import 'dart:ui';

/// One pen stroke — a polyline of points the student drew in one continuous
/// touch, plus enough metadata to erase it as a whole unit (the spec's
/// "stroke-eraser removes whole strokes it touches", not pixel erasing).
class Stroke {
  const Stroke({
    required this.id,
    required this.colorValue,
    required this.width,
    required this.points,
    required this.t0,
    this.t1,
  });

  final String id;
  final int colorValue;
  final double width;
  final List<Offset> points;
  final int t0;
  final int? t1;

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
    'id': id,
    'color': colorValue,
    'width': width,
    'points': points.map((p) => [p.dx, p.dy]).toList(),
    't0': t0,
    't1': t1,
  };

  factory Stroke.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List;
    return Stroke(
      id: json['id'] as String,
      colorValue: json['color'] as int,
      width: (json['width'] as num).toDouble(),
      points: rawPoints
          .map(
            (p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
          )
          .toList(),
      t0: json['t0'] as int,
      t1: json['t1'] as int?,
    );
  }
}
