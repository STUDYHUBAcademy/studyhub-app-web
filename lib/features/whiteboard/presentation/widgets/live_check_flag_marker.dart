import 'package:flutter/material.dart';

import '../../domain/entities/live_check_result.dart';
import 'live_check_controller.dart';

/// The small tappable "!" badge next to a line the live checker flagged —
/// tapping shows the note; red for a critical mistake, orange for minor.
class LiveCheckFlagMarker extends StatelessWidget {
  const LiveCheckFlagMarker({super.key, required this.flag, required this.onTap});

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

void showLiveCheckFlagNote(BuildContext context, LiveCheckFlag flag) {
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

/// Positions a [LiveCheckFlagMarker] for each currently-flagged line, in the
/// same logical page coordinates the canvas's strokes use — meant to be
/// spread into [WhiteboardCanvas.overlayChildren].
List<Widget> buildLiveCheckMarkers(
  BuildContext context,
  LiveCheckController liveCheck,
) {
  return [
    for (final entry in liveCheck.flagsByLine.entries)
      if (liveCheck.lines.where((l) => l.index == entry.key).firstOrNull
          case final line?)
        Positioned(
          left: line.bounds.right + 6,
          top: line.bounds.top - 4,
          child: LiveCheckFlagMarker(
            flag: entry.value,
            onTap: () => showLiveCheckFlagNote(context, entry.value),
          ),
        ),
  ];
}
