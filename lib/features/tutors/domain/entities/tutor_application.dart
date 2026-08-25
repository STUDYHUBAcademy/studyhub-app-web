class TutorApplication {
  const TutorApplication({
    required this.id,
    required this.name,
    this.phonePrimary,
    this.phoneWhatsapp,
    this.email,
    this.demoLink,
    this.graduationFaculty,
    required this.subjects,
    required this.status,
    required this.submittedAt,
  });

  final String id;
  final String name;
  final String? phonePrimary;
  final String? phoneWhatsapp;
  final String? email;
  final String? demoLink;
  final Map<String, dynamic>? graduationFaculty;
  final List<Map<String, dynamic>> subjects;
  final String status; // new | promoted | rejected
  final DateTime submittedAt;

  String get facultyLabel {
    final dept = graduationFaculty?['deptTitle'] as String?;
    final cat = graduationFaculty?['catTitle'] as String?;
    if (dept == null && cat == null) return 'غير محدد';
    return [dept, cat].whereType<String>().join(' — ');
  }

  factory TutorApplication.fromJson(Map<String, dynamic> json) {
    return TutorApplication(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      phonePrimary: json['phone_primary'] as String?,
      phoneWhatsapp: json['phone_whatsapp'] as String?,
      email: json['email'] as String?,
      demoLink: json['demo_link'] as String?,
      graduationFaculty: (json['graduation_faculty'] as Map?)
          ?.cast<String, dynamic>(),
      subjects: ((json['subjects'] as List?) ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList(),
      status: json['status'] as String? ?? 'new',
      submittedAt: DateTime.parse(json['submitted_at'] as String),
    );
  }
}
