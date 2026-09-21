import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/realtime_error_view.dart';
import '../../../courses/domain/entities/course.dart';
import '../../../courses/presentation/providers/courses_providers.dart';
import '../../domain/entities/task.dart';
import '../providers/tasks_providers.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  Future<void> _addTask(BuildContext context, WidgetRef ref) async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    DateTime? dueDate;
    Course? linkedCourse;
    String? formError;
    final courses = (ref.read(coursesProvider).valueOrNull ?? [])
      ..sort((a, b) => a.subjectName.compareTo(b.subjectName));

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
                  DropdownButtonFormField<Course?>(
                    initialValue: linkedCourse,
                    decoration: const InputDecoration(
                      labelText: 'مرتبطة بكورس (اختياري)',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('بدون كورس'),
                      ),
                      ...courses.map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.subjectName),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => linkedCourse = v),
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
          linkedCourseId: linkedCourse?.id,
        );
  }

  Future<void> _editTask(BuildContext context, WidgetRef ref, Task task) async {
    final titleController = TextEditingController(text: task.title);
    final bodyController = TextEditingController(text: task.body ?? '');
    final progressController = TextEditingController(
      text: task.progressNote ?? '',
    );
    DateTime? dueDate = task.dueDate;
    String? formError;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: const Text('تعديل المهمة'),
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
                  TextField(
                    controller: progressController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات التقدم (لحد فين وصلت)',
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
        .updateTask(
          id: task.id,
          title: titleController.text.trim(),
          body: bodyController.text.trim().isEmpty
              ? null
              : bodyController.text.trim(),
          dueDate: dueDate,
          progressNote: progressController.text.trim().isEmpty
              ? null
              : progressController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('✅ المهام والملاحظات'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'مطلوب إنجازه'),
              Tab(text: 'مكتمل'),
            ],
          ),
        ),
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
            final open = tasks.where((t) => t.status != 'done').toList();
            final done = tasks.where((t) => t.status == 'done').toList();
            return TabBarView(
              children: [
                _TasksList(
                  tasks: open,
                  emptyMessage: 'لسه مفيش مهام مطلوبة',
                  onTapTask: (t) => _editTask(context, ref, t),
                ),
                _TasksList(
                  tasks: done,
                  emptyMessage: 'لسه مفيش مهام مكتملة',
                  onTapTask: (t) => _editTask(context, ref, t),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TasksList extends StatelessWidget {
  const _TasksList({
    required this.tasks,
    required this.emptyMessage,
    required this.onTapTask,
  });

  final List<Task> tasks;
  final String emptyMessage;
  final void Function(Task) onTapTask;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      itemCount: tasks.length,
      itemBuilder: (context, i) =>
          _TaskTile(task: tasks[i], onTap: () => onTapTask(tasks[i])),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.task, required this.onTap});

  final Task task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = task.status == 'done';
    final overdue =
        !done && task.dueDate != null && task.dueDate!.isBefore(DateTime.now());
    final courseName = task.linkedCourseId == null
        ? null
        : (ref.watch(coursesProvider).valueOrNull ?? [])
              .where((c) => c.id == task.linkedCourseId)
              .firstOrNull
              ?.subjectName;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
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
            if (courseName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '📘 $courseName',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
            if (task.body != null && task.body!.isNotEmpty)
              Text(
                task.body!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            if (task.progressNote != null && task.progressNote!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '📝 ${task.progressNote!}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.accent,
                  ),
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
