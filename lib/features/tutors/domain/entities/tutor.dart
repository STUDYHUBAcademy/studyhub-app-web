class Tutor {
  const Tutor({
    required this.id,
    this.applicationId,
    required this.name,
    this.phonePrimary,
    this.phoneWhatsapp,
    this.email,
    this.demoLink,
    this.faculty,
    required this.subjects,
    required this.status,
    required this.isFeatured,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String? applicationId;
  final String name;
  final String? phonePrimary;
  final String? phoneWhatsapp;
  final String? email;
  final String? demoLink;
  final Map<String, dynamic>? faculty;
  final List<Map<String, dynamic>> subjects;
  final String status; // active | inactive
  final bool isFeatured;
  final String? notes;
  final DateTime createdAt;

  String get facultyLabel {
    final dept = faculty?['deptTitle'] as String?;
    final cat = faculty?['catTitle'] as String?;
    if (dept == null && cat == null) return 'غير محدد';
    return [dept, cat].whereType<String>().join(' — ');
  }

  factory Tutor.fromJson(Map<String, dynamic> json) {
    return Tutor(
      id: json['id'] as String,
      applicationId: json['application_id'] as String?,
      name: json['name'] as String? ?? '',
      phonePrimary: json['phone_primary'] as String?,
      phoneWhatsapp: json['phone_whatsapp'] as String?,
      email: json['email'] as String?,
      demoLink: json['demo_link'] as String?,
      faculty: (json['faculty'] as Map?)?.cast<String, dynamic>(),
      subjects: ((json['subjects'] as List?) ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList(),
      status: json['status'] as String? ?? 'active',
      isFeatured: json['is_featured'] as bool? ?? false,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
