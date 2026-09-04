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

  /// Drafts a quiz automatically from Drive file content via the
  /// `generate-quiz` Edge Function (Gemini). [files] is one map per
  /// selected file: `{'id': ..., 'mime_type': ...}`.
  Future<Quiz> generateQuiz({
    required String title,
    String? courseId,
    required String direction,
    required List<Map<String, String?>> files,
    required String driveAccessToken,
  });

  /// Also cascades to delete every attempt recorded for this quiz.
  Future<void> deleteQuiz(String id);
}
