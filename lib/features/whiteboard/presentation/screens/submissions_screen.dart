import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/realtime_error_view.dart';
import '../../domain/entities/wb_assignment.dart';
import '../../domain/entities/wb_submission.dart';
import '../providers/whiteboard_providers.dart';
import '../widgets/whiteboard_canvas.dart';

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
                  trailing: const Icon(Icons.chevron_left_rounded),
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

/// Static, read-only render of a submission's strokes — no AI grading or
/// animated replay in this phase (that's Phase 2/4 of the spec).
class _SubmissionReviewScreen extends StatelessWidget {
  const _SubmissionReviewScreen({required this.submission});

  final WbSubmission submission;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(submission.studentName)),
      body: InteractiveViewer(
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
    );
  }
}
