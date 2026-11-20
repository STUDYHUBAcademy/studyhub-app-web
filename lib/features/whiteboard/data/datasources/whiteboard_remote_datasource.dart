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

  // Anon only has column-level SELECT grants on these — never model_answer/
  // rubric/accepted_variations/checks (the student's device must never see
  // the answer key). Only the Edge Functions read those server-side.
  static const _publicQuestionColumns =
      'id, teacher_id, subject_pack, prompt, source_path, source_type, '
      'reference_video_link, max_score, language, created_at';

  Future<List<Map<String, dynamic>>> fetchQuestions(List<String> ids) async {
    if (ids.isEmpty) return [];
    return await _client
        .from('wb_questions')
        .select(_publicQuestionColumns)
        .inFilter('id', ids);
  }

  Future<void> submitWork(Map<String, dynamic> data) async {
    await _client.from('wb_submissions').insert(data);
  }

  Future<Map<String, dynamic>> gradeSubmission({
    required String submissionId,
    required String imageBase64,
  }) async {
    final response = await _client.functions.invoke(
      'wb-grade',
      body: {'submission_id': submissionId, 'image_base64': imageBase64},
    );
    final data = response.data;
    if (response.status != 200 || data is! Map || data['feedback'] == null) {
      final message = (data is Map ? data['error'] : null) ?? response.data;
      throw Exception('فشل التصحيح بالذكاء الاصطناعي: $message');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> liveCheck({
    required String questionId,
    required String imageBase64,
  }) async {
    final response = await _client.functions.invoke(
      'wb-live-check',
      body: {'question_id': questionId, 'image_base64': imageBase64},
    );
    final data = response.data;
    if (response.status != 200 || data is! Map || data['state'] == null) {
      final message = (data is Map ? data['error'] : null) ?? response.data;
      throw Exception('فشل التصحيح الفوري: $message');
    }
    return Map<String, dynamic>.from(data);
  }
}
