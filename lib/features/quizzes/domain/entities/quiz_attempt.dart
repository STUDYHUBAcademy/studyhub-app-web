class QuizAttempt {
  const QuizAttempt({
    required this.id,
    required this.quizId,
    required this.studentName,
    this.studentPhone,
    required this.totalQuestions,
    required this.correctCount,
    required this.scorePct,
    required this.createdAt,
  });

  final String id;
  final String quizId;
  final String studentName;
  final String? studentPhone;
  final int totalQuestions;
  final int correctCount;
  final double scorePct;
  final DateTime createdAt;

  factory QuizAttempt.fromJson(Map<String, dynamic> json) {
    return QuizAttempt(
      id: json['id'] as String,
      quizId: json['quiz_id'] as String,
      studentName: json['student_name'] as String,
      studentPhone: json['student_phone'] as String?,
      totalQuestions: (json['total_questions'] as num).toInt(),
      correctCount: (json['correct_count'] as num).toInt(),
      scorePct: (json['score_pct'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
