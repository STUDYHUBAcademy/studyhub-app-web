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
  final DateTime createdAt;

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
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
