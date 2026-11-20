import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/realtime_error_view.dart';
import '../providers/whiteboard_providers.dart';
import 'assignment_editor_screen.dart';
import 'submissions_screen.dart';

class AssignmentsScreen extends ConsumerWidget {
  const AssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(wbAssignmentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('🧑‍🏫 السبورة الذكية')),
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
