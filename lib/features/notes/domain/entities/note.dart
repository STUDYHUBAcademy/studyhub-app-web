class Note {
  const Note({
    required this.id,
    required this.text,
    this.linkedCourseId,
    required this.createdAt,
  });

  final String id;
  final String text;
  final String? linkedCourseId;
  final DateTime createdAt;

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      text: json['text'] as String,
      linkedCourseId: json['linked_course_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
