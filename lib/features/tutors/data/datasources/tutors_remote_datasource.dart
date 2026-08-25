import 'package:supabase_flutter/supabase_flutter.dart';

class TutorsRemoteDatasource {
  TutorsRemoteDatasource(this._client);

  final SupabaseClient _client;

  Stream<List<Map<String, dynamic>>> watchApplications() {
    return _client
        .from('tutor_applications')
        .stream(primaryKey: ['id'])
        .order('submitted_at', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> watchTutors() {
    return _client
        .from('tutors')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  Future<Map<String, dynamic>> insertTutor(Map<String, dynamic> tutor) async {
    return _client.from('tutors').insert(tutor).select().single();
  }

  /// True if a tutor already exists for this application (already promoted
  /// once — guards a retry after a partial failure) or shares an email/phone
  /// with an existing tutor (the same person applied more than once).
  Future<bool> tutorExists({
    String? applicationId,
    String? email,
    String? phonePrimary,
    String? phoneWhatsapp,
  }) async {
    final conditions = <String>[];
    if (applicationId != null) {
      conditions.add('application_id.eq.$applicationId');
    }
    if (email != null && email.trim().isNotEmpty) {
      conditions.add('email.eq.${email.trim()}');
    }
    if (phonePrimary != null && phonePrimary.trim().isNotEmpty) {
      conditions.add('phone_primary.eq.${phonePrimary.trim()}');
    }
    if (phoneWhatsapp != null && phoneWhatsapp.trim().isNotEmpty) {
      conditions.add('phone_whatsapp.eq.${phoneWhatsapp.trim()}');
    }
    if (conditions.isEmpty) return false;
    final rows = await _client
        .from('tutors')
        .select('id')
        .or(conditions.join(','))
        .limit(1);
    return rows.isNotEmpty;
  }

  Future<void> updateApplicationStatus(String id, String status) async {
    await _client
        .from('tutor_applications')
        .update({'status': status})
        .eq('id', id);
  }

  Future<void> updateTutorStatus(String id, String status) async {
    await _client.from('tutors').update({'status': status}).eq('id', id);
  }

  Future<void> updateTutorFeatured(String id, bool featured) async {
    await _client.from('tutors').update({'is_featured': featured}).eq('id', id);
  }

  Future<void> deleteTutor(String id) async {
    await _client.from('tutors').delete().eq('id', id);
  }

  Future<void> deleteApplication(String id) async {
    await _client.from('tutor_applications').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> fetchStatusLog(String tutorId) {
    return _client
        .from('tutor_status_log')
        .select('status, changed_at')
        .eq('tutor_id', tutorId)
        .order('changed_at');
  }

  Future<List<String>> fetchCourseIdsForTutor(String tutorId) async {
    final rows = await _client
        .from('courses')
        .select('id')
        .eq('tutor_id', tutorId);
    return rows.map((r) => r['id'] as String).toList();
  }

  Future<List<String>> fetchCourseTermIds(List<String> courseIds) async {
    if (courseIds.isEmpty) return [];
    final rows = await _client
        .from('course_terms')
        .select('id')
        .inFilter('course_id', courseIds);
    return rows.map((r) => r['id'] as String).toList();
  }

  Future<List<Map<String, dynamic>>> fetchEnrollmentAmounts(
    List<String> courseTermIds,
  ) {
    if (courseTermIds.isEmpty) return Future.value([]);
    return _client
        .from('enrollments')
        .select('amount, currency')
        .inFilter('course_term_id', courseTermIds);
  }

  Future<List<Map<String, dynamic>>> fetchTutorLedger(String tutorId) {
    return _client
        .from('tutor_ledger')
        .select('amount, currency, equivalent_sar_amount')
        .eq('tutor_id', tutorId);
  }

  Future<List<Map<String, dynamic>>> fetchPrivateSessions(String tutorId) {
    return _client
        .from('private_sessions')
        .select('student_total, student_total_currency')
        .eq('tutor_id', tutorId);
  }
}
