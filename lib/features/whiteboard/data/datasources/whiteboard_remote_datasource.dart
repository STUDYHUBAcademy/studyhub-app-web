import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class WhiteboardRemoteDatasource {
  WhiteboardRemoteDatasource(this._client);

  final SupabaseClient _client;

  Stream<List<Map<String, dynamic>>> watchQuestions() {
    return _client
        .from('wb_questions')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> watchAssignments() {
    return _client
        .from('wb_assignments')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> watchSubmissions(String assignmentId) {
    return _client
        .from('wb_submissions')
        .stream(primaryKey: ['id'])
        .eq('assignment_id', assignmentId)
        .order('created_at', ascending: false);
  }

  Future<Map<String, dynamic>> addQuestion(Map<String, dynamic> data) async {
    return _client.from('wb_questions').insert(data).select().single();
  }

  Future<Map<String, dynamic>> addAssignment(Map<String, dynamic> data) async {
    return _client.from('wb_assignments').insert(data).select().single();
  }

  Future<void> setAssignmentPublished(String id, bool isPublished) async {
    await _client
        .from('wb_assignments')
        .update({'is_published': isPublished})
        .eq('id', id);
  }

  Future<String> uploadQuestionSource(Uint8List bytes, String fileName) async {
    final path = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await _client.storage.from('wb-figures').uploadBinary(path, bytes);
    return path;
  }

  String publicUrlFor(String storagePath) {
    return _client.storage.from('wb-figures').getPublicUrl(storagePath);
  }

  Future<Map<String, dynamic>?> fetchPublishedAssignment(String id) async {
    return await _client
        .from('wb_assignments')
        .select()
        .eq('id', id)
        .eq('is_published', true)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> fetchQuestions(List<String> ids) async {
    if (ids.isEmpty) return [];
    return await _client.from('wb_questions').select().inFilter('id', ids);
  }

  Future<void> submitWork(Map<String, dynamic> data) async {
    await _client.from('wb_submissions').insert(data);
  }
}
