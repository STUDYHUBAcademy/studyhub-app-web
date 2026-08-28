class PrivateSession {
  const PrivateSession({
    required this.id,
    this.tutorId,
    this.studentId,
    required this.subject,
    this.scheduledAt,
    required this.durationMinutes,
    this.studentHourlyRate,
    this.studentTotal,
    required this.studentTotalCurrency,
    this.studentAmountReceived,
    required this.paymentMethod,
    this.tutorHourlyRate,
    this.tutorPayout,
    required this.tutorPayoutCurrency,
    required this.status,
    required this.studentPaid,
    required this.tutorPaid,
    this.materialNote,
    required this.writeOffAmount,
    this.writeOffReason,
    this.acquisitionSource,
    this.marketerName,
    this.commissionPct,
    this.commissionAmount,
    required this.createdAt,
  });

  final String id;
  final String? tutorId;
  final String? studentId;
  final String subject;
  final DateTime? scheduledAt;
  final int durationMinutes;
  final double? studentHourlyRate;
  final double? studentTotal;
  final String studentTotalCurrency;

  /// Net amount actually received from the student after payment-processor
  /// fees (Tabby/Tamara installment cuts etc). Null means assume the full
  /// effective total (after any write-off) was received.
  final double? studentAmountReceived;
  final String paymentMethod; // cash | visa | tabby | tamara
  final double? tutorHourlyRate;
  final double? tutorPayout;
  final String tutorPayoutCurrency;
  final String status; // scheduled | completed | cancelled
  final bool studentPaid;
  final bool tutorPaid;
  final String? materialNote;

  /// A permanent reduction of what's owed — a discount, or a gateway cut the
  /// academy never sees. Mirrors Enrollment.writeOffAmount.
  final double writeOffAmount;
  final String? writeOffReason;

  /// Per-session override of how this student came to this specific
  /// session — null means "use the student's own default".
  final String? acquisitionSource;
  final String? marketerName;
  final double? commissionPct;

  /// Flat commission owed to the marketer for this session specifically —
  /// used instead of [commissionPct] when the source is 'marketer'.
  final double? commissionAmount;
  final DateTime createdAt;

  /// What's actually still expected from the student for this session —
  /// the contracted total minus any discount/gateway-fee write-off.
  double get effectiveTotal => (studentTotal ?? 0) - writeOffAmount;

  factory PrivateSession.fromJson(Map<String, dynamic> json) {
    return PrivateSession(
      id: json['id'] as String,
      tutorId: json['tutor_id'] as String?,
      studentId: json['student_id'] as String?,
      subject: json['subject'] as String? ?? '',
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.parse(json['scheduled_at'] as String).toLocal()
          : null,
      durationMinutes: json['duration_minutes'] as int? ?? 60,
      studentHourlyRate: (json['student_hourly_rate'] as num?)?.toDouble(),
      studentTotal: (json['student_total'] as num?)?.toDouble(),
      studentTotalCurrency: json['student_total_currency'] as String? ?? 'SAR',
      studentAmountReceived: (json['student_amount_received'] as num?)
          ?.toDouble(),
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      tutorHourlyRate: (json['tutor_hourly_rate'] as num?)?.toDouble(),
      tutorPayout: (json['tutor_payout'] as num?)?.toDouble(),
      tutorPayoutCurrency: json['tutor_payout_currency'] as String? ?? 'EGP',
      status: json['status'] as String? ?? 'scheduled',
      studentPaid: json['student_paid'] as bool? ?? false,
      tutorPaid: json['tutor_paid'] as bool? ?? false,
      materialNote: json['material_note'] as String?,
      writeOffAmount: (json['write_off_amount'] as num?)?.toDouble() ?? 0,
      writeOffReason: json['write_off_reason'] as String?,
      acquisitionSource: json['acquisition_source'] as String?,
      marketerName: json['marketer_name'] as String?,
      commissionPct: (json['commission_pct'] as num?)?.toDouble(),
      commissionAmount: (json['commission_amount'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
