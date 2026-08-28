import '../../domain/entities/course.dart';
import '../../domain/entities/course_demo.dart';
import '../../domain/entities/course_term.dart';
import '../../domain/entities/enrollment.dart';
import '../../domain/entities/enrollment_payment.dart';
import '../../domain/entities/tutor_payment.dart';
import '../../domain/repositories/courses_repository.dart';
import '../datasources/courses_remote_datasource.dart';

class CoursesRepositoryImpl implements CoursesRepository {
  CoursesRepositoryImpl(this._remote);

  final CoursesRemoteDatasource _remote;

  @override
  Stream<List<Course>> watchCourses() {
    return _remote.watchCourses().map(
      (rows) => rows.map(Course.fromJson).toList(),
    );
  }

  @override
  Stream<List<CourseDemo>> watchDemos(String courseId) {
    return _remote
        .watchDemos(courseId)
        .map((rows) => rows.map(CourseDemo.fromJson).toList());
  }

  @override
  Stream<List<CourseTerm>> watchCourseTerms(String courseId) {
    return _remote
        .watchCourseTerms(courseId)
        .map((rows) => rows.map(CourseTerm.fromJson).toList());
  }

  @override
  Stream<List<CourseTerm>> watchAllCourseTerms() {
    return _remote.watchAllCourseTerms().map(
      (rows) => rows.map(CourseTerm.fromJson).toList(),
    );
  }

  @override
  Stream<List<Enrollment>> watchEnrollments(String courseTermId) {
    return _remote
        .watchEnrollments(courseTermId)
        .map((rows) => rows.map(Enrollment.fromJson).toList());
  }

  @override
  Stream<List<Enrollment>> watchAllEnrollments() {
    return _remote.watchAllEnrollments().map(
      (rows) => rows.map(Enrollment.fromJson).toList(),
    );
  }

  @override
  Future<Course> addCourse({
    required String subjectName,
    String? universityId,
    String? firstTermId,
    String? demoLink,
  }) async {
    final row = await _remote.addCourse({
      'subject_name': subjectName,
      'university_id': universityId,
      'first_term_id': firstTermId,
      'demo_link': demoLink,
      'status': 'planning',
    });
    return Course.fromJson(row);
  }

  @override
  Future<void> updateCourseStatus(String courseId, String status) {
    return _remote.updateCourse(courseId, {'status': status});
  }

  @override
  Future<void> updateCourseDetails({
    required String courseId,
    required String subjectName,
    String? universityId,
    String? firstTermId,
  }) {
    return _remote.updateCourse(courseId, {
      'subject_name': subjectName,
      'university_id': universityId,
      'first_term_id': firstTermId,
    });
  }

  @override
  Future<void> updateCourseMaterialsLink(String courseId, String? link) {
    return _remote.updateCourse(courseId, {'materials_link': link});
  }

  @override
  Future<void> updateCourseDemoLink(String courseId, String? link) {
    return _remote.updateCourse(courseId, {'demo_link': link});
  }

  @override
  Future<void> updateCourseGroupLink(String courseId, String? link) {
    return _remote.updateCourse(courseId, {'group_link': link});
  }

  @override
  Future<void> updateCourseExplanationStatus(String courseId, String status) {
    return _remote.updateCourse(courseId, {'explanation_status': status});
  }

  @override
  Future<void> deleteCourse(String courseId) => _remote.deleteCourse(courseId);

  @override
  Future<void> addDemo({
    required String courseId,
    required String tutorId,
    DateTime? demoAt,
    String? notes,
  }) {
    return _remote.addDemo({
      'course_id': courseId,
      'tutor_id': tutorId,
      'demo_at': demoAt?.toUtc().toIso8601String(),
      'notes': notes,
    });
  }

  @override
  Future<void> setDemoOutcome(CourseDemo demo, String outcome) async {
    await _remote.setDemoOutcome(demo.id, outcome);
    if (outcome == 'selected') {
      await _remote.updateCourse(demo.courseId, {
        'tutor_id': demo.tutorId,
        'status': 'active',
      });
      await _remote.rejectOtherDemos(demo.courseId, demo.id);
    }
  }

