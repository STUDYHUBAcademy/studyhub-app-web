class Student {
  const Student({
    required this.id,
    required this.name,
    this.phoneWhatsapp,
    this.universityId,
    this.acquisitionSource = 'direct',
    this.marketerName,
    this.commissionPct,
  });

  final String id;
  final String name;
  final String? phoneWhatsapp;
  final String? universityId;

  /// direct | haraj | marketer — where this student came from.
  final String acquisitionSource;
  final String? marketerName;

  /// Percentage of the revenue this student generates that's owed as
  /// commission — fixed at 1 for 'haraj', negotiated per-marketer otherwise.
  final double? commissionPct;

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as String,
      name: json['name'] as String,
      phoneWhatsapp: json['phone_whatsapp'] as String?,
      universityId: json['university_id'] as String?,
      acquisitionSource: json['acquisition_source'] as String? ?? 'direct',
      marketerName: json['marketer_name'] as String?,
      commissionPct: (json['commission_pct'] as num?)?.toDouble(),
    );
  }
}
