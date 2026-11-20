import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../domain/entities/stroke.dart';
import '../../domain/entities/stroke_line.dart';
import 'whiteboard_canvas.dart';

Future<ui.Image?> _decodeBackground(
  Uint8List? bytes,
  String? sourceType,
) async {
  if (bytes == null) return null;
  if (sourceType == 'pdf') {
    final doc = await PdfDocument.openData(bytes);
    final page = await doc.getPage(1);
    final rendered = await page.render(
      width: page.width * 2,
      height: page.height * 2,
      format: PdfPageImageFormat.png,
    );
    await page.close();
    await doc.close();
    return rendered == null ? null : decodeImageFromList(rendered.bytes);
  }
  return decodeImageFromList(bytes);
}

void _drawBackground(Canvas canvas, ui.Image? background) {
  if (background == null) return;
  final scale = kWhiteboardPageWidth / background.width;
  canvas.drawImageRect(
    background,
    Rect.fromLTWH(0, 0, background.width.toDouble(), background.height.toDouble()),
    Rect.fromLTWH(0, 0, kWhiteboardPageWidth, background.height * scale),
    Paint(),
  );
}

/// Renders a submission's strokes (plus the question's background, if any)
/// into a single flat PNG — this is what gets sent to the AI grader, since
/// Deno has no Flutter runtime to render strokes itself. Uses the same
/// [WhiteboardPainter] the live canvas uses, called directly against an
/// off-screen [ui.PictureRecorder] canvas — no widget tree needs to be
/// mounted for this.
///
/// For a multi-page PDF background, only the first page is drawn — the
/// question's text prompt is sent to the grader alongside this image anyway,
/// so the background here is supplementary visual context, not the only
/// source of the question.
Future<Uint8List> rasterizeSubmission({
  required List<Stroke> strokes,
  Uint8List? backgroundBytes,
  String? backgroundSourceType,
}) async {
  final background = await _decodeBackground(
    backgroundBytes,
    backgroundSourceType,
  );

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    const Rect.fromLTWH(0, 0, kWhiteboardPageWidth, kWhiteboardPageHeight),
  );
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, kWhiteboardPageWidth, kWhiteboardPageHeight),
    Paint()..color = Colors.white,
  );
  _drawBackground(canvas, background);
  WhiteboardPainter(
    strokes: strokes,
    liveStroke: null,
    liveColor: Colors.black,
    liveWidth: 1,
  ).paint(canvas, const Size(kWhiteboardPageWidth, kWhiteboardPageHeight));

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    kWhiteboardPageWidth.toInt(),
    kWhiteboardPageHeight.toInt(),
  );
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

/// Result of rasterizing a snapshot for the live AI checker: the PNG sent to
/// Gemini, and the exact line segmentation used to draw its numbered badges
/// — the caller maps the AI's returned line numbers back to these bounds to
/// know which strokes to recolor and where to place a marker.
class LiveCheckSnapshot {
  const LiveCheckSnapshot({
    required this.png,
    required this.lines,
    required this.croppedHeight,
  });

  final Uint8List png;
  final List<StrokeLine> lines;

  /// How tall the cropped image is, in page-logical units — needed because
  /// the live-check image is cropped to the written area, not the full
  /// (mostly blank) page, to keep the upload small and the check fast.
  final double croppedHeight;
}

const _kLiveCheckTopPadding = 40.0;
const _kLiveCheckBottomPadding = 120.0;
const _kLineBadgeX = 22.0;
const _kLineBadgeRadius = 14.0;

/// Renders the current in-progress strokes (plus background) cropped to the
/// written area, with a numbered blue circle badge in the left margin for
/// each segmented line — exactly the "don't ask the model for coordinates,
/// ask it for line numbers" trick the spec calls for, so the AI can answer
/// "line 3 is wrong" and that maps back deterministically to real strokes.
Future<LiveCheckSnapshot> rasterizeForLiveCheck({
  required List<Stroke> strokes,
  Uint8List? backgroundBytes,
  String? backgroundSourceType,
}) async {
  final lines = segmentIntoLines(strokes);
  final background = await _decodeBackground(
    backgroundBytes,
    backgroundSourceType,
  );

  var maxY = _kLiveCheckTopPadding;
  for (final line in lines) {
    if (line.bounds.bottom > maxY) maxY = line.bounds.bottom;
  }
  final height = (maxY + _kLiveCheckBottomPadding).clamp(
    400.0,
    kWhiteboardPageHeight,
  );

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, kWhiteboardPageWidth, height),
  );
  canvas.drawRect(
    Rect.fromLTWH(0, 0, kWhiteboardPageWidth, height),
    Paint()..color = Colors.white,
  );
  _drawBackground(canvas, background);
  WhiteboardPainter(
    strokes: strokes,
    liveStroke: null,
    liveColor: Colors.black,
    liveWidth: 1,
  ).paint(canvas, Size(kWhiteboardPageWidth, height));

  final badgePaint = Paint()..color = const Color(0xFF2A5BD6);
  for (final line in lines) {
    final cy = (line.bounds.top + line.bounds.bottom) / 2;
    canvas.drawCircle(Offset(_kLineBadgeX, cy), _kLineBadgeRadius, badgePaint);
    final tp = TextPainter(
      text: TextSpan(
        text: '${line.index}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(_kLineBadgeX - tp.width / 2, cy - tp.height / 2),
    );
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    kWhiteboardPageWidth.toInt(),
    height.toInt(),
  );
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return LiveCheckSnapshot(
    png: byteData!.buffer.asUint8List(),
    lines: lines,
    croppedHeight: height,
  );
}
