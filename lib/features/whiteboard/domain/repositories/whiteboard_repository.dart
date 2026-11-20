import 'dart:typed_data';

import '../entities/live_check_result.dart';
import '../entities/stroke.dart';
import '../entities/wb_assignment.dart';
import '../entities/wb_question.dart';
import '../entities/wb_submission.dart';

abstract class WhiteboardRepository {
  // Owner side (authenticated) ----------------------------------------------
  Stream<List<WbQuestion>> watchQuestions();
  Stream<List<WbAssignment>> watchAssignments();
  Stream<List<WbSubmission>> watchSubmissions(String assignmentId);

  Future<WbQuestion> addQuestion({
    required String subjectPack,
    required String prompt,
    String? sourcePath,
    String? sourceType,
    String? referenceDriveLink,
    String? referenceVideoLink,
    String? modelAnswer,
    double maxScore,
    required String language,
  });

  Future<WbAssignment> addAssignment({
    required String title,
    String? courseId,
    required List<String> questionIds,
    DateTime? dueAt,
  });

  Future<void> setAssignmentPublished(String id, bool isPublished);

  /// Uploads a question's source file (PDF or image) to the `wb-figures`
  /// bucket and returns its storage path (stored as `wb_questions.source_path`).
  Future<String> uploadQuestionSource({
    required Uint8List bytes,
    required String fileName,
  });

  String publicUrlFor(String storagePath);

  // Public/anonymous side (the shared /whiteboard/:id link) ------------------
  Future<WbAssignment?> fetchPublishedAssignment(String id);
  Future<List<WbQuestion>> fetchQuestions(List<String> ids);

  Future<void> submitWork({
    required String assignmentId,
    required String questionId,
    required String studentName,
    String? studentPhone,
    required List<Stroke> strokes,
    int? durationMs,
  });

  /// Grades a submission with AI from an already-rasterized PNG of its
  /// strokes (+ background), and persists the result on the submission row.
  Future<WbGradingResult> gradeSubmission({
    required String submissionId,
    required Uint8List imageBytes,
  });

  /// Live, in-progress check while a student is still writing — public/
  /// anonymous-safe (no session required), unlike [gradeSubmission]. Not
  /// persisted anywhere; purely for instant on-screen feedback.
  Future<LiveCheckResult> liveCheck({
    required String questionId,
    required Uint8List imageBytes,
  });
}
