import '../entities/tutor.dart';
import '../entities/tutor_application.dart';
import '../entities/tutor_finance_summary.dart';
import '../entities/tutor_status_period.dart';

abstract class TutorsRepository {
  Stream<List<TutorApplication>> watchApplications();
  Stream<List<Tutor>> watchTutors();

  /// Creates a `tutors` row from an application and marks it promoted.
  Future<void> promoteApplication(TutorApplication application);

  /// Lightweight tutor creation (name only) for quick-add flows like
  /// booking a private session for a tutor who isn't in the roster yet.
  Future<Tutor> addTutorQuick(String name);

  Future<void> rejectApplication(String applicationId);

  Future<void> setTutorStatus(String tutorId, String status);

  Future<void> setTutorFeatured(String tutorId, bool featured);

  Future<void> deleteTutor(String tutorId);

  Future<void> deleteApplication(String applicationId);

  /// True if a tutor already exists in the roster matching this
  /// application's email or phone — used to clean up applications left
  /// pending for someone who's already been added to القائمة another way.
  Future<bool> tutorExistsFor(TutorApplication application);

  Future<List<TutorStatusPeriod>> getStatusHistory(String tutorId);

  Future<TutorFinanceSummary> getFinanceSummary(String tutorId);
}
