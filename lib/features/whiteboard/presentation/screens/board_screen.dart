import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/wb_assignment.dart';
import '../../domain/entities/wb_question.dart';
import '../providers/whiteboard_providers.dart';
import '../widgets/whiteboard_background.dart';
import '../widgets/whiteboard_canvas.dart';
import '../widgets/whiteboard_controller.dart';
import '../widgets/whiteboard_toolbar.dart';

/// The public, unauthenticated page a student reaches via the shared
/// `/whiteboard/:id` link — same trust model as web/quiz.html: no login,
/// just a name (+ optional phone) typed in before a one-shot submission.
class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key, required this.assignmentId});

  final String assignmentId;

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  late Future<_BoardData?> _dataFuture;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _controller = WhiteboardController();
  bool _started = false;
  bool _submitting = false;
  bool _submitted = false;
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<_BoardData?> _load() async {
    final repo = ref.read(whiteboardRepositoryProvider);
    final assignment = await repo.fetchPublishedAssignment(widget.assignmentId);
    if (assignment == null) return null;
    final questions = await repo.fetchQuestions(assignment.questionIds);
    if (questions.isEmpty) return null;
    final question = questions.first;
    Uint8List? sourceBytes;
    if (question.sourcePath != null) {
      final url = repo.publicUrlFor(question.sourcePath!);
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) sourceBytes = res.bodyBytes;
    }
    return _BoardData(assignment, question, sourceBytes);
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      final data = await _dataFuture;
      if (data == null) return;
      await ref
          .read(whiteboardRepositoryProvider)
          .submitWork(
            assignmentId: data.assignment.id,
            questionId: data.question.id,
            studentName: _nameController.text.trim(),
            studentPhone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            strokes: _controller.strokes,
            durationMs: _startedAt == null
                ? null
                : DateTime.now().difference(_startedAt!).inMilliseconds,
          );
      if (mounted) setState(() => _submitted = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('حصل خطأ أثناء التسليم: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<_BoardData?>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data;
            if (data == null) {
              return const Center(
                child: Text(
                  'الواجب غير موجود أو غير متاح حاليًا',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              );
            }
            if (_submitted) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    '✅ تم تسليم الواجب بنجاح',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                ),
              );
            }
            if (!_started) {
              return _NameEntryForm(
                title: data.assignment.title,
                nameController: _nameController,
                phoneController: _phoneController,
                onStart: () {
                  if (_nameController.text.trim().isEmpty) return;
                  _startedAt = DateTime.now();
                  setState(() => _started = true);
                },
              );
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          data.question.prompt,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('تسليم'),
                      ),
                    ],
                  ),
                ),
                WhiteboardToolbar(controller: _controller),
                Expanded(
                  child: WhiteboardCanvas(
                    controller: _controller,
                    background: data.sourceBytes == null
                        ? null
                        : WhiteboardBackground(
                            bytes: data.sourceBytes!,
                            sourceType: data.question.sourceType ?? 'image',
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BoardData {
  _BoardData(this.assignment, this.question, this.sourceBytes);
  final WbAssignment assignment;
  final WbQuestion question;
  final Uint8List? sourceBytes;
}

class _NameEntryForm extends StatelessWidget {
  const _NameEntryForm({
    required this.title,
    required this.nameController,
    required this.phoneController,
    required this.onStart,
  });

  final String title;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'اسمك'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'رقم الواتساب (اختياري)',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onStart,
                child: const Text('ابدأ الحل'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
