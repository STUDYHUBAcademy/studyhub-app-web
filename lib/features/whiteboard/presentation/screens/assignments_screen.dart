import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/contact_links.dart';
import '../../../../core/widgets/realtime_error_view.dart';
import '../providers/whiteboard_providers.dart';
import 'assignment_editor_screen.dart';
import 'quick_canvas_screen.dart';
import 'submissions_screen.dart';

const _studyModeLink = 'https://studyhubacademy.github.io/studyhub-app-web/#/study';

class AssignmentsScreen extends ConsumerWidget {
  const AssignmentsScreen({super.key});

  Future<void> _shareStudyModeLink(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🧠 المذاكرة الحرة بالذكاء الاصطناعي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'لينك عام لأي طالب — يختار مادة من مواد الأكاديمي ويذاكر عليه '
              'والذكاء الاصطناعي يصحح له أول بأول.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
            const SizedBox(height: 10),
            SelectableText(
              _studyModeLink,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: _studyModeLink));
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('اتنسخ اللينك')));
            },
            child: const Text('نسخ'),
          ),
          ElevatedButton(
            onPressed: () => shareLink(_studyModeLink),
            child: const Text('مشاركة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(wbAssignmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🧑‍🏫 السبورة الذكية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology_outlined),
            tooltip: 'مشاركة لينك المذاكرة الحرة',
            onPressed: () => _shareStudyModeLink(context),
          ),
          IconButton(
            icon: const Icon(Icons.draw_outlined),
            tooltip: 'فتح سبورة فارغة',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const QuickCanvasScreen(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const AssignmentEditorScreen(),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('واجب جديد'),
      ),
      body: assignmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => RealtimeErrorView(
          error: err,
          onRetry: () => ref.invalidate(wbAssignmentsProvider),
        ),
        data: (assignments) {
          if (assignments.isEmpty) {
            return const Center(
              child: Text(
                'لسه مفيش واجبات مضافة',
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
            itemCount: assignments.length,
            itemBuilder: (context, i) {
              final a = assignments[i];
              final submissions = ref
                  .watch(wbSubmissionsProvider(a.id))
                  .valueOrNull;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(
                    a.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    [
                      '${submissions?.length ?? 0} تسليم',
                      if (a.dueAt != null)
                        'الموعد ${intl.DateFormat('d MMM', 'ar').format(a.dueAt!)}',
                      if (!a.isPublished) 'موقّف',
                    ].join(' • '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => SubmissionsScreen(assignment: a),
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
