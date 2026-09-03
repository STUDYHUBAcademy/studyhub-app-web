import '../../domain/entities/quiz.dart';
import '../../domain/entities/quiz_attempt.dart';
import '../../domain/repositories/quizzes_repository.dart';
import '../datasources/quizzes_remote_datasource.dart';

class QuizzesRepositoryImpl implements QuizzesRepository {
  QuizzesRepositoryImpl(this._remote);

  final QuizzesRemoteDatasource _remote;

  @override
  Stream<List<Quiz>> watchQuizzes() {
    return _remote.watchQuizzes().map(
      (rows) => rows.map(Quiz.fromJson).toList(),
    );
  }

  @override
  Stream<List<QuizAttempt>> watchAttempts(String quizId) {
    return _remote
        .watchAttempts(quizId)
        .map((rows) => rows.map(QuizAttempt.fromJson).toList());
  }

  @override
  Future<Quiz> addQuiz({
    required String title,
    String? courseId,
    String? videoLink,
    required String direction,
    required List<Map<String, dynamic>> questions,
  }) async {
    final row = await _remote.addQuiz({
      'title': title,
      'course_id': courseId,
      'video_link': videoLink,
      'direction': direction,
      'questions': questions,
    });
    return Quiz.fromJson(row);
  }
}
