class TutorPayment {
  const TutorPayment({
    required this.id,
    required this.tutorId,
    this.courseTermId,
    this.privateSessionId,
    required this.amount,
    required this.currency,
    this.equivalentSarAmount,
    required this.type,
    required this.date,
    this.notes,
  });

  final String id;
  final String tutorId;
  final String? courseTermId;
  final String? privateSessionId;
  final double amount;
  final String currency;
  final double? equivalentSarAmount;
  final String type;
  final DateTime date;
  final String? notes;

  factory TutorPayment.fromJson(Map<String, dynamic> json) {
    return TutorPayment(
      id: json['id'] as String,
      tutorId: json['tutor_id'] as String,
      courseTermId: json['course_term_id'] as String?,
      privateSessionId: json['private_session_id'] as String?,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      equivalentSarAmount: (json['equivalent_sar_amount'] as num?)?.toDouble(),
      type: json['type'] as String,
      date: DateTime.parse(json['date'] as String),
      notes: json['notes'] as String?,
    );
  }
}
