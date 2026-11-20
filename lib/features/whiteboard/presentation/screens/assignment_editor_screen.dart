import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/contact_links.dart';
import '../../../courses/domain/entities/course.dart';
import '../../../courses/presentation/providers/courses_providers.dart';
import '../../../courses/presentation/screens/drive_folder_picker_screen.dart';
import '../providers/whiteboard_providers.dart';

class AssignmentEditorScreen extends ConsumerStatefulWidget {
  const AssignmentEditorScreen({super.key});

  @override
  ConsumerState<AssignmentEditorScreen> createState() =>
      _AssignmentEditorScreenState();
}

class _AssignmentEditorScreenState
    extends ConsumerState<AssignmentEditorScreen> {
  final _titleController = TextEditingController();
  final _promptController = TextEditingController();
  final _driveLinkController = TextEditingController();
  final _videoLinkController = TextEditingController();
  Course? _course;
  DateTime? _dueAt;
  PlatformFile? _sourceFile;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _promptController.dispose();
    _driveLinkController.dispose();
    _videoLinkController.dispose();
    super.dispose();
  }

  Future<void> _pickSourceFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    final file = files.firstOrNull;
    if (file == null) return;
    setState(() => _sourceFile = file);
  }

  Future<void> _pickDriveLink() async {
    final link = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const DriveFolderPickerScreen()),
    );
    if (link == null) return;
    _driveLinkController.text = link;
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueAt = picked);
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      setState(() => _error = 'لازم تكتب عنوان للواجب');
      return;
    }
    if (_promptController.text.trim().isEmpty && _sourceFile == null) {
      setState(() => _error = 'لازم تكتب نص المسألة أو ترفع ملف PDF/صورة');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(whiteboardRepositoryProvider);

      String? sourcePath;
      String? sourceType;
      final file = _sourceFile;
      if (file != null) {
        sourceType = file.extension?.toLowerCase() == 'pdf' ? 'pdf' : 'image';
        sourcePath = await repo.uploadQuestionSource(
          bytes: await file.readAsBytes(),
          fileName: file.name,
        );
      }

      final question = await repo.addQuestion(
        subjectPack: _course?.subjectName ?? 'عام',
        prompt: _promptController.text.trim().isEmpty
            ? 'حل المسألة المرفقة'
            : _promptController.text.trim(),
        sourcePath: sourcePath,
        sourceType: sourceType,
        referenceDriveLink: _driveLinkController.text.trim().isEmpty
            ? null
            : _driveLinkController.text.trim(),
        referenceVideoLink: _videoLinkController.text.trim().isEmpty
            ? null
            : _videoLinkController.text.trim(),
        language: 'ar',
      );

      final assignment = await repo.addAssignment(
        title: _titleController.text.trim(),
        courseId: _course?.id,
        questionIds: [question.id],
        dueAt: _dueAt,
      );
      await repo.setAssignmentPublished(assignment.id, true);

      if (!mounted) return;
      await _showLinkDialog(assignment.id, assignment.title);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = 'حصل خطأ أثناء الحفظ: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showLinkDialog(String assignmentId, String title) async {
    final link =
        'https://studyhubacademy.github.io/studyhub-app-web/#/whiteboard/$assignmentId';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✅ الواجب جاهز'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SelectableText(
              link,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: link));
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('اتنسخ اللينك')));
            },
            child: const Text('نسخ'),
          ),
          ElevatedButton(
            onPressed: () => shareLink(link),
            child: const Text('مشاركة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final courses =
        (ref.watch(coursesProvider).valueOrNull ?? [])
            .where((c) => c.status == 'active')
            .toList()
          ..sort((a, b) => a.subjectName.compareTo(b.subjectName));

    return Scaffold(
      appBar: AppBar(title: const Text('واجب سبورة جديد')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'عنوان الواجب'),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<Course?>(
              initialValue: _course,
              decoration: const InputDecoration(
                labelText: 'المادة (اختار الكورس)',
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('بدون كورس')),
                ...courses.map(
                  (c) => DropdownMenuItem(value: c, child: Text(c.subjectName)),
                ),
              ],
              onChanged: (v) => setState(() {
                _course = v;
                // Every course already has its own Drive materials link —
                // reuse it as the whiteboard's subject reference instead of
                // asking the owner to pick one again.
                if (v?.materialsLink != null) {
                  _driveLinkController.text = v!.materialsLink!;
                }
              }),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _promptController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'نص المسألة (لو مفيش ملف مرفق)',
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _pickSourceFile,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(
                _sourceFile == null
                    ? 'ارفع ملف المسألة (PDF أو صورة)'
                    : 'مرفق: ${_sourceFile!.name}',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _driveLinkController,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'رابط مرجع المادة (معبّى تلقائي من ملفات الكورس)',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.folder_outlined),
                  tooltip: 'اختار رابط تاني من Drive',
                  onPressed: _pickDriveLink,
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _videoLinkController,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'رابط فيديو الشرح (تيليجرام مثلًا، اختياري)',
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: _pickDueDate,
              child: Text(
                _dueAt == null
                    ? 'موعد التسليم (اختياري)'
                    : intl.DateFormat('d MMMM yyyy', 'ar').format(_dueAt!),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('حفظ ومشاركة اللينك'),
            ),
          ],
        ),
      ),
    );
  }
}
