class EnrollmentPayment {
  const EnrollmentPayment({
    required this.id,
    required this.enrollmentId,
    required this.amount,
    required this.currency,
    required this.paymentMethod,
    required this.paidAt,
    this.notes,
  });

  final String id;
  final String enrollmentId;
  final double amount;
  final String currency;
  final String paymentMethod;
  final DateTime paidAt;
  final String? notes;

  factory EnrollmentPayment.fromJson(Map<String, dynamic> json) {
    return EnrollmentPayment(
      id: json['id'] as String,
      enrollmentId: json['enrollment_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'SAR',
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      paidAt: DateTime.parse(json['paid_at'] as String),
      notes: json['notes'] as String?,
    );
  }
}
