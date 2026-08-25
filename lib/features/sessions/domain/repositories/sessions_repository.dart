import '../entities/private_session.dart';

abstract class SessionsRepository {
  Stream<List<PrivateSession>> watchSessions();

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
  });

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
  });

  Future<void> updateSessionStatus(String id, String status);
  Future<void> updateSessionPaymentFlags(
    String id, {
    bool? studentPaid,
    bool? tutorPaid,
  });
  Future<void> deleteSession(String id);
}
