import 'package:supabase_flutter/supabase_flutter.dart';

class CoursesRemoteDatasource {
  CoursesRemoteDatasource(this._client);

  final SupabaseClient _client;

  Stream<List<Map<String, dynamic>>> watchCourses() {
    return _client
        .from('courses')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> watchDemos(String courseId) {
    return _client
        .from('course_demos')
        .stream(primaryKey: ['id'])
        .eq('course_id', courseId)
        .order('created_at', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> watchCourseTerms(String courseId) {
    return _client
        .from('course_terms')
        .stream(primaryKey: ['id'])
        .eq('course_id', courseId)
        .order('created_at', ascending: false);
  }

  /// Every course term across every course — used by the dashboard to
  /// compute how much is still owed to tutors academy-wide.
  Stream<List<Map<String, dynamic>>> watchAllCourseTerms() {
    return _client
        .from('course_terms')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> watchEnrollments(String courseTermId) {
    return _client
        .from('enrollments')
        .stream(primaryKey: ['id'])
        .eq('course_term_id', courseTermId)
        .order('joined_at', ascending: false);
  }

  /// Every enrollment across every course/term — used by the dashboard to
  /// compute academy-wide revenue and pending-payment counts.
  Stream<List<Map<String, dynamic>>> watchAllEnrollments() {
    return _client
        .from('enrollments')
        .stream(primaryKey: ['id'])
        .order('joined_at', ascending: false);
  }

  Future<Map<String, dynamic>> addCourse(Map<String, dynamic> course) async {
    return _client.from('courses').insert(course).select().single();
  }

  Future<void> updateCourse(String id, Map<String, dynamic> patch) async {
    await _client.from('courses').update(patch).eq('id', id);
  }

  Future<void> deleteCourse(String id) async {
    await _client.from('courses').delete().eq('id', id);
  }

  Future<void> addDemo(Map<String, dynamic> demo) async {
    await _client.from('course_demos').insert(demo);
  }

  Future<void> setDemoOutcome(String demoId, String outcome) async {
    await _client
        .from('course_demos')
        .update({'outcome': outcome})
        .eq('id', demoId);
  }

  Future<void> rejectOtherPendingDemos(
    String courseId,
    String exceptDemoId,
  ) async {
    await _client
        .from('course_demos')
        .update({'outcome': 'rejected'})
        .eq('course_id', courseId)
        .eq('outcome', 'pending')
        .neq('id', exceptDemoId);
  }

  Future<int> countExistingCourseTerms(String courseId) async {
    final rows = await _client
        .from('course_terms')
        .select('id')
        .eq('course_id', courseId);
    return rows.length;
  }

  Future<void> addCourseTerm(Map<String, dynamic> courseTerm) async {
    await _client.from('course_terms').insert(courseTerm);
  }

  Future<void> updateCourseTerm(String id, Map<String, dynamic> patch) async {
    await _client.from('course_terms').update(patch).eq('id', id);
  }

  Future<void> addEnrollment(Map<String, dynamic> enrollment) async {
    await _client.from('enrollments').insert(enrollment);
  }

  Future<void> updateEnrollmentPaymentStatus(String id, String status) async {
    await _client
        .from('enrollments')
        .update({'payment_status': status})
        .eq('id', id);
  }

  Future<void> updateEnrollmentStatus(String id, String status) async {
    await _client.from('enrollments').update({'status': status}).eq('id', id);
  }

  Future<void> updateEnrollmentSource(
    String id,
    Map<String, dynamic> patch,
  ) async {
    await _client.from('enrollments').update(patch).eq('id', id);
  }

  Future<void> updateEnrollmentWriteOff(
    String id,
    double writeOffAmount,
    String reason,
  ) async {
    await _client
        .from('enrollments')
        .update({
          'write_off_amount': writeOffAmount,
          'write_off_reason': reason,
        })
        .eq('id', id);
  }

  Stream<List<Map<String, dynamic>>> watchEnrollmentPayments(
    String enrollmentId,
  ) {
    return _client
        .from('enrollment_payments')
        .stream(primaryKey: ['id'])
        .eq('enrollment_id', enrollmentId)
        .order('paid_at', ascending: false);
  }

  /// Every installment across every enrollment — used by the dashboard to
  /// compute how much is still owed on course fees academy-wide.
  Stream<List<Map<String, dynamic>>> watchAllEnrollmentPayments() {
    return _client
        .from('enrollment_payments')
        .stream(primaryKey: ['id'])
        .order('paid_at', ascending: false);
  }

  Future<void> addEnrollmentPayment(Map<String, dynamic> payment) async {
    await _client.from('enrollment_payments').insert(payment);
  }

  Future<void> updateEnrollmentPayment(
    String id,
    Map<String, dynamic> patch,
  ) async {
    await _client.from('enrollment_payments').update(patch).eq('id', id);
  }

  Future<void> deleteEnrollmentPayment(String id) async {
    await _client.from('enrollment_payments').delete().eq('id', id);
  }

  Future<Map<String, dynamic>> fetchEnrollment(String id) async {
    return _client.from('enrollments').select().eq('id', id).single();
  }

  Future<List<Map<String, dynamic>>> fetchEnrollmentPaymentAmounts(
    String enrollmentId,
  ) {
    return _client
        .from('enrollment_payments')
        .select('amount')
        .eq('enrollment_id', enrollmentId);
  }

  Stream<List<Map<String, dynamic>>> watchTutorLedger(String tutorId) {
    return _client
        .from('tutor_ledger')
        .stream(primaryKey: ['id'])
        .eq('tutor_id', tutorId)
        .order('date', ascending: false);
  }

  /// Every ledger entry across every tutor — used by the dashboard to
  /// compute academy-wide payouts and net profit.
  Stream<List<Map<String, dynamic>>> watchAllTutorLedger() {
    return _client
        .from('tutor_ledger')
        .stream(primaryKey: ['id'])
        .order('date', ascending: false);
  }

  Future<void> addTutorLedgerEntry(Map<String, dynamic> entry) async {
    await _client.from('tutor_ledger').insert(entry);
  }

  Future<void> updateTutorLedgerEntry(
    String id,
    Map<String, dynamic> patch,
  ) async {
    await _client.from('tutor_ledger').update(patch).eq('id', id);
  }
}
