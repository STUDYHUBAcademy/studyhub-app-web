import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../domain/entities/stroke.dart';
import 'whiteboard_canvas.dart';

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
  ui.Image? background;
  if (backgroundBytes != null) {
    if (backgroundSourceType == 'pdf') {
      final doc = await PdfDocument.openData(backgroundBytes);
      final page = await doc.getPage(1);
      final rendered = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: PdfPageImageFormat.png,
      );
      await page.close();
      await doc.close();
      if (rendered != null) {
        background = await decodeImageFromList(rendered.bytes);
      }
    } else {
      background = await decodeImageFromList(backgroundBytes);
    }
  }

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    const Rect.fromLTWH(0, 0, kWhiteboardPageWidth, kWhiteboardPageHeight),
  );
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, kWhiteboardPageWidth, kWhiteboardPageHeight),
    Paint()..color = Colors.white,
  );
  if (background != null) {
    final scale = kWhiteboardPageWidth / background.width;
    canvas.drawImageRect(
      background,
      Rect.fromLTWH(
        0,
        0,
        background.width.toDouble(),
        background.height.toDouble(),
      ),
      Rect.fromLTWH(
        0,
        0,
        kWhiteboardPageWidth,
        background.height * scale,
      ),
      Paint(),
    );
  }
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
