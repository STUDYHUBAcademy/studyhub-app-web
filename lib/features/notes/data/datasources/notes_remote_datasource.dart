import 'package:supabase_flutter/supabase_flutter.dart';

class NotesRemoteDatasource {
  NotesRemoteDatasource(this._client);

  final SupabaseClient _client;

  Stream<List<Map<String, dynamic>>> watchNotes() {
    return _client
        .from('notes')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  Future<void> addNote({required String text, String? linkedCourseId}) async {
    await _client.from('notes').insert({
      'text': text,
      'linked_course_id': linkedCourseId,
    });
  }

  Future<void> updateNote({required String id, required String text}) async {
    await _client.from('notes').update({'text': text}).eq('id', id);
  }

  Future<void> deleteNote(String id) async {
    await _client.from('notes').delete().eq('id', id);
  }
}
