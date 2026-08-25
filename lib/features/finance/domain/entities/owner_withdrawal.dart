class OwnerWithdrawal {
  const OwnerWithdrawal({
    required this.id,
    required this.profileId,
    required this.amount,
    required this.currency,
    required this.date,
    this.notes,
  });

  final String id;
  final String profileId;
  final double amount;
  final String currency;
  final DateTime date;
  final String? notes;

  factory OwnerWithdrawal.fromJson(Map<String, dynamic> json) {
    return OwnerWithdrawal(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'SAR',
      date: DateTime.parse(json['date'] as String),
      notes: json['notes'] as String?,
    );
  }
}
