import '../entities/quiz.dart';
import '../entities/quiz_attempt.dart';

abstract class QuizzesRepository {
  Stream<List<Quiz>> watchQuizzes();
  Stream<List<QuizAttempt>> watchAttempts(String quizId);

  /// [questions] is the raw parsed JSON array (already validated by the
  /// caller) — passed straight through to the jsonb column.
  Future<Quiz> addQuiz({
    required String title,
    String? courseId,
    String? videoLink,
    required String direction,
    required List<Map<String, dynamic>> questions,
  });
}
