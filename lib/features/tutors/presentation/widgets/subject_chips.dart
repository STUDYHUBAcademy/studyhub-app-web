import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class SubjectChips extends StatelessWidget {
  const SubjectChips({super.key, required this.subjects});

  final List<Map<String, dynamic>> subjects;

  @override
  Widget build(BuildContext context) {
    if (subjects.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: subjects.map((s) {
        final ar = s['ar'] as String? ?? '';
        final en = s['en'] as String? ?? '';
        final label = en.isEmpty ? ar : '$ar ($en)';
        return Chip(
          label: Text(label, style: const TextStyle(fontSize: 12)),
          backgroundColor: AppColors.surfaceVariant,
          side: BorderSide.none,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(),
    );
  }
}
