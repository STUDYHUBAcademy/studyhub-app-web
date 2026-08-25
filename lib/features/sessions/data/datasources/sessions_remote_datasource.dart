import 'package:supabase_flutter/supabase_flutter.dart';

class SessionsRemoteDatasource {
  SessionsRemoteDatasource(this._client);

  final SupabaseClient _client;

  Stream<List<Map<String, dynamic>>> watchSessions() {
    return _client
        .from('private_sessions')
        .stream(primaryKey: ['id'])
        .order('scheduled_at');
  }

  Future<Map<String, dynamic>> addSession(Map<String, dynamic> session) async {
    return _client.from('private_sessions').insert(session).select().single();
  }

  Future<void> updateSession(String id, Map<String, dynamic> patch) async {
    await _client.from('private_sessions').update(patch).eq('id', id);
  }

  Future<void> deleteSession(String id) async {
    await _client.from('private_sessions').delete().eq('id', id);
  }
}
