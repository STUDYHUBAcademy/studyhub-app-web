import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/realtime_error_view.dart';
import '../../../courses/domain/entities/course.dart';
import '../../../courses/presentation/providers/courses_providers.dart';
import '../../domain/entities/note.dart';
import '../providers/notes_providers.dart';

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  Future<void> _addNote(BuildContext context, WidgetRef ref) async {
    final textController = TextEditingController();
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
          title: const Text('إضافة ملاحظة'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: textController,
                    maxLines: 4,
                    minLines: 2,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'اكتب ملاحظتك هنا...',
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
                if (textController.text.trim().isEmpty) {
                  setState(() => formError = 'لازم تكتب الملاحظة');
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
    if (textController.text.trim().isEmpty) return;
    await ref
        .read(notesRepositoryProvider)
        .addNote(
          text: textController.text.trim(),
          linkedCourseId: linkedCourse?.id,
        );
  }

  Future<void> _editNote(BuildContext context, WidgetRef ref, Note note) async {
    final textController = TextEditingController(text: note.text);
    String? formError;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: const Text('تعديل الملاحظة'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: textController,
                  maxLines: 5,
                  minLines: 2,
                  autofocus: true,
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (textController.text.trim().isEmpty) {
                  setState(() => formError = 'لازم تكتب الملاحظة');
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
    if (textController.text.trim().isEmpty) return;
    await ref
        .read(notesRepositoryProvider)
        .updateNote(id: note.id, text: textController.text.trim());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('🗒️ الملاحظات')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addNote(context, ref),
        child: const Icon(Icons.add),
      ),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => RealtimeErrorView(
          error: err,
          onRetry: () => ref.invalidate(notesProvider),
        ),
        data: (notes) {
          if (notes.isEmpty) {
            return const Center(
              child: Text(
                'لسه مفيش ملاحظات مسجلة',
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
            itemCount: notes.length,
            itemBuilder: (context, i) => _NoteTile(
              note: notes[i],
              onTap: () => _editNote(context, ref, notes[i]),
            ),
          );
        },
      ),
    );
  }
}

class _NoteTile extends ConsumerWidget {
  const _NoteTile({required this.note, required this.onTap});

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseName = note.linkedCourseId == null
        ? null
        : (ref.watch(coursesProvider).valueOrNull ?? [])
              .where((c) => c.id == note.linkedCourseId)
              .firstOrNull
              ?.subjectName;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        title: Text(note.text, style: const TextStyle(fontSize: 13)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (courseName != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 2),
                child: Text(
                  '📘 $courseName',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
            Text(
              intl.DateFormat('d MMMM yyyy', 'ar').format(note.createdAt),
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: () =>
              ref.read(notesRepositoryProvider).deleteNote(note.id),
        ),
      ),
    );
  }
}
