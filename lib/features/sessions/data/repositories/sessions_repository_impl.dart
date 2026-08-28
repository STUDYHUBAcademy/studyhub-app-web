import '../../domain/entities/private_session.dart';
import '../../domain/repositories/sessions_repository.dart';
import '../datasources/sessions_remote_datasource.dart';

class SessionsRepositoryImpl implements SessionsRepository {
  SessionsRepositoryImpl(this._remote);

  final SessionsRemoteDatasource _remote;

  @override
  Stream<List<PrivateSession>> watchSessions() {
    return _remote.watchSessions().map(
      (rows) => rows.map(PrivateSession.fromJson).toList(),
    );
  }

  Map<String, dynamic> _payload({
    required String tutorId,
    required String studentId,
    required String subject,
    DateTime? scheduledAt,
    required int durationMinutes,
    double? studentHourlyRate,
    double? studentTotal,
    required String studentTotalCurrency,
    double? studentAmountReceived,
    required String paymentMethod,
    double? tutorHourlyRate,
    double? tutorPayout,
    required String tutorPayoutCurrency,
    String? materialNote,
    double writeOffAmount = 0,
    String? writeOffReason,
    String? acquisitionSource,
    String? marketerName,
    double? commissionPct,
    double? commissionAmount,
  }) {
    return {
      'tutor_id': tutorId,
      'student_id': studentId,
      'subject': subject,
      'scheduled_at': scheduledAt?.toUtc().toIso8601String(),
      'duration_minutes': durationMinutes,
      'student_hourly_rate': studentHourlyRate,
      'student_total': studentTotal,
      'student_total_currency': studentTotalCurrency,
      'student_amount_received': studentAmountReceived,
      'payment_method': paymentMethod,
      'tutor_hourly_rate': tutorHourlyRate,
      'tutor_payout': tutorPayout,
      'tutor_payout_currency': tutorPayoutCurrency,
      'material_note': materialNote,
      'write_off_amount': writeOffAmount,
      'write_off_reason': writeOffReason,
      'acquisition_source': acquisitionSource,
      'marketer_name': marketerName,
      'commission_pct': commissionPct,
      'commission_amount': commissionAmount,
    };
  }

  @override
  Future<PrivateSession> addSession({
    required String tutorId,
    required String studentId,
    required String subject,
    DateTime? scheduledAt,
    required int durationMinutes,
    double? studentHourlyRate,
    double? studentTotal,
    required String studentTotalCurrency,
    double? studentAmountReceived,
    required String paymentMethod,
    double? tutorHourlyRate,
    double? tutorPayout,
    required String tutorPayoutCurrency,
    String? materialNote,
    double writeOffAmount = 0,
    String? writeOffReason,
    String? acquisitionSource,
    String? marketerName,
    double? commissionPct,
    double? commissionAmount,
  }) async {
    final payload = _payload(
      tutorId: tutorId,
      studentId: studentId,
      subject: subject,
      scheduledAt: scheduledAt,
      durationMinutes: durationMinutes,
      studentHourlyRate: studentHourlyRate,
      studentTotal: studentTotal,
      studentTotalCurrency: studentTotalCurrency,
      studentAmountReceived: studentAmountReceived,
      paymentMethod: paymentMethod,
      tutorHourlyRate: tutorHourlyRate,
      tutorPayout: tutorPayout,
      tutorPayoutCurrency: tutorPayoutCurrency,
      materialNote: materialNote,
      writeOffAmount: writeOffAmount,
      writeOffReason: writeOffReason,
      acquisitionSource: acquisitionSource,
      marketerName: marketerName,
      commissionPct: commissionPct,
      commissionAmount: commissionAmount,
    )..['status'] = 'scheduled';
    final row = await _remote.addSession(payload);
    return PrivateSession.fromJson(row);
  }

  @override
  Future<void> updateSession({
    required String id,
    required String tutorId,
    required String studentId,
    required String subject,
    DateTime? scheduledAt,
    required int durationMinutes,
    double? studentHourlyRate,
    double? studentTotal,
    required String studentTotalCurrency,
    double? studentAmountReceived,
    required String paymentMethod,
    double? tutorHourlyRate,
    double? tutorPayout,
    required String tutorPayoutCurrency,
    String? materialNote,
    double writeOffAmount = 0,
    String? writeOffReason,
    String? acquisitionSource,
    String? marketerName,
    double? commissionPct,
    double? commissionAmount,
  }) {
    return _remote.updateSession(
      id,
      _payload(
        tutorId: tutorId,
        studentId: studentId,
        subject: subject,
        scheduledAt: scheduledAt,
        durationMinutes: durationMinutes,
        studentHourlyRate: studentHourlyRate,
        studentTotal: studentTotal,
        studentTotalCurrency: studentTotalCurrency,
        studentAmountReceived: studentAmountReceived,
        paymentMethod: paymentMethod,
        tutorHourlyRate: tutorHourlyRate,
        tutorPayout: tutorPayout,
        tutorPayoutCurrency: tutorPayoutCurrency,
        materialNote: materialNote,
        writeOffAmount: writeOffAmount,
        writeOffReason: writeOffReason,
        acquisitionSource: acquisitionSource,
        marketerName: marketerName,
        commissionPct: commissionPct,
        commissionAmount: commissionAmount,
      ),
    );
  }

  @override
  Future<void> updateSessionStatus(String id, String status) {
    return _remote.updateSession(id, {'status': status});
  }

  @override
  Future<void> updateSessionPaymentFlags(
    String id, {
    bool? studentPaid,
    bool? tutorPaid,
  }) {
    final patch = <String, dynamic>{};
    if (studentPaid != null) patch['student_paid'] = studentPaid;
    if (tutorPaid != null) patch['tutor_paid'] = tutorPaid;
    return _remote.updateSession(id, patch);
  }

  @override
  Future<void> deleteSession(String id) => _remote.deleteSession(id);
}
