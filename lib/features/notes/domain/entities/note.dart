class Note {
  const Note({
    required this.id,
    required this.text,
    this.linkedCourseId,
    this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String text;
  final String? linkedCourseId;
  final String? createdBy;
  final DateTime createdAt;

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      text: json['text'] as String,
      linkedCourseId: json['linked_course_id'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
