import 'dart:ui';

import 'stroke.dart';

/// One "line" of handwritten work — a vertical band of strokes grouped by
/// y-overlap, roughly one step of a solution. Numbered top-to-bottom so the
/// AI can be told "line 3 is wrong" instead of coordinates (coordinates from
/// a vision model are unreliable; line numbers read off a rendered badge are
/// not).
class StrokeLine {
  StrokeLine({required this.index, required this.strokes});

  final int index;
  final List<Stroke> strokes;

  late final Rect bounds = _computeBounds();

  Rect _computeBounds() {
    var minX = double.infinity, minY = double.infinity;
    var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final s in strokes) {
      for (final p in s.points) {
        if (p.dx < minX) minX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy > maxY) maxY = p.dy;
      }
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}

(double, double) _strokeYRange(Stroke s) {
  var minY = double.infinity, maxY = double.negativeInfinity;
  for (final p in s.points) {
    if (p.dy < minY) minY = p.dy;
    if (p.dy > maxY) maxY = p.dy;
  }
  return (minY, maxY);
}

/// Greedily groups strokes into vertical bands: a stroke joins an existing
/// line if its y-range overlaps that line's current y-range within
/// [bandPadding], otherwise it starts a new line. Re-run from scratch on
/// every check — a single homework page has few enough strokes that this is
/// cheap, and it keeps line numbers correct even if the student goes back
/// and adds a stroke above earlier work.
List<StrokeLine> segmentIntoLines(
  List<Stroke> strokes, {
  double bandPadding = 24,
}) {
  if (strokes.isEmpty) return [];

  final withRange = strokes.map((s) => (s, _strokeYRange(s))).toList()
    ..sort((a, b) => a.$2.$1.compareTo(b.$2.$1));

  final groups = <List<Stroke>>[];
  final groupRanges = <(double, double)>[];
  for (final (s, range) in withRange) {
    var placed = false;
    for (var i = 0; i < groups.length; i++) {
      final g = groupRanges[i];
      if (range.$1 <= g.$2 + bandPadding && range.$2 >= g.$1 - bandPadding) {
        groups[i].add(s);
        groupRanges[i] = (
          g.$1 < range.$1 ? g.$1 : range.$1,
          g.$2 > range.$2 ? g.$2 : range.$2,
        );
        placed = true;
        break;
      }
    }
    if (!placed) {
      groups.add([s]);
      groupRanges.add(range);
    }
  }

  final order = List.generate(groups.length, (i) => i)
    ..sort((a, b) => groupRanges[a].$1.compareTo(groupRanges[b].$1));
  return [
    for (final (n, i) in order.indexed)
      StrokeLine(index: n + 1, strokes: groups[i]),
  ];
}
