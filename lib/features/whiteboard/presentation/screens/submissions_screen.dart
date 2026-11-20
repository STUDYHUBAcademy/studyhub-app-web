import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' as intl;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/realtime_error_view.dart';
import '../../domain/entities/wb_assignment.dart';
import '../../domain/entities/wb_question.dart';
import '../../domain/entities/wb_submission.dart';
import '../providers/whiteboard_providers.dart';
import '../widgets/whiteboard_canvas.dart';
import '../widgets/whiteboard_rasterizer.dart';

class SubmissionsScreen extends ConsumerWidget {
  const SubmissionsScreen({super.key, required this.assignment});

  final WbAssignment assignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissionsAsync = ref.watch(wbSubmissionsProvider(assignment.id));

    return Scaffold(
      appBar: AppBar(title: Text(assignment.title)),
      body: submissionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => RealtimeErrorView(
          error: err,
          onRetry: () => ref.invalidate(wbSubmissionsProvider(assignment.id)),
        ),
        data: (submissions) {
          if (submissions.isEmpty) {
            return const Center(
              child: Text(
                'لسه محدش سلّم الواجب ده',
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: submissions.length,
            itemBuilder: (context, i) {
              final s = submissions[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(
                    s.studentName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    [
                      ?s.studentPhone,
                      intl.DateFormat(
                        'd MMM yyyy — h:mm a',
                        'ar',
                      ).format(s.createdAt),
                      '${s.strokes.length} خط',
                    ].join(' • '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  trailing: s.isGraded
                      ? Chip(
                          label: Text(
                            '${s.aiScore!.toStringAsFixed(1)} / ${s.aiMaxScore!.toStringAsFixed(0)}',
                          ),
                          backgroundColor: AppColors.accentSoft,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        )
                      : const Icon(Icons.chevron_left_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          _SubmissionReviewScreen(submission: s),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Static render of a submission's strokes, with an on-demand
/// "صحّح بالذكاء الاصطناعي" action — no live replay yet (that's Phase 4 of
/// the spec).
class _SubmissionReviewScreen extends ConsumerStatefulWidget {
  const _SubmissionReviewScreen({required this.submission});

  final WbSubmission submission;

  @override
  ConsumerState<_SubmissionReviewScreen> createState() =>
      _SubmissionReviewScreenState();
}

class _SubmissionReviewScreenState
    extends ConsumerState<_SubmissionReviewScreen> {
  bool _grading = false;
  String? _error;

  Future<void> _grade(WbQuestion? question) async {
    setState(() {
      _grading = true;
      _error = null;
    });
    try {
      Uint8List? backgroundBytes;
      if (question?.sourcePath != null) {
        final repo = ref.read(whiteboardRepositoryProvider);
        final url = repo.publicUrlFor(question!.sourcePath!);
        final res = await http.get(Uri.parse(url));
        if (res.statusCode == 200) backgroundBytes = res.bodyBytes;
      }
      final image = await rasterizeSubmission(
        strokes: widget.submission.strokes,
        backgroundBytes: backgroundBytes,
        backgroundSourceType: question?.sourceType,
      );
      await ref
          .read(whiteboardRepositoryProvider)
          .gradeSubmission(submissionId: widget.submission.id, imageBytes: image);
      // The updated row arrives via the realtime-synced wbSubmissionsProvider
      // this screen reads below — nothing else to do here.
    } catch (e) {
      if (mounted) setState(() => _error = 'حصل خطأ أثناء التصحيح: $e');
    } finally {
      if (mounted) setState(() => _grading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = ref.watch(wbQuestionsProvider).valueOrNull ?? [];
    final question = questions
        .where((q) => q.id == widget.submission.questionId)
        .firstOrNull;

    // Pull the live row (realtime-synced) so a fresh grading result shows
    // up here without needing to pop back to the list first.
    final live = ref
        .watch(wbSubmissionsProvider(widget.submission.assignmentId))
        .valueOrNull
        ?.where((s) => s.id == widget.submission.id)
        .firstOrNull;
    final submission = live ?? widget.submission;

    return Scaffold(
      appBar: AppBar(title: Text(submission.studentName)),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              maxScale: 4,
              child: SizedBox(
                width: kWhiteboardPageWidth,
                height: kWhiteboardPageHeight,
                child: Container(
                  color: Colors.white,
                  child: CustomPaint(
                    painter: WhiteboardPainter(
                      strokes: submission.strokes,
                      liveStroke: null,
                      liveColor: Colors.black,
                      liveWidth: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (submission.isGraded) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 18,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'تصحيح الذكاء الاصطناعي: ${submission.aiScore!.toStringAsFixed(1)} / ${submission.aiMaxScore!.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(submission.aiFeedback!),
                    const SizedBox(height: 10),
                  ],
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: AppColors.error)),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _grading ? null : () => _grade(question),
                      icon: _grading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        submission.isGraded
                            ? 'إعادة التصحيح بالذكاء الاصطناعي'
                            : 'صحّح بالذكاء الاصطناعي',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
