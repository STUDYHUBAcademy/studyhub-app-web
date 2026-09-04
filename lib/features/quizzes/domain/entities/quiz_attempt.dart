class QuizAttempt {
  const QuizAttempt({
    required this.id,
    required this.quizId,
    this.termId,
    required this.studentName,
    this.studentPhone,
    required this.totalQuestions,
    required this.correctCount,
    required this.scorePct,
    required this.createdAt,
  });

  final String id;
  final String quizId;

  /// Set from the `?term=<id>` on the link the student used — tagged by
  /// the owner at share time, not guessed after the fact. Null if the
  /// link wasn't tagged with a term.
  final String? termId;
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
      termId: json['term_id'] as String?,
      studentName: json['student_name'] as String,
      studentPhone: json['student_phone'] as String?,
      totalQuestions: (json['total_questions'] as num).toInt(),
      correctCount: (json['correct_count'] as num).toInt(),
      scorePct: (json['score_pct'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
