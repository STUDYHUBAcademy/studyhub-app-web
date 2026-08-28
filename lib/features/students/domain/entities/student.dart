class Student {
  const Student({
    required this.id,
    required this.name,
    this.phoneWhatsapp,
    this.universityId,
    this.acquisitionSource = 'direct',
    this.marketerName,
    this.commissionPct,
    this.commissionAmount,
  });

  final String id;
  final String name;
  final String? phoneWhatsapp;
  final String? universityId;

  /// direct | haraj | marketer — where this student came from.
  final String acquisitionSource;
  final String? marketerName;

  /// Percentage of the revenue this student generates that's owed as
  /// commission — fixed at 1 for 'haraj'. Not used for 'marketer' (see
  /// [commissionAmount]).
  final double? commissionPct;

  /// Flat commission amount owed to the marketer — used instead of a
  /// percentage since marketer deals are negotiated as a fixed sum.
  final double? commissionAmount;

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as String,
      name: json['name'] as String,
      phoneWhatsapp: json['phone_whatsapp'] as String?,
      universityId: json['university_id'] as String?,
      acquisitionSource: json['acquisition_source'] as String? ?? 'direct',
      marketerName: json['marketer_name'] as String?,
      commissionPct: (json['commission_pct'] as num?)?.toDouble(),
      commissionAmount: (json['commission_amount'] as num?)?.toDouble(),
    );
  }
}
