import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/services/google_drive_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/contact_links.dart';
import '../../../courses/domain/entities/course.dart';
import '../../../courses/presentation/providers/courses_providers.dart';
import '../../../courses/presentation/screens/drive_folder_picker_screen.dart';
import '../../quiz_link.dart';
import '../providers/quizzes_providers.dart';

class CreateQuizScreen extends ConsumerStatefulWidget {
  const CreateQuizScreen({super.key});

  @override
  ConsumerState<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends ConsumerState<CreateQuizScreen> {
  final _titleController = TextEditingController();
  final _videoLinkController = TextEditingController();
  final _questionsController = TextEditingController();
  final _driveService = GoogleDriveService();
  GoogleSignInAccount? _driveAccount;
  Course? _selectedCourse;
  String _direction = 'rtl';
  String _mode = 'ai';
  List<DriveItem> _selectedFiles = [];
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _videoLinkController.dispose();
    _questionsController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>>? _parseQuestions() {
    final raw = _questionsController.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'الصق مصفوفة الأسئلة (JSON) الأول');
      return null;
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (e) {
      setState(() => _error = 'الـ JSON مش مكتوب صح: $e');
      return null;
    }
    if (decoded is! List || decoded.isEmpty) {
      setState(
        () => _error = 'المفروض يكون مصفوفة أسئلة فيها عنصر واحد على الأقل',
      );
      return null;
    }
    final questions = <Map<String, dynamic>>[];
    for (var i = 0; i < decoded.length; i++) {
      final q = decoded[i];
      if (q is! Map ||
          q['text'] is! String ||
          q['options'] is! List ||
          (q['options'] as List).length < 2 ||
          q['correct_index'] is! int ||
          (q['correct_index'] as int) < 0 ||
          (q['correct_index'] as int) >= (q['options'] as List).length) {
        setState(
          () => _error =
              'السؤال رقم ${i + 1} ناقصه بيانات (text/options/correct_index) أو correct_index برة نطاق options',
        );
        return null;
      }
      questions.add(Map<String, dynamic>.from(q));
    }
    return questions;
  }

  Future<void> _submitManual() async {
    setState(() => _error = null);
    if (_titleController.text.trim().isEmpty) {
      setState(() => _error = 'اكتب عنوان الاختبار');
      return;
    }
    final questions = _parseQuestions();
    if (questions == null) return;

    setState(() => _saving = true);
    try {
      final quiz = await ref
          .read(quizzesRepositoryProvider)
          .addQuiz(
            title: _titleController.text.trim(),
            courseId: _selectedCourse?.id,
            videoLink: _videoLinkController.text.trim().isEmpty
                ? null
                : _videoLinkController.text.trim(),
            direction: _direction,
            questions: questions,
          );
      if (!mounted) return;
      await _showLinkDialog(quiz.id, quiz.title);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = 'حصل خطأ أثناء الحفظ: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickFiles() async {
    final selected = await Navigator.of(context).push<List<DriveItem>>(
      MaterialPageRoute(
        builder: (context) => DriveFolderPickerScreen(
          multiSelect: true,
          initialAccount: _driveAccount,
          onAccountResolved: (account) => _driveAccount = account,
        ),
      ),
    );
    if (selected == null) return;
    setState(() {
      _selectedFiles = selected;
      if (_titleController.text.trim().isEmpty && selected.isNotEmpty) {
        _titleController.text = _titleFromFileName(selected.first.name);
      }
    });
  }

  /// Strips a file extension (".pdf", ".pptx"...) so the auto-filled title
  /// doesn't carry it — still just a starting point, the owner can edit it.
  String _titleFromFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot > 0 ? fileName.substring(0, dot) : fileName;
  }

  /// Arabic noun/number agreement for "file(s) selected" — "1 ملفات" reads
  /// as broken Arabic, so this picks the grammatically correct form per
  /// count instead of blindly interpolating the number into a fixed string.
  String _selectedFilesLabel(int count) {
    switch (count) {
      case 0:
        return 'اختيار ملفات من Drive';
      case 1:
        return 'اختيار ملفات (ملف واحد مختار)';
      case 2:
        return 'اختيار ملفات (ملفين مختارين)';
      default:
        return count <= 10
            ? 'اختيار ملفات ($count ملفات مختارة)'
            : 'اختيار ملفات ($count ملف مختار)';
    }
  }

