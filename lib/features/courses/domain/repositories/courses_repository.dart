import '../entities/course.dart';
import '../entities/course_demo.dart';
import '../entities/course_term.dart';
import '../entities/enrollment.dart';
import '../entities/enrollment_payment.dart';
import '../entities/tutor_payment.dart';

abstract class CoursesRepository {
  Stream<List<Course>> watchCourses();
  Stream<List<CourseDemo>> watchDemos(String courseId);
  Stream<List<CourseTerm>> watchCourseTerms(String courseId);
  Stream<List<CourseTerm>> watchAllCourseTerms();
  Stream<List<Enrollment>> watchEnrollments(String courseTermId);
  Stream<List<Enrollment>> watchAllEnrollments();
  Stream<List<TutorPayment>> watchTutorLedger(String tutorId);
  Stream<List<TutorPayment>> watchAllTutorLedger();
  Stream<List<EnrollmentPayment>> watchEnrollmentPayments(String enrollmentId);
  Stream<List<EnrollmentPayment>> watchAllEnrollmentPayments();

  /// Records one installment against an enrollment. Auto-flips the
  /// enrollment's payment_status to 'paid' once installments cover the full
  /// amount, to 'partial' otherwise — an explicit 'overdue' set by the owner
  /// is left alone.
  Future<void> addEnrollmentPayment({
    required String enrollmentId,
    required double amount,
    required String currency,
    String paymentMethod = 'cash',
    String? notes,
  });

  /// Permanently reduces what's owed on an enrollment (a discount, or a
  /// payment-gateway cut the academy never receives) without pretending
  /// it was paid in cash.
  Future<void> addEnrollmentWriteOff({
    required String enrollmentId,
    required double amount,
    required String reason,
  });

  Future<void> updateEnrollmentPayment({
    required String id,
    required String enrollmentId,
    required double amount,
    required String currency,
    String paymentMethod = 'cash',
    String? notes,
  });

  Future<void> deleteEnrollmentPayment({
    required String id,
    required String enrollmentId,
  });

  Future<Course> addCourse({
    required String subjectName,
    String? universityId,
    String? firstTermId,
    String? demoLink,
  });
  Future<void> updateCourseStatus(String courseId, String status);
  Future<void> updateCourseDetails({
    required String courseId,
    required String subjectName,
    String? universityId,
    String? firstTermId,
  });
  Future<void> updateCourseMaterialsLink(String courseId, String? link);
  Future<void> updateCourseDemoLink(String courseId, String? link);
  Future<void> updateCourseGroupLink(String courseId, String? link);

  Future<void> updateCourseNotes(String courseId, String? notes);
  Future<void> updateCourseExplanationStatus(String courseId, String status);
  Future<void> deleteCourse(String courseId);

  Future<void> addDemo({
    required String courseId,
    required String tutorId,
    DateTime? demoAt,
    String? notes,
  });

  /// Marking a demo 'selected' also sets the course's tutor and
  /// auto-rejects any other still-pending demos for the same course.
  Future<void> setDemoOutcome(CourseDemo demo, String outcome);

  /// Removes this candidate entirely (not just marks them rejected). If they
  /// were the selected tutor, also clears the course's tutor and reverts its
  /// status to planning so it doesn't point at a tutor with no demo record.
  Future<void> deleteDemo(CourseDemo demo);

  /// Defaults pricing_model to 'flat' for a course's first term and
  /// 'revshare' (10%) for any subsequent term, per the academy's standard deal.
  Future<void> addCourseTerm({
    required String courseId,
    required String termId,
    String? pricingModelOverride,
    double? tutorFlatFee,
    String tutorFlatFeeCurrency = 'EGP',
    double revsharePct = 10,
    double? studentPrice,
    String studentPriceCurrency = 'SAR',
  });

  Future<void> updateCourseTermStatus(String id, String status);

  /// Edits a term's pricing after it's already been created — e.g. the
  /// tutor's rate was set provisionally and needs correcting once the real
  /// deal is settled.
  Future<void> updateCourseTermPricing({
    required String id,
    required String pricingModel,
    double? tutorFlatFee,
    required String tutorFlatFeeCurrency,
    required double revsharePct,
    double? studentPrice,
    required String studentPriceCurrency,
  });

  /// Permanently removes a term — cascades to its enrollments/students, so
  /// callers should confirm with the owner before calling this.
  Future<void> deleteCourseTerm(String id);

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
  });

  Future<void> updateEnrollmentPaymentStatus(String id, String status);
  Future<void> updateEnrollmentStatus(String id, String status);

  /// Overrides how this specific enrollment is attributed, independent of
  /// the student's own default (see [Enrollment.acquisitionSource]).
  Future<void> updateEnrollmentSource({
    required String id,
    required String? acquisitionSource,
    String? marketerName,
    double? commissionPct,
    double? commissionAmount,
  });

  /// Exactly one of [courseTermId] / [privateSessionId] should be set to
  /// tie the payment back to what it's settling.
  Future<void> addTutorPayment({
    required String tutorId,
    String? courseTermId,
    String? privateSessionId,
    required double amount,
    required String currency,
    double? equivalentSarAmount,
    String type = 'deposit',
    String? notes,
  });

  Future<void> updateTutorPayment({
    required String id,
    required double amount,
    required String currency,
    double? equivalentSarAmount,
    String? notes,
  });
}
