import 'stroke.dart';

class WbSubmission {
  const WbSubmission({
    required this.id,
    required this.assignmentId,
    required this.questionId,
    this.studentId,
    required this.studentName,
    this.studentPhone,
    required this.status,
    required this.strokes,
    this.durationMs,
    this.aiScore,
    this.aiMaxScore,
    this.aiFeedback,
    this.aiGradedAt,
    required this.createdAt,
  });

  final String id;
  final String assignmentId;
  final String questionId;
  final String? studentId;
  final String studentName;
  final String? studentPhone;
  final String status; // 'draft' | 'submitted'
  final List<Stroke> strokes;
  final int? durationMs;
  final double? aiScore;
  final double? aiMaxScore;
  final String? aiFeedback;
  final DateTime? aiGradedAt;
  final DateTime createdAt;

  bool get isGraded => aiGradedAt != null;

  factory WbSubmission.fromJson(Map<String, dynamic> json) {
    final rawStrokes = json['strokes'] as List? ?? [];
    return WbSubmission(
      id: json['id'] as String,
      assignmentId: json['assignment_id'] as String,
      questionId: json['question_id'] as String,
      studentId: json['student_id'] as String?,
      studentName: json['student_name'] as String,
      studentPhone: json['student_phone'] as String?,
      status: json['status'] as String? ?? 'submitted',
      strokes: rawStrokes
          .map((s) => Stroke.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
      durationMs: json['duration_ms'] as int?,
      aiScore: (json['ai_score'] as num?)?.toDouble(),
      aiMaxScore: (json['ai_max_score'] as num?)?.toDouble(),
      aiFeedback: json['ai_feedback'] as String?,
      aiGradedAt: json['ai_graded_at'] == null
          ? null
          : DateTime.parse(json['ai_graded_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Result of an on-demand AI grading call — returned immediately so the UI
/// doesn't have to wait on a Realtime round-trip to show it, even though the
/// same values also land on the submission row via [WhiteboardRepository.gradeSubmission].
class WbGradingResult {
  const WbGradingResult({
    required this.score,
    required this.maxScore,
    required this.feedback,
  });

  final double score;
  final double maxScore;
  final String feedback;

  factory WbGradingResult.fromJson(Map<String, dynamic> json) {
    return WbGradingResult(
      score: (json['score'] as num).toDouble(),
      maxScore: (json['max_score'] as num).toDouble(),
      feedback: json['feedback'] as String,
    );
  }
}