  @override
  Future<void> deleteDemo(CourseDemo demo) async {
    await _remote.deleteDemo(demo.id);
    if (demo.outcome == 'selected') {
      await _remote.updateCourse(demo.courseId, {
        'tutor_id': null,
        'status': 'planning',
      });
    }
  }

  @override
  Future<void> addCourseTerm({
    required String courseId,
    required String termId,
    String? pricingModelOverride,
    double? tutorFlatFee,
    String tutorFlatFeeCurrency = 'EGP',
    double revsharePct = 10,
    double? studentPrice,
    String studentPriceCurrency = 'SAR',
  }) async {
    String pricingModel = pricingModelOverride ?? 'flat';
    if (pricingModelOverride == null) {
      final existingCount = await _remote.countExistingCourseTerms(courseId);
      pricingModel = existingCount == 0 ? 'flat' : 'revshare';
    }
    await _remote.addCourseTerm({
      'course_id': courseId,
      'term_id': termId,
      'pricing_model': pricingModel,
      'tutor_flat_fee': tutorFlatFee,
      'tutor_flat_fee_currency': tutorFlatFeeCurrency,
      'revshare_pct': revsharePct,
      'student_price': studentPrice,
      'student_price_currency': studentPriceCurrency,
      'status': 'planning',
    });
    // Adding a term (e.g. reopening a course for a new academic term) means the course is in use again.
    await _remote.updateCourse(courseId, {'status': 'active'});
  }

  @override
  Future<void> updateCourseTermStatus(String id, String status) {
    return _remote.updateCourseTerm(id, {'status': status});
  }

  @override
  Future<void> deleteCourseTerm(String id) => _remote.deleteCourseTerm(id);

  @override
  Future<void> addEnrollment({
    required String courseTermId,
    required String studentId,
    required double amount,
    required String currency,
    String paymentStatus = 'pending',
    String paymentMethod = 'cash',
    String? acquisitionSource,
    String? marketerName,
    double? commissionPct,
    double? commissionAmount,
  }) {
    return _remote.addEnrollment({
      'course_term_id': courseTermId,
      'student_id': studentId,
      'amount': amount,
      'currency': currency,
      'payment_status': paymentStatus,
      'payment_method': paymentMethod,
      'acquisition_source': ?acquisitionSource,
      'marketer_name': ?marketerName,
      'commission_pct': ?commissionPct,
      'commission_amount': ?commissionAmount,
    });
  }

  @override
  Future<void> updateEnrollmentPaymentStatus(String id, String status) {
    return _remote.updateEnrollmentPaymentStatus(id, status);
  }

  @override
  Future<void> updateEnrollmentStatus(String id, String status) {
    return _remote.updateEnrollmentStatus(id, status);
  }

  @override
  Future<void> updateEnrollmentSource({
    required String id,
    required String? acquisitionSource,
    String? marketerName,
    double? commissionPct,
    double? commissionAmount,
  }) {
    return _remote.updateEnrollmentSource(id, {
      'acquisition_source': acquisitionSource,
      'marketer_name': marketerName,
      'commission_pct': commissionPct,
      'commission_amount': commissionAmount,
    });
  }

  @override
  Stream<List<EnrollmentPayment>> watchEnrollmentPayments(String enrollmentId) {
    return _remote
        .watchEnrollmentPayments(enrollmentId)
        .map((rows) => rows.map(EnrollmentPayment.fromJson).toList());
  }

  @override
  Stream<List<EnrollmentPayment>> watchAllEnrollmentPayments() {
    return _remote.watchAllEnrollmentPayments().map(
      (rows) => rows.map(EnrollmentPayment.fromJson).toList(),
    );
  }

  @override
  Future<void> addEnrollmentPayment({
    required String enrollmentId,
    required double amount,
    required String currency,
    String paymentMethod = 'cash',
    String? notes,
  }) async {
    await _remote.addEnrollmentPayment({
      'enrollment_id': enrollmentId,
      'amount': amount,
      'currency': currency,
      'payment_method': paymentMethod,
      'notes': notes,
    });
    await _recomputeEnrollmentStatus(enrollmentId);
  }

