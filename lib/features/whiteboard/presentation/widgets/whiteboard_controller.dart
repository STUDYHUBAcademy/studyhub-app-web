import 'package:flutter/material.dart';

import '../../domain/entities/stroke.dart';

enum WhiteboardTool { pen, eraser, pan }

/// A blank page, or one ruled with notebook lines — like Inkodo's
/// note-taking pages — shown behind any uploaded source and the strokes.
enum PageStyle { blank, ruled }

/// Local, ephemeral drawing state for one board session — not a Riverpod
/// provider, since nothing outside the canvas widget needs it and its
/// lifetime is exactly the screen that owns it.
class WhiteboardController extends ChangeNotifier {
  final List<Stroke> strokes = [];
  final List<Stroke> _redoStack = [];

  WhiteboardTool tool = WhiteboardTool.pen;
  Color penColor = Colors.black;
  double penWidth = 3;
  PageStyle pageStyle = PageStyle.blank;

  /// Pan/zoom applied to the whole page (background + strokes together).
  Offset panOffset = Offset.zero;
  double zoom = 1;

  List<Offset>? _liveStrokePoints;
  int? _liveStrokeT0;
  int _nextId = 0;

  List<Offset>? get liveStrokePoints => _liveStrokePoints;

  bool get canUndo => strokes.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void setTool(WhiteboardTool t) {
    tool = t;
    notifyListeners();
  }

  void setPenColor(Color c) {
    penColor = c;
    notifyListeners();
  }

  void setPageStyle(PageStyle s) {
    pageStyle = s;
    notifyListeners();
  }

  void zoomBy(double factor) {
    zoom = (zoom * factor).clamp(0.5, 3.0);
    notifyListeners();
  }

  void panBy(Offset delta) {
    panOffset += delta;
    notifyListeners();
  }

  /// [point] is already in page-logical coordinates (the caller divides out
  /// the current pan/zoom before calling this).
  void pointerDown(Offset point) {
    if (tool == WhiteboardTool.pan) return;
    _liveStrokePoints = [point];
    _liveStrokeT0 = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
  }

  void pointerMove(Offset point) {
    if (tool == WhiteboardTool.pan || _liveStrokePoints == null) return;
    _liveStrokePoints!.add(point);
    if (tool == WhiteboardTool.eraser) _eraseNear(point);
    notifyListeners();
  }

  void pointerUp() {
    final points = _liveStrokePoints;
    if (points != null && points.length > 1 && tool == WhiteboardTool.pen) {
      strokes.add(
        Stroke(
          id: 'local_${_nextId++}_${DateTime.now().microsecondsSinceEpoch}',
          colorValue: penColor.toARGB32(),
          width: penWidth,
          points: List.of(points),
          t0: _liveStrokeT0!,
          t1: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      _redoStack.clear();
    }
    _liveStrokePoints = null;
    notifyListeners();
  }

  void _eraseNear(Offset point) {
    const hitRadius = 18.0;
    strokes.removeWhere(
      (s) => s.points.any((p) => (p - point).distance < hitRadius),
    );
  }

  void undo() {
    if (strokes.isEmpty) return;
    _redoStack.add(strokes.removeLast());
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    strokes.add(_redoStack.removeLast());
    notifyListeners();
  }

  void clear() {
    strokes.clear();
    _redoStack.clear();
    notifyListeners();
  }

  void loadStrokes(List<Stroke> initial) {
    strokes
      ..clear()
      ..addAll(initial);
    notifyListeners();
  }
}
