class WbQuestion {
  const WbQuestion({
    required this.id,
    this.teacherId,
    required this.subjectPack,
    required this.prompt,
    this.sourcePath,
    this.sourceType,
    this.referenceDriveLink,
    this.referenceVideoLink,
    this.modelAnswer,
    this.maxScore = 10,
    required this.language,
    required this.createdAt,
  });

  final String id;
  final String? teacherId;
  final String subjectPack;
  final String prompt;
  final String? sourcePath;
  final String? sourceType; // 'pdf' | 'image'
  final String? referenceDriveLink;
  final String? referenceVideoLink;
  final String? modelAnswer;
  final double maxScore;
  final String language;
  final DateTime createdAt;

  factory WbQuestion.fromJson(Map<String, dynamic> json) {
    return WbQuestion(
      id: json['id'] as String,
      teacherId: json['teacher_id'] as String?,
      subjectPack: json['subject_pack'] as String? ?? 'math',
      prompt: json['prompt'] as String,
      sourcePath: json['source_path'] as String?,
      sourceType: json['source_type'] as String?,
      referenceDriveLink: json['reference_drive_link'] as String?,
      referenceVideoLink: json['reference_video_link'] as String?,
      modelAnswer: json['model_answer'] as String?,
      maxScore: (json['max_score'] as num?)?.toDouble() ?? 10,
      language: json['language'] as String? ?? 'ar',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
