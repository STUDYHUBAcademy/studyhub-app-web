import 'quiz_question.dart';

class Quiz {
  const Quiz({
    required this.id,
    required this.title,
    this.courseId,
    this.videoLink,
    required this.questions,
    required this.isPublished,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String? courseId;
  final String? videoLink;
  final List<QuizQuestion> questions;
  final bool isPublished;
  final DateTime createdAt;

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'] as String,
      title: json['title'] as String,
      courseId: json['course_id'] as String?,
      videoLink: json['video_link'] as String?,
      questions: (json['questions'] as List<dynamic>? ?? [])
          .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
      isPublished: json['is_published'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
