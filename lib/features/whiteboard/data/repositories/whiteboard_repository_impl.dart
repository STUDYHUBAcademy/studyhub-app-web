import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/live_check_result.dart';
import '../../domain/entities/stroke.dart';
import '../../domain/entities/wb_assignment.dart';
import '../../domain/entities/wb_question.dart';
import '../../domain/entities/wb_submission.dart';
import '../../domain/repositories/whiteboard_repository.dart';
import '../datasources/whiteboard_remote_datasource.dart';

class WhiteboardRepositoryImpl implements WhiteboardRepository {
  WhiteboardRepositoryImpl(this._remote, this._client);

  final WhiteboardRemoteDatasource _remote;
  final SupabaseClient _client;

  @override
  Stream<List<WbQuestion>> watchQuestions() {
    return _remote.watchQuestions().map(
      (rows) => rows.map(WbQuestion.fromJson).toList(),
    );
  }

  @override
  Stream<List<WbAssignment>> watchAssignments() {
    return _remote.watchAssignments().map(
      (rows) => rows.map(WbAssignment.fromJson).toList(),
    );
  }

  @override
  Stream<List<WbSubmission>> watchSubmissions(String assignmentId) {
    return _remote
        .watchSubmissions(assignmentId)
        .map((rows) => rows.map(WbSubmission.fromJson).toList());
  }

  @override
  Future<WbQuestion> addQuestion({
    required String subjectPack,
    required String prompt,
    String? sourcePath,
    String? sourceType,
    String? referenceDriveLink,
    String? referenceVideoLink,
    String? modelAnswer,
    double maxScore = 10,
    required String language,
  }) async {
    final row = await _remote.addQuestion({
      'teacher_id': _client.auth.currentUser?.id,
      'subject_pack': subjectPack,
      'prompt': prompt,
      'source_path': sourcePath,
      'source_type': sourceType,
      'reference_drive_link': referenceDriveLink,
      'reference_video_link': referenceVideoLink,
      'model_answer': modelAnswer,
      'max_score': maxScore,
      'language': language,
    });
    return WbQuestion.fromJson(row);
  }

  @override
  Future<WbAssignment> addAssignment({
    required String title,
    String? courseId,
    required List<String> questionIds,
    DateTime? dueAt,
  }) async {
    final row = await _remote.addAssignment({
      'teacher_id': _client.auth.currentUser?.id,
      'title': title,
      'course_id': courseId,
      'question_ids': questionIds,
      'due_at': dueAt?.toIso8601String(),
    });
    return WbAssignment.fromJson(row);
  }

  @override
  Future<void> setAssignmentPublished(String id, bool isPublished) {
    return _remote.setAssignmentPublished(id, isPublished);
  }

  @override
  Future<String> uploadQuestionSource({
    required Uint8List bytes,
    required String fileName,
  }) {
    return _remote.uploadQuestionSource(bytes, fileName);
  }

  @override
  String publicUrlFor(String storagePath) => _remote.publicUrlFor(storagePath);

  @override
  Future<WbAssignment?> fetchPublishedAssignment(String id) async {
    final row = await _remote.fetchPublishedAssignment(id);
    return row == null ? null : WbAssignment.fromJson(row);
  }

  @override
  Future<List<WbQuestion>> fetchQuestions(List<String> ids) async {
    final rows = await _remote.fetchQuestions(ids);
    return rows.map(WbQuestion.fromJson).toList();
  }

  @override
  Future<void> submitWork({
    required String assignmentId,
    required String questionId,
    required String studentName,
    String? studentPhone,
    required List<Stroke> strokes,
    int? durationMs,
  }) {
    return _remote.submitWork({
      'assignment_id': assignmentId,
      'question_id': questionId,
      'student_name': studentName,
      'student_phone': studentPhone,
      'status': 'submitted',
      'strokes': strokes.map((s) => s.toJson()).toList(),
      'duration_ms': durationMs,
    });
  }

  @override
  Future<WbGradingResult> gradeSubmission({
    required String submissionId,
    required Uint8List imageBytes,
  }) async {
    final result = await _remote.gradeSubmission(
      submissionId: submissionId,
      imageBase64: base64Encode(imageBytes),
    );
    return WbGradingResult.fromJson(result);
  }

  @override
  Future<LiveCheckResult> liveCheck({
    required String questionId,
    required Uint8List imageBytes,
  }) async {
    final result = await _remote.liveCheck(
      questionId: questionId,
      imageBase64: base64Encode(imageBytes),
    );
    return LiveCheckResult.fromJson(result);
  }
}
