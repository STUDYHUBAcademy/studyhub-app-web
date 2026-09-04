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

  Future<Map<String, dynamic>> addQuiz(Map<String, dynamic> quiz) async {
    return _client.from('quizzes').insert(quiz).select().single();
  }

  Future<void> deleteQuiz(String id) async {
    await _client.from('quizzes').delete().eq('id', id);
  }

  /// Calls the `generate-quiz` Edge Function (deployed under the Supabase
  /// dashboard's auto-generated slug "bright-responder" — the "Name" field
  /// there is just a display label and doesn't change the actual routing
  /// slug), which reads the given Drive files, asks Gemini to draft the
  /// MCQs, and inserts the resulting quiz row itself (as the calling owner,
  /// via their forwarded session).
  Future<Map<String, dynamic>> generateQuiz(
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.functions.invoke(
      'bright-responder',
      body: payload,
    );
    final data = response.data;
    if (response.status != 200 || data is! Map || data['quiz'] == null) {
      final message = (data is Map ? data['error'] : null) ?? response.data;
      throw Exception('فشل توليد الاختبار: $message');
    }
    return Map<String, dynamic>.from(data['quiz'] as Map);
  }
}