  Future<void> _generate() async {
    setState(() => _error = null);
    if (_titleController.text.trim().isEmpty) {
      setState(() => _error = 'اكتب عنوان الاختبار');
      return;
    }
    if (_selectedFiles.isEmpty) {
      setState(() => _error = 'اختار ملف واحد على الأقل من Drive');
      return;
    }

    setState(() => _saving = true);
    try {
      // Reuse the account the file picker already resolved — a *second*
      // independent silent sign-in attempt can spuriously fail on web
      // right after the interactive one that just succeeded.
      final account =
          _driveAccount ?? await _driveService.attemptSilentSignIn();
      if (account == null) {
        throw Exception('محتاج تسجّل دخول بحساب جوجل الأول (من زرار الملفات)');
      }
      final token = await _driveService.accessTokenFor(account);
      final quiz = await ref
          .read(quizzesRepositoryProvider)
          .generateQuiz(
            title: _titleController.text.trim(),
            courseId: _selectedCourse?.id,
            direction: _direction,
            files: _selectedFiles
                .map((f) => {'id': f.id, 'mime_type': f.mimeType})
                .toList(),
            driveAccessToken: token,
          );
      if (!mounted) return;
      await _showLinkDialog(quiz.id, quiz.title);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = 'حصل خطأ أثناء التوليد: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _browseDriveForLink() async {
    final link = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => DriveFolderPickerScreen(
          allowFiles: true,
          initialAccount: _driveAccount,
          onAccountResolved: (account) => _driveAccount = account,
        ),
      ),
    );
    if (link != null) _videoLinkController.text = link;
  }

  Future<void> _showLinkDialog(String quizId, String title) async {
    final link = quizLinkFor(quizId);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الاختبار جاهز ✅'),
        content: SelectableText(link, textDirection: TextDirection.ltr),
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
            onPressed: () {
              shareLink(link);
              Navigator.pop(context);
            },
            child: const Text('مشاركة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCourses =
        (ref.watch(coursesProvider).valueOrNull ?? [])
            .where((c) => c.status == 'active')
            .toList()
          ..sort((a, b) => a.subjectName.compareTo(b.subjectName));

    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء اختبار جديد')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<Course?>(
              initialValue: _selectedCourse,
              decoration: const InputDecoration(labelText: 'الكورس (اختياري)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('بدون كورس')),
                ...activeCourses.map(
                  (c) => DropdownMenuItem(value: c, child: Text(c.subjectName)),
                ),
              ],
              onChanged: (v) => setState(() => _selectedCourse = v),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'عنوان الاختبار'),
            ),
            const SizedBox(height: 14),
            const Text(
              'اتجاه محتوى الأسئلة',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'rtl', label: Text('عربي (RTL)')),
                ButtonSegment(value: 'ltr', label: Text('إنجليزي (LTR)')),
              ],
              selected: {_direction},
              onSelectionChanged: (s) => setState(() => _direction = s.first),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'ai',
                  label: Text('توليد تلقائي من Drive'),
                  icon: Icon(Icons.auto_awesome, size: 16),
                ),
                ButtonSegment(
                  value: 'manual',
                  label: Text('لصق يدوي'),
                  icon: Icon(Icons.edit_note, size: 16),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 16),
            if (_mode == 'ai') ...[
              OutlinedButton.icon(
                onPressed: _pickFiles,
                icon: const Icon(Icons.folder_open_outlined, size: 18),
                label: Text(_selectedFilesLabel(_selectedFiles.length)),
              ),
              if (_selectedFiles.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final f in _selectedFiles)
                      Chip(
                        label: Text(
                          f.name,
                          style: const TextStyle(fontSize: 11),
                        ),
                        onDeleted: () => setState(
                          () => _selectedFiles = _selectedFiles
                              .where((x) => x.id != f.id)
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ],
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _saving ? null : _generate,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('توليد الاختبار'),
              ),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _videoLinkController,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        labelText: 'لينك الفيديو/المرجع (اختياري)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _browseDriveForLink,
                    tooltip: 'تصفّح Drive',
                    icon: const Icon(Icons.folder_open_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'الصق هنا مصفوفة الأسئلة (JSON) اللي هبعتهالك',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _questionsController,
                maxLines: 14,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(
                  hintText: '[{"topic":"...","text":"...","options":["...","..."],"correct_index":0}, ...]',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ],
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _saving ? null : _submitManual,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('حفظ وإنشاء اللينك'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
