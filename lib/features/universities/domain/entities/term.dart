const semesterLabels = {
  'first': 'الفصل الأول',
  'second': 'الفصل الثاني',
  'summer': 'الفصل الصيفي',
};

class Term {
  const Term({
    required this.id,
    required this.name,
    this.semester,
    this.academicYear,
    this.startDate,
    this.endDate,
    required this.status,
  });

  final String id;
  final String name;
  final String? semester; // first | second | summer
  final String? academicYear; // e.g. "2025/2026"
  final DateTime? startDate;
  final DateTime? endDate;
  final String status; // upcoming | active | closed

  factory Term.fromJson(Map<String, dynamic> json) {
    return Term(
      id: json['id'] as String,
      name: json['name'] as String,
      semester: json['semester'] as String?,
      academicYear: json['academic_year'] as String?,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      status: json['status'] as String? ?? 'upcoming',
    );
  }
}
