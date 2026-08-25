class Task {
  const Task({
    required this.id,
    required this.title,
    this.body,
    this.dueDate,
    required this.status,
    this.linkedCourseId,
    this.progressNote,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String? body;
  final DateTime? dueDate;
  final String status; // open | done
  final String? linkedCourseId;
  final String? progressNote;
  final DateTime createdAt;

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String?,
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      status: json['status'] as String? ?? 'open',
      linkedCourseId: json['linked_course_id'] as String?,
      progressNote: json['progress_note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
