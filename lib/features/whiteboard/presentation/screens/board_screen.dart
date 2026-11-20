import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/live_check_result.dart';
import '../../domain/entities/stroke_line.dart';
import '../../domain/entities/wb_assignment.dart';
import '../../domain/entities/wb_question.dart';
import '../providers/whiteboard_providers.dart';
import '../widgets/whiteboard_background.dart';
import '../widgets/whiteboard_canvas.dart';
import '../widgets/whiteboard_controller.dart';
import '../widgets/whiteboard_rasterizer.dart';
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

  // Live AI checking — off by default, toggled by the student once they
  // start writing; see rasterizeForLiveCheck for the line-numbering trick.
  bool _liveCheckOn = false;
  Timer? _debounce;
  bool _checking = false;
  bool _pendingRecheck = false;
  int _lastSeenStrokeCount = 0;
  List<StrokeLine> _lastLines = [];
  Map<String, Color> _strokeColors = {};
  Map<int, LiveCheckFlag> _flagsByLine = {};
  String? _liveMessage;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
    _controller.addListener(_onBoardChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onBoardChanged);
    _debounce?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onBoardChanged() {
    if (!_liveCheckOn) return;
    if (_controller.strokes.length == _lastSeenStrokeCount) return;
    _lastSeenStrokeCount = _controller.strokes.length;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1200), _runLiveCheck);
  }

  void _setLiveCheckOn(bool on) {
    setState(() {
      _liveCheckOn = on;
      if (!on) {
        _debounce?.cancel();
        _strokeColors = {};
        _flagsByLine = {};
        _liveMessage = null;
      }
    });
  }

  Future<void> _runLiveCheck() async {
    if (_checking) {
      _pendingRecheck = true;
      return;
    }
    if (_controller.strokes.isEmpty) return;
    final data = await _dataFuture;
    if (data == null) return;
    _checking = true;
    try {
      final snapshot = await rasterizeForLiveCheck(
        strokes: List.of(_controller.strokes),
        backgroundBytes: data.sourceBytes,
        backgroundSourceType: data.question.sourceType,
      );
      final result = await ref
          .read(whiteboardRepositoryProvider)
          .liveCheck(questionId: data.question.id, imageBytes: snapshot.png);
      if (!mounted) return;
      _applyLiveCheckResult(snapshot.lines, result);
    } catch (_) {
      // Silent — a failed live check just means no feedback this round;
      // the next debounce cycle (or stroke) tries again.
    } finally {
      _checking = false;
      if (_pendingRecheck) {
        _pendingRecheck = false;
        unawaited(_runLiveCheck());
      }
    }
  }

  void _applyLiveCheckResult(List<StrokeLine> lines, LiveCheckResult result) {
    final colors = <String, Color>{};
    final flagsByLine = <int, LiveCheckFlag>{};
    for (final flag in result.flags) {
      final line = lines.where((l) => l.index == flag.line).firstOrNull;
      if (line == null) continue;
      flagsByLine[flag.line] = flag;
      final color = flag.severity == 'critical'
          ? const Color(0xFFC21F3A)
          : const Color(0xFFB36A00);
      for (final s in line.strokes) {
        colors[s.id] = color;
      }
    }
    if (!mounted) return;
    setState(() {
      _strokeColors = colors;
      _flagsByLine = flagsByLine;
      _lastLines = lines;
      _liveMessage = result.message;
    });
  }

  void _showFlagNote(LiveCheckFlag flag) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(flag.severity == 'critical' ? '⚠️ ملاحظة مهمة' : 'ملاحظة'),
        content: Text(flag.note),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('تمام'),
          ),
        ],
      ),
    );
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
                      IconButton(
                        tooltip: _liveCheckOn
                            ? 'إيقاف التصحيح الفوري'
                            : 'تشغيل التصحيح الفوري بالذكاء الاصطناعي',
                        onPressed: () => _setLiveCheckOn(!_liveCheckOn),
                        icon: Icon(
                          Icons.bolt,
                          color: _liveCheckOn
                              ? AppColors.accent
                              : AppColors.textMuted,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: _liveCheckOn
                              ? AppColors.accentSoft
                              : null,
                        ),
                      ),
                      const SizedBox(width: 4),
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
                if (_liveCheckOn && _liveMessage != null)
                  Container(
                    width: double.infinity,
                    color: AppColors.accentSoft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Text(
                      _liveMessage!,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                WhiteboardToolbar(controller: _controller),
                Expanded(
                  child: WhiteboardCanvas(
                    controller: _controller,
                    strokeColorOverrides: _strokeColors,
                    background: data.sourceBytes == null
                        ? null
                        : WhiteboardBackground(
                            bytes: data.sourceBytes!,
                            sourceType: data.question.sourceType ?? 'image',
                          ),
                    overlayChildren: [
                      for (final entry in _flagsByLine.entries)
                        if (_lastLines
                                .where((l) => l.index == entry.key)
                                .firstOrNull
                            case final line?)
                          Positioned(
                            left: line.bounds.right + 6,
                            top: line.bounds.top - 4,
                            child: _FlagMarker(
                              flag: entry.value,
                              onTap: () => _showFlagNote(entry.value),
                            ),
                          ),
                    ],
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

/// The small tappable "!" badge next to a line the live checker flagged —
/// tapping shows the note; red for a critical mistake, orange for minor.
class _FlagMarker extends StatelessWidget {
  const _FlagMarker({required this.flag, required this.onTap});

  final LiveCheckFlag flag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = flag.severity == 'critical'
        ? const Color(0xFFC21F3A)
        : const Color(0xFFB36A00);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
        alignment: Alignment.center,
        child: const Text(
          '!',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
