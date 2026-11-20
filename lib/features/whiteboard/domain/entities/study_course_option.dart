/// A minimal, public-safe course entry for the free-study course picker —
/// deliberately not the full `Course` entity, since anon only has a
/// column-level grant on `id`/`subject_name` (see schema.sql).
class StudyCourseOption {
  const StudyCourseOption({required this.id, required this.subjectName});

  final String id;
  final String subjectName;

  factory StudyCourseOption.fromJson(Map<String, dynamic> json) {
    return StudyCourseOption(
      id: json['id'] as String,
      subjectName: json['subject_name'] as String,
    );
  }
}
