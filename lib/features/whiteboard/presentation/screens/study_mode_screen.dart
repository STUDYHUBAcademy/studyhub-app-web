import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/live_check_result.dart';
import '../../domain/entities/stroke.dart';
import '../../domain/entities/stroke_line.dart';
import '../../domain/entities/study_course_option.dart';
import '../providers/whiteboard_providers.dart';
import '../widgets/live_check_controller.dart';
import '../widgets/live_check_flag_marker.dart';
import '../widgets/live_check_widgets.dart';
import '../widgets/whiteboard_background.dart';
import '../widgets/whiteboard_canvas.dart';
import '../widgets/whiteboard_controller.dart';
import '../widgets/whiteboard_rasterizer.dart';
import '../widgets/whiteboard_toolbar.dart';

/// The public, unauthenticated free-study canvas (`/study`) — unlike
/// `/whiteboard/:id`, there's no assignment or teacher-authored question:
/// the student picks one of the academy's own courses, writes or uploads
/// whatever problem they're practicing, and the AI checks it live using
/// that course's cached Drive-material digest (`course_knowledge`) for
/// grounding instead of a specific rubric.
class StudyModeScreen extends ConsumerStatefulWidget {
  const StudyModeScreen({super.key});

  @override
  ConsumerState<StudyModeScreen> createState() => _StudyModeScreenState();
}

class _StudyModeScreenState extends ConsumerState<StudyModeScreen> {
  StudyCourseOption? _course;
  late Future<List<StudyCourseOption>> _coursesFuture;
  final _controller = WhiteboardController();
  late final LiveCheckController _liveCheck;
  Uint8List? _backgroundBytes;
  String _backgroundType = 'image';

  @override
  void initState() {
    super.initState();
    _coursesFuture = ref.read(whiteboardRepositoryProvider).fetchActiveCourses();
    _liveCheck = LiveCheckController(check: _performLiveCheck)
      ..setEnabled(true);
    _controller.addListener(_onBoardChanged);
    // Full-State rebuild (not a narrowly-scoped AnimatedBuilder) — the
    // toggle button lives in the AppBar, so anything scoped to just the
    // body would freeze the button's `enabled` prop at its first value and
    // never update it again, making every tap re-apply that stale value.
    _liveCheck.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.removeListener(_onBoardChanged);
    _liveCheck.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onBoardChanged() => _liveCheck.onStrokesChanged(_controller.strokes);

  Future<(List<StrokeLine>, LiveCheckResult)> _performLiveCheck(
    List<Stroke> strokes,
  ) async {
    final course = _course;
    if (course == null) throw Exception('no course selected');
    final snapshot = await rasterizeForLiveCheck(
      strokes: strokes,
      backgroundBytes: _backgroundBytes,
      backgroundSourceType: _backgroundType,
    );
    final result = await ref
        .read(whiteboardRepositoryProvider)
        .liveCheck(courseId: course.id, imageBytes: snapshot.png);
    return (snapshot.lines, result);
  }

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    final file = files.firstOrNull;
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final isPdf = file.extension?.toLowerCase() == 'pdf';
    setState(() {
      _backgroundBytes = bytes;
      _backgroundType = isPdf ? 'pdf' : 'image';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_course == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('المذاكرة الحرة بالذكاء الاصطناعي')),
        body: FutureBuilder<List<StudyCourseOption>>(
          future: _coursesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final courses = snapshot.data ?? [];
            if (courses.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'لسه مفيش مواد متاحة للمذاكرة',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'اختار المادة اللي هتذاكرها — هيساعد الذكاء الاصطناعي يصحح لك أدق',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                for (final c in courses)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(c.subjectName),
                      trailing: const Icon(Icons.chevron_left_rounded),
                      onTap: () => setState(() => _course = c),
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_course!.subjectName),
        actions: [
          LiveCheckToggleButton(
            enabled: _liveCheck.enabled,
            onToggle: _liveCheck.setEnabled,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: 'ارفع صورة أو PDF للمسألة',
            onPressed: _pickFile,
          ),
        ],
      ),
      body: Column(
        children: [
          WhiteboardToolbar(controller: _controller),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: WhiteboardCanvas(
                    controller: _controller,
                    strokeColorOverrides: _liveCheck.strokeColors,
                    background: _backgroundBytes == null
                        ? null
                        : WhiteboardBackground(
                            bytes: _backgroundBytes!,
                            sourceType: _backgroundType,
                          ),
                    overlayChildren: buildLiveCheckMarkers(context, _liveCheck),
                  ),
                ),
                // Floats over the canvas rather than sitting in the Column
                // above it — a sibling banner that appears/disappears would
                // resize the canvas's own viewport each time, which shifts
                // what's visible and makes just-written strokes look like
                // they vanished (they're only scrolled out of the smaller
                // view, never actually deleted).
                if (_liveCheck.enabled)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LiveCheckMessageBanner(
                      message: _liveCheck.displayMessage,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
