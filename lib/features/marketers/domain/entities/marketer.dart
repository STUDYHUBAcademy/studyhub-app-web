class Marketer {
  const Marketer({
    required this.id,
    required this.name,
    this.phoneWhatsapp,
    this.defaultCommissionAmount,
    this.notes,
  });

  final String id;
  final String name;
  final String? phoneWhatsapp;

  /// Default commission (a flat amount, not a percentage) suggested whenever
  /// this marketer is picked for a new enrollment/session — still editable
  /// per-transaction.
  final double? defaultCommissionAmount;
  final String? notes;

  factory Marketer.fromJson(Map<String, dynamic> json) {
    return Marketer(
      id: json['id'] as String,
      name: json['name'] as String,
      phoneWhatsapp: json['phone_whatsapp'] as String?,
      defaultCommissionAmount: (json['default_commission_amount'] as num?)
          ?.toDouble(),
      notes: json['notes'] as String?,
    );
  }
}