  @override
  Future<void> addEnrollmentWriteOff({
    required String enrollmentId,
    required double amount,
    required String reason,
  }) async {
    final enrollment = await _remote.fetchEnrollment(enrollmentId);
    final currentWriteOff =
        (enrollment['write_off_amount'] as num?)?.toDouble() ?? 0;
    await _remote.updateEnrollmentWriteOff(
      enrollmentId,
      currentWriteOff + amount,
      reason,
    );
    await _recomputeEnrollmentStatus(enrollmentId);
  }

  /// Re-derives payment_status from actual installments + write-offs against
  /// the effective amount owed (contracted amount minus any write-off). Never
  /// overrides an explicit 'overdue' the owner set manually.
  Future<void> _recomputeEnrollmentStatus(String enrollmentId) async {
    final enrollment = await _remote.fetchEnrollment(enrollmentId);
    final currentStatus = enrollment['payment_status'] as String? ?? 'pending';
    if (currentStatus == 'overdue') return;

    final totalAmount = (enrollment['amount'] as num?)?.toDouble() ?? 0;
    final writeOff = (enrollment['write_off_amount'] as num?)?.toDouble() ?? 0;
    final effectiveAmount = totalAmount - writeOff;
    final paymentRows = await _remote.fetchEnrollmentPaymentAmounts(
      enrollmentId,
    );
    final paidSoFar = paymentRows.fold<double>(
      0,
      (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0),
    );
    // A fully written-off enrollment (effectiveAmount <= 0) has nothing left
    // to collect, so it counts as settled even with zero cash received.
    final remaining = effectiveAmount - paidSoFar;
    final newStatus = remaining <= 0.01
        ? 'paid'
        : (paidSoFar > 0 ? 'partial' : 'pending');
    if (newStatus != currentStatus) {
      await _remote.updateEnrollmentPaymentStatus(enrollmentId, newStatus);
    }
  }

  @override
  Future<void> updateEnrollmentPayment({
    required String id,
    required String enrollmentId,
    required double amount,
    required String currency,
    String paymentMethod = 'cash',
    String? notes,
  }) async {
    await _remote.updateEnrollmentPayment(id, {
      'amount': amount,
      'currency': currency,
      'payment_method': paymentMethod,
      'notes': notes,
    });
    await _recomputeEnrollmentStatus(enrollmentId);
  }

  @override
  Future<void> deleteEnrollmentPayment({
    required String id,
    required String enrollmentId,
  }) async {
    await _remote.deleteEnrollmentPayment(id);
    await _recomputeEnrollmentStatus(enrollmentId);
  }

  @override
  Stream<List<TutorPayment>> watchTutorLedger(String tutorId) {
    return _remote
        .watchTutorLedger(tutorId)
        .map((rows) => rows.map(TutorPayment.fromJson).toList());
  }

  @override
  Stream<List<TutorPayment>> watchAllTutorLedger() {
    return _remote.watchAllTutorLedger().map(
      (rows) => rows.map(TutorPayment.fromJson).toList(),
    );
  }

  @override
  Future<void> addTutorPayment({
    required String tutorId,
    String? courseTermId,
    String? privateSessionId,
    required double amount,
    required String currency,
    double? equivalentSarAmount,
    String type = 'deposit',
    String? notes,
  }) {
    return _remote.addTutorLedgerEntry({
      'tutor_id': tutorId,
      'course_term_id': courseTermId,
      'private_session_id': privateSessionId,
      'amount': amount,
      'currency': currency,
      'equivalent_sar_amount': equivalentSarAmount,
      'type': type,
      'notes': notes,
    });
  }

  @override
  Future<void> updateTutorPayment({
    required String id,
    required double amount,
    required String currency,
    double? equivalentSarAmount,
    String? notes,
  }) {
    return _remote.updateTutorLedgerEntry(id, {
      'amount': amount,
      'currency': currency,
      'equivalent_sar_amount': equivalentSarAmount,
      'notes': notes,
    });
  }
}
