import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/contact_links.dart';
import '../../../courses/domain/entities/course.dart';
import '../../../courses/presentation/providers/courses_providers.dart';
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
  Course? _selectedCourse;
  String _direction = 'rtl';
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

  Future<void> _submit() async {
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
            TextField(
              controller: _videoLinkController,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'لينك الفيديو/المرجع (اختياري)',
              ),
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
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('حفظ وإنشاء اللينك'),
            ),
          ],
        ),
      ),
    );
  }
}
