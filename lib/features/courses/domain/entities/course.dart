class Course {
  const Course({
    required this.id,
    required this.subjectName,
    this.universityId,
    this.tutorId,
    this.firstTermId,
    this.materialsLink,
    this.demoLink,
    this.groupLink,
    required this.status,
    required this.explanationStatus,
    required this.createdAt,
  });

  final String id;
  final String subjectName;
  final String? universityId;
  final String? tutorId;
  final String? firstTermId;
  final String? materialsLink;
  final String? demoLink;
  final String? groupLink;
  final String status; // planning | active | inactive | archived
  final String explanationStatus; // not_started | in_progress | completed
  final DateTime createdAt;

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as String,
      subjectName: json['subject_name'] as String,
      universityId: json['university_id'] as String?,
      tutorId: json['tutor_id'] as String?,
      firstTermId: json['first_term_id'] as String?,
      materialsLink: json['materials_link'] as String?,
      demoLink: json['demo_link'] as String?,
      groupLink: json['group_link'] as String?,
      status: json['status'] as String? ?? 'planning',
      explanationStatus: json['explanation_status'] as String? ?? 'not_started',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
