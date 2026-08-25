import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_client.dart';
import '../../data/datasources/courses_remote_datasource.dart';
import '../../data/repositories/courses_repository_impl.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/course_demo.dart';
import '../../domain/entities/course_term.dart';
import '../../domain/entities/enrollment.dart';
import '../../domain/entities/enrollment_payment.dart';
import '../../domain/entities/tutor_payment.dart';
import '../../domain/repositories/courses_repository.dart';

final coursesRemoteDatasourceProvider = Provider<CoursesRemoteDatasource>((
  ref,
) {
  return CoursesRemoteDatasource(AppSupabase.client);
});

final coursesRepositoryProvider = Provider<CoursesRepository>((ref) {
  return CoursesRepositoryImpl(ref.watch(coursesRemoteDatasourceProvider));
});

final coursesProvider = StreamProvider<List<Course>>((ref) {
  return ref.watch(coursesRepositoryProvider).watchCourses();
});

final courseDemosProvider = StreamProvider.family<List<CourseDemo>, String>((
  ref,
  courseId,
) {
  return ref.watch(coursesRepositoryProvider).watchDemos(courseId);
});

final courseTermsProvider = StreamProvider.family<List<CourseTerm>, String>((
  ref,
  courseId,
) {
  return ref.watch(coursesRepositoryProvider).watchCourseTerms(courseId);
});

/// Every course term across every course — feeds the dashboard's
/// remaining-owed-to-tutors KPI.
final allCourseTermsProvider = StreamProvider<List<CourseTerm>>((ref) {
  return ref.watch(coursesRepositoryProvider).watchAllCourseTerms();
});

final enrollmentsProvider = StreamProvider.family<List<Enrollment>, String>((
  ref,
  courseTermId,
) {
  return ref.watch(coursesRepositoryProvider).watchEnrollments(courseTermId);
});

/// Every enrollment across every course/term — feeds the dashboard's
/// academy-wide revenue and pending-payment KPIs.
final allEnrollmentsProvider = StreamProvider<List<Enrollment>>((ref) {
  return ref.watch(coursesRepositoryProvider).watchAllEnrollments();
});

final tutorLedgerProvider = StreamProvider.family<List<TutorPayment>, String>((
  ref,
  tutorId,
) {
  return ref.watch(coursesRepositoryProvider).watchTutorLedger(tutorId);
});

/// Every ledger entry across every tutor — feeds the dashboard's
/// academy-wide payout/net-profit KPIs.
final allTutorLedgerProvider = StreamProvider<List<TutorPayment>>((ref) {
  return ref.watch(coursesRepositoryProvider).watchAllTutorLedger();
});

final enrollmentPaymentsProvider =
    StreamProvider.family<List<EnrollmentPayment>, String>((ref, enrollmentId) {
      return ref
          .watch(coursesRepositoryProvider)
          .watchEnrollmentPayments(enrollmentId);
    });

/// Every installment across every enrollment — feeds the dashboard's
/// outstanding-course-fees KPI.
final allEnrollmentPaymentsProvider = StreamProvider<List<EnrollmentPayment>>((
  ref,
) {
  return ref.watch(coursesRepositoryProvider).watchAllEnrollmentPayments();
});
