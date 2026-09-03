import '../entities/quiz.dart';
import '../entities/quiz_attempt.dart';

abstract class QuizzesRepository {
  Stream<List<Quiz>> watchQuizzes();
  Stream<List<QuizAttempt>> watchAttempts(String quizId);
}
