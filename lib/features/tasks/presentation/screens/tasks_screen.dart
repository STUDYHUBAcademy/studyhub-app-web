import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/realtime_error_view.dart';
import '../../domain/entities/task.dart';
import '../providers/tasks_providers.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  Future<void> _addTask(BuildContext context, WidgetRef ref) async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    DateTime? dueDate;
    String? formError;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: const Text('إضافة مهمة'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'العنوان'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bodyController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'تفاصيل (اختياري)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dueDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => dueDate = picked);
                    },
                    child: Text(
                      dueDate == null
                          ? 'تاريخ التسليم (اختياري)'
                          : intl.DateFormat(
                              'd MMMM yyyy',
                              'ar',
                            ).format(dueDate!),
                    ),
                  ),
                  if (formError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      formError!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) {
                  setState(() => formError = 'لازم تكتب عنوان المهمة');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    if (titleController.text.trim().isEmpty) return;
    await ref
        .read(tasksRepositoryProvider)
        .addTask(
          title: titleController.text.trim(),
          body: bodyController.text.trim().isEmpty
              ? null
              : bodyController.text.trim(),
          dueDate: dueDate,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('✅ المهام والملاحظات')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addTask(context, ref),
        child: const Icon(Icons.add),
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => RealtimeErrorView(
          error: err,
          onRetry: () => ref.invalidate(tasksProvider),
        ),
        data: (tasks) {
          if (tasks.isEmpty) {
            return const Center(
              child: Text(
                'لسه مفيش مهام مسجلة',
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }
          final open = tasks.where((t) => t.status == 'open').toList();
          final done = tasks.where((t) => t.status == 'done').toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
            children: [
              if (open.isNotEmpty) ...[
                const Text(
                  'مهام مفتوحة',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ...open.map((t) => _TaskTile(task: t)),
              ],
              if (done.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'مهام منجزة',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                ...done.map((t) => _TaskTile(task: t)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = task.status == 'done';
    final overdue =
        !done && task.dueDate != null && task.dueDate!.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Checkbox(
          value: done,
          onChanged: (v) => ref
              .read(tasksRepositoryProvider)
              .updateTaskStatus(task.id, v == true ? 'done' : 'open'),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: done ? TextDecoration.lineThrough : null,
            color: done ? AppColors.textMuted : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.body != null && task.body!.isNotEmpty)
              Text(
                task.body!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            if (task.dueDate != null)
              Text(
                intl.DateFormat('d MMMM yyyy', 'ar').format(task.dueDate!),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: overdue ? AppColors.error : AppColors.textMuted,
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: () =>
              ref.read(tasksRepositoryProvider).deleteTask(task.id),
        ),
      ),
    );
  }
}
