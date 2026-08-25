class CourseTerm {
  const CourseTerm({
    required this.id,
    required this.courseId,
    required this.termId,
    required this.pricingModel,
    this.tutorFlatFee,
    required this.tutorFlatFeeCurrency,
    required this.revsharePct,
    this.studentPrice,
    required this.studentPriceCurrency,
    required this.status,
  });

  final String id;
  final String courseId;
  final String termId;
  final String pricingModel; // flat | revshare
  final double? tutorFlatFee;
  final String tutorFlatFeeCurrency;
  final double revsharePct;
  final double? studentPrice;
  final String studentPriceCurrency;
  final String status; // planning | marketing | active | completed | cancelled

  factory CourseTerm.fromJson(Map<String, dynamic> json) {
    return CourseTerm(
      id: json['id'] as String,
      courseId: json['course_id'] as String,
      termId: json['term_id'] as String,
      pricingModel: json['pricing_model'] as String? ?? 'flat',
      tutorFlatFee: (json['tutor_flat_fee'] as num?)?.toDouble(),
      tutorFlatFeeCurrency: json['tutor_flat_fee_currency'] as String? ?? 'EGP',
      revsharePct: (json['revshare_pct'] as num?)?.toDouble() ?? 10,
      studentPrice: (json['student_price'] as num?)?.toDouble(),
      studentPriceCurrency: json['student_price_currency'] as String? ?? 'SAR',
      status: json['status'] as String? ?? 'planning',
    );
  }
}
