class CourseDemo {
  const CourseDemo({
    required this.id,
    required this.courseId,
    required this.tutorId,
    this.demoAt,
    this.notes,
    required this.outcome,
    required this.createdAt,
  });

  final String id;
  final String courseId;
  final String tutorId;
  final DateTime? demoAt;
  final String? notes;
  final String outcome; // pending | selected | rejected
  final DateTime createdAt;

  factory CourseDemo.fromJson(Map<String, dynamic> json) {
    return CourseDemo(
      id: json['id'] as String,
      courseId: json['course_id'] as String,
      tutorId: json['tutor_id'] as String,
      demoAt: json['demo_at'] != null
          ? DateTime.parse(json['demo_at'] as String)
          : null,
      notes: json['notes'] as String?,
      outcome: json['outcome'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
