import 'package:flutter/material.dart';

import '../../domain/entities/stroke.dart';
import 'whiteboard_controller.dart';

/// Fixed logical page size strokes are recorded in — matches the spec's
/// "1000-wide logical space". Height is generous (a notebook page, not a
/// cramped answer box) so a full worked solution has room.
const kWhiteboardPageWidth = 1000.0;
const kWhiteboardPageHeight = 2400.0;

/// A general-purpose drawing canvas (pen/eraser/undo/pan/zoom) with an
/// optional background layer — a question image, or a PDF's pages stacked
/// vertically — behind the strokes, like Inkodo/Samsung Notes rather than a
/// single boxed answer field.
///
/// Pan/zoom is handled entirely by this widget via [WhiteboardController],
/// not a parent `Scrollable`/`InteractiveViewer` — the prototype this is
/// ported from had exactly the bug where a parent scroll view stole the
/// drawing gesture, so there's deliberately no ancestor `Scrollable` here to
/// steal it from.
class WhiteboardCanvas extends StatefulWidget {
  const WhiteboardCanvas({
    super.key,
    required this.controller,
    this.background,
    this.strokeColorOverrides = const {},
    this.overlayChildren = const [],
  });

  final WhiteboardController controller;
  final Widget? background;

  /// Maps a stroke id to a color it should render as instead of its own —
  /// how the live AI-check flags a wrong line red/orange without mutating
  /// the actual stroke data.
  final Map<String, Color> strokeColorOverrides;

  /// Extra widgets positioned in the same 1000x2400 logical page space as
  /// the strokes (e.g. the live-check "!" markers) — added inside the same
  /// `Transform` as the canvas so they pan/zoom together with it.
  final List<Widget> overlayChildren;

  @override
  State<WhiteboardCanvas> createState() => _WhiteboardCanvasState();
}

class _WhiteboardCanvasState extends State<WhiteboardCanvas> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  Offset _toPageCoordinates(Offset localPosition, Size viewportSize) {
    final c = widget.controller;
    final scale = (viewportSize.width / kWhiteboardPageWidth) * c.zoom;
    return (localPosition - c.panOffset) / scale;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportSize = constraints.biggest;
          final scale = (viewportSize.width / kWhiteboardPageWidth) * c.zoom;
          return Listener(
            onPointerDown: (e) {
              if (c.tool == WhiteboardTool.pan) return;
              c.pointerDown(_toPageCoordinates(e.localPosition, viewportSize));
            },
            onPointerMove: (e) {
              if (c.tool == WhiteboardTool.pan) {
                c.panBy(e.delta);
                return;
              }
              c.pointerMove(_toPageCoordinates(e.localPosition, viewportSize));
            },
            onPointerUp: (_) => c.pointerUp(),
            onPointerCancel: (_) => c.pointerUp(),
            child: Container(
              color: Colors.white,
              width: double.infinity,
              height: double.infinity,
              child: Transform(
                transform: Matrix4.identity()
                  ..translateByDouble(c.panOffset.dx, c.panOffset.dy, 0.0, 1.0)
                  ..scaleByDouble(scale, scale, scale, 1.0),
                child: SizedBox(
                  width: kWhiteboardPageWidth,
                  height: kWhiteboardPageHeight,
                  child: Stack(
                    children: [
                      if (widget.background != null)
                        Positioned.fill(child: widget.background!),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: WhiteboardPainter(
                            strokes: c.strokes,
                            liveStroke: c.liveStrokePoints,
                            liveColor: c.penColor,
                            liveWidth: c.penWidth,
                            pageStyle: c.pageStyle,
                            strokeColorOverrides: widget.strokeColorOverrides,
                          ),
                        ),
                      ),
                      ...widget.overlayChildren,
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class WhiteboardPainter extends CustomPainter {
  WhiteboardPainter({
    required this.strokes,
    required this.liveStroke,
    required this.liveColor,
    required this.liveWidth,
    this.pageStyle = PageStyle.blank,
    this.strokeColorOverrides = const {},
  });

  final List<Stroke> strokes;
  final List<Offset>? liveStroke;
  final Color liveColor;
  final double liveWidth;
  final PageStyle pageStyle;
  final Map<String, Color> strokeColorOverrides;

  static const _ruleSpacing = 48.0;

  void _paintRuledLines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD7E0EA)
      ..strokeWidth = 1;
    for (var y = _ruleSpacing; y < size.height; y += _ruleSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _paintPolyline(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      canvas.drawCircle(
        points.first,
        paint.strokeWidth / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (pageStyle == PageStyle.ruled) _paintRuledLines(canvas, size);
    for (final s in strokes) {
      _paintPolyline(
        canvas,
        s.points,
        Paint()
          ..color = strokeColorOverrides[s.id] ?? s.color
          ..strokeWidth = s.width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }
    if (liveStroke != null) {
      _paintPolyline(
        canvas,
        liveStroke!,
        Paint()
          ..color = liveColor
          ..strokeWidth = liveWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WhiteboardPainter oldDelegate) => true;
}
