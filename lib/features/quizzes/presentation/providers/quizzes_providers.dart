import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_client.dart';
import '../../data/datasources/quizzes_remote_datasource.dart';
import '../../data/repositories/quizzes_repository_impl.dart';
import '../../domain/entities/quiz.dart';
import '../../domain/entities/quiz_attempt.dart';
import '../../domain/repositories/quizzes_repository.dart';

final quizzesRemoteDatasourceProvider = Provider<QuizzesRemoteDatasource>((
  ref,
) {
  return QuizzesRemoteDatasource(AppSupabase.client);
});

final quizzesRepositoryProvider = Provider<QuizzesRepository>((ref) {
  return QuizzesRepositoryImpl(ref.watch(quizzesRemoteDatasourceProvider));
});

final quizzesProvider = StreamProvider<List<Quiz>>((ref) {
  return ref.watch(quizzesRepositoryProvider).watchQuizzes();
});

final quizAttemptsProvider = StreamProvider.family<List<QuizAttempt>, String>((
  ref,
  quizId,
) {
  return ref.watch(quizzesRepositoryProvider).watchAttempts(quizId);
});
