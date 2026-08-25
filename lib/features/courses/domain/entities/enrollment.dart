const enrollmentWriteOffReasons = {
  'discount': 'خصم للطالب',
  'gateway_fee': 'رسوم بوابة دفع (تابي/تمارا/فيزا)',
  'other': 'أخرى',
};

class Enrollment {
  const Enrollment({
    required this.id,
    required this.courseTermId,
    required this.studentId,
    required this.amount,
    required this.currency,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.status,
    required this.writeOffAmount,
    this.writeOffReason,
    this.acquisitionSource,
    this.marketerName,
    this.commissionPct,
    required this.joinedAt,
  });

  final String id;
  final String courseTermId;
  final String studentId;
  final double amount;
  final String currency;
  final String paymentStatus; // pending | partial | paid | overdue
  final String paymentMethod; // cash | visa | tabby | tamara
  final String status; // active | cancelled
  final double writeOffAmount;
  final String? writeOffReason;

  /// Per-enrollment override of how this student came to this specific
  /// course — null means "use the student's own default" (see
  /// Student.acquisitionSource), since the same student can arrive via a
  /// marketer for one course and directly for another.
  final String? acquisitionSource;
  final String? marketerName;
  final double? commissionPct;
  final DateTime joinedAt;

  /// What's actually still expected from the student — the contracted
  /// amount minus any discount/gateway-fee write-off recorded against it.
  double get effectiveAmount => amount - writeOffAmount;

  factory Enrollment.fromJson(Map<String, dynamic> json) {
    return Enrollment(
      id: json['id'] as String,
      courseTermId: json['course_term_id'] as String,
      studentId: json['student_id'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'SAR',
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      status: json['status'] as String? ?? 'active',
      writeOffAmount: (json['write_off_amount'] as num?)?.toDouble() ?? 0,
      writeOffReason: json['write_off_reason'] as String?,
      acquisitionSource: json['acquisition_source'] as String?,
      marketerName: json['marketer_name'] as String?,
      commissionPct: (json['commission_pct'] as num?)?.toDouble(),
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }
}
