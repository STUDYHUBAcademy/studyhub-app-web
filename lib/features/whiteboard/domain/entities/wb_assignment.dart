class WbAssignment {
  const WbAssignment({
    required this.id,
    this.teacherId,
    this.courseId,
    required this.title,
    required this.questionIds,
    required this.isPublished,
    this.dueAt,
    required this.createdAt,
  });

  final String id;
  final String? teacherId;
  final String? courseId;
  final String title;
  final List<String> questionIds;
  final bool isPublished;
  final DateTime? dueAt;
  final DateTime createdAt;

  factory WbAssignment.fromJson(Map<String, dynamic> json) {
    return WbAssignment(
      id: json['id'] as String,
      teacherId: json['teacher_id'] as String?,
      courseId: json['course_id'] as String?,
      title: json['title'] as String,
      questionIds: (json['question_ids'] as List? ?? [])
          .map((e) => e as String)
          .toList(),
      isPublished: json['is_published'] as bool? ?? false,
      dueAt: json['due_at'] != null
          ? DateTime.parse(json['due_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
