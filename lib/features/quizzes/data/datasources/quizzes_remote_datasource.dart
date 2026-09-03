import 'package:supabase_flutter/supabase_flutter.dart';

class QuizzesRemoteDatasource {
  QuizzesRemoteDatasource(this._client);

  final SupabaseClient _client;

  Stream<List<Map<String, dynamic>>> watchQuizzes() {
    return _client
        .from('quizzes')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> watchAttempts(String quizId) {
    return _client
        .from('quiz_attempts')
        .stream(primaryKey: ['id'])
        .eq('quiz_id', quizId)
        .order('created_at', ascending: false);
  }
}
