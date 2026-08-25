import '../../domain/entities/tutor.dart';
import '../../domain/entities/tutor_application.dart';
import '../../domain/entities/tutor_finance_summary.dart';
import '../../domain/entities/tutor_status_period.dart';
import '../../domain/repositories/tutors_repository.dart';
import '../datasources/tutors_remote_datasource.dart';

class TutorsRepositoryImpl implements TutorsRepository {
  TutorsRepositoryImpl(this._remote);

  final TutorsRemoteDatasource _remote;

  @override
  Stream<List<TutorApplication>> watchApplications() {
    return _remote.watchApplications().map(
      (rows) => rows.map(TutorApplication.fromJson).toList(),
    );
  }

  @override
  Stream<List<Tutor>> watchTutors() {
    return _remote.watchTutors().map(
      (rows) => rows.map(Tutor.fromJson).toList(),
    );
  }

  @override
  Future<bool> tutorExistsFor(TutorApplication application) {
    return _remote.tutorExists(
      applicationId: application.id,
      email: application.email,
      phonePrimary: application.phonePrimary,
      phoneWhatsapp: application.phoneWhatsapp,
    );
  }

  @override
  Future<void> promoteApplication(TutorApplication application) async {
    // Same person may have applied more than once (or a retry after a
    // partial failure re-promotes the same application) — don't create a
    // second roster entry for someone already there.
    final alreadyExists = await tutorExistsFor(application);
    if (!alreadyExists) {
      await _remote.insertTutor({
        'application_id': application.id,
        'name': application.name,
        'phone_primary': application.phonePrimary,
        'phone_whatsapp': application.phoneWhatsapp,
        'email': application.email,
        'demo_link': application.demoLink,
        'faculty': application.graduationFaculty,
        'subjects': application.subjects,
        // Promoted tutors start inactive — they're vetted into the roster
        // but not yet assigned to a course/demo, so 'active' would overstate it.
        'status': 'inactive',
      });
    }
    await _remote.updateApplicationStatus(application.id, 'promoted');
  }

  @override
  Future<Tutor> addTutorQuick(String name) async {
    final row = await _remote.insertTutor({
      'name': name,
      'subjects': [],
      'status': 'active',
    });
    return Tutor.fromJson(row);
  }

  @override
  Future<void> rejectApplication(String applicationId) {
    return _remote.updateApplicationStatus(applicationId, 'rejected');
  }

  @override
  Future<void> setTutorStatus(String tutorId, String status) {
    return _remote.updateTutorStatus(tutorId, status);
  }

  @override
  Future<void> setTutorFeatured(String tutorId, bool featured) {
    return _remote.updateTutorFeatured(tutorId, featured);
  }

  @override
  Future<void> deleteTutor(String tutorId) {
    return _remote.deleteTutor(tutorId);
  }

  @override
  Future<void> deleteApplication(String applicationId) {
    return _remote.deleteApplication(applicationId);
  }

  @override
  Future<List<TutorStatusPeriod>> getStatusHistory(String tutorId) async {
    final rows = await _remote.fetchStatusLog(tutorId);
    final log = rows
        .map(
          (r) => (
            status: r['status'] as String,
            changedAt: DateTime.parse(r['changed_at'] as String),
          ),
        )
        .toList();
    return TutorStatusPeriod.fromLog(log);
  }

  @override
  Future<TutorFinanceSummary> getFinanceSummary(String tutorId) async {
    final courseIds = await _remote.fetchCourseIdsForTutor(tutorId);
    final courseTermIds = await _remote.fetchCourseTermIds(courseIds);
    final enrollments = await _remote.fetchEnrollmentAmounts(courseTermIds);
    final ledger = await _remote.fetchTutorLedger(tutorId);
    final sessions = await _remote.fetchPrivateSessions(tutorId);

    final revenue = <String, double>{};
    final paid = <String, double>{};
    var paidSarEquivalent = 0.0;

    void addTo(Map<String, double> map, String? currency, num? amount) {
      if (currency == null || amount == null) return;
      map[currency] = (map[currency] ?? 0) + amount.toDouble();
    }

    for (final e in enrollments) {
      addTo(revenue, e['currency'] as String?, e['amount'] as num?);
    }
    for (final l in ledger) {
      final currency = l['currency'] as String?;
      final amount = (l['amount'] as num?)?.toDouble();
      addTo(paid, currency, amount);
      if (amount != null) {
        paidSarEquivalent += currency == 'SAR'
            ? amount
            : ((l['equivalent_sar_amount'] as num?)?.toDouble() ?? 0);
      }
    }
    // Tutor payouts for sessions are tracked via tutor_ledger (like course
    // payments) rather than the session's own target amount, so `paid` only
    // ever comes from `ledger` above — avoids double-counting.
    for (final s in sessions) {
      addTo(
        revenue,
        s['student_total_currency'] as String?,
        s['student_total'] as num?,
      );
    }

    return TutorFinanceSummary(
      revenueByCurrency: revenue,
      paidByCurrency: paid,
      paidSarEquivalent: paidSarEquivalent,
    );
  }
}
