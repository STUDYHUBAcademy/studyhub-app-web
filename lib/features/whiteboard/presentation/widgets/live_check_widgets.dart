import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The ⚡ icon button that turns live AI checking on/off — shared between
/// the assignment board and the free-study canvas.
class LiveCheckToggleButton extends StatelessWidget {
  const LiveCheckToggleButton({
    super.key,
    required this.enabled,
    required this.onToggle,
  });

  final bool enabled;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: enabled
          ? 'إيقاف التصحيح الفوري'
          : 'تشغيل التصحيح الفوري بالذكاء الاصطناعي',
      onPressed: () => onToggle(!enabled),
      icon: Icon(
        Icons.bolt,
        color: enabled ? AppColors.accent : AppColors.textMuted,
      ),
      style: IconButton.styleFrom(
        backgroundColor: enabled ? AppColors.accentSoft : null,
      ),
    );
  }
}

/// The thin banner showing the live checker's latest short message.
class LiveCheckMessageBanner extends StatelessWidget {
  const LiveCheckMessageBanner({super.key, required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: AppColors.accentSoft,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Text(message!, style: const TextStyle(fontSize: 12.5)),
    );
  }
}
