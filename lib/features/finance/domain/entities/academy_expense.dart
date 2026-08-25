const expenseCategoryLabels = {
  'admin': 'مصاريف إدارية',
  'ads': 'إعلانات',
  'subscriptions': 'اشتراكات وأدوات',
  'other': 'أخرى',
};

class AcademyExpense {
  const AcademyExpense({
    required this.id,
    required this.category,
    required this.name,
    required this.amount,
    required this.currency,
    required this.date,
    this.notes,
  });

  final String id;
  final String category; // admin | ads | subscriptions | other
  final String name;
  final double amount;
  final String currency;
  final DateTime date;
  final String? notes;

  factory AcademyExpense.fromJson(Map<String, dynamic> json) {
    return AcademyExpense(
      id: json['id'] as String,
      category: json['category'] as String? ?? 'other',
      name: json['name'] as String? ?? '',
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'SAR',
      date: DateTime.parse(json['date'] as String),
      notes: json['notes'] as String?,
    );
  }
}
