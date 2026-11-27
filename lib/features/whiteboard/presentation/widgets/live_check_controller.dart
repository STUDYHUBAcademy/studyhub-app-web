import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/entities/live_check_result.dart';
import '../../domain/entities/stroke.dart';
import '../../domain/entities/stroke_line.dart';

/// Debounced orchestration for the "⚡ live AI check" toggle — shared by the
/// assignment board and the free-study canvas, which differ only in what
/// [check] sends as grounding context (a question id vs. a course id).
///
/// [check] is called with the current strokes once the student pauses, and
/// must return the exact line segmentation it sent to the AI (so the
/// returned line numbers map back to real strokes) alongside the result.
class LiveCheckController extends ChangeNotifier {
  LiveCheckController({required this.check});

  final Future<(List<StrokeLine>, LiveCheckResult)> Function(
    List<Stroke> strokes,
  )
  check;

  bool enabled = false;
  Timer? _debounce;
  bool _checking = false;
  bool _pendingRecheck = false;
  int _lastSeenStrokeCount = 0;
  List<Stroke> _pendingStrokes = const [];

  List<StrokeLine> lines = [];
  Map<String, Color> strokeColors = {};
  Map<int, LiveCheckFlag> flagsByLine = {};
  String? message;

  /// Set when a check throws, cleared on the next successful one — surfaced
  /// in the UI (instead of silently swallowed) so a real failure is visible
  /// rather than looking identical to "nothing wrong to flag yet".
  String? lastError;
  bool checking = false;

  /// What the banner should actually show: an in-flight indicator takes
  /// priority, then a real error, then the AI's own message.
  String? get displayMessage {
    if (checking) return '🔎 بيراجع...';
    if (lastError != null) return '⚠️ $lastError';
    return message;
  }

  void setEnabled(bool on) {
    enabled = on;
    if (!on) {
      _debounce?.cancel();
      strokeColors = {};
      flagsByLine = {};
      message = null;
    }
    notifyListeners();
  }

  /// Call whenever the canvas's stroke list may have changed (e.g. from a
  /// `WhiteboardController` listener) — restarts the debounce only if a
  /// stroke was actually added/removed since the last call.
  void onStrokesChanged(List<Stroke> strokes) {
    if (!enabled) return;
    if (strokes.length == _lastSeenStrokeCount) return;
    _lastSeenStrokeCount = strokes.length;
    _pendingStrokes = strokes;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1200), _run);
  }

  Future<void> _run() async {
    if (_checking) {
      _pendingRecheck = true;
      return;
    }
    final strokes = List<Stroke>.of(_pendingStrokes);
    if (strokes.isEmpty) return;
    _checking = true;
    checking = true;
    notifyListeners();
    try {
      final (lines, result) = await check(strokes);
      lastError = null;
      _applyResult(lines, result);
    } catch (e) {
      lastError = e.toString();
    } finally {
      _checking = false;
      checking = false;
      notifyListeners();
      if (_pendingRecheck) {
        _pendingRecheck = false;
        unawaited(_run());
      }
    }
  }

  void _applyResult(List<StrokeLine> lines, LiveCheckResult result) {
    final colors = <String, Color>{};
    final flags = <int, LiveCheckFlag>{};
    for (final flag in result.flags) {
      final line = lines.where((l) => l.index == flag.line).firstOrNull;
      if (line == null) continue;
      flags[flag.line] = flag;
      final color = flag.severity == 'critical'
          ? const Color(0xFFC21F3A)
          : const Color(0xFFB36A00);
      for (final s in line.strokes) {
        colors[s.id] = color;
      }
    }
    this.lines = lines;
    strokeColors = colors;
    flagsByLine = flags;
    message = result.message;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
