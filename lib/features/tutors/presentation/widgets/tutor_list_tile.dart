import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/tutor.dart';

class _StatusStyle {
  const _StatusStyle(this.label, this.color);
  final String label;
  final Color color;
}

const _statusStyles = {
  'active': _StatusStyle('نشط', AppColors.success),
  'inactive': _StatusStyle('غير نشط', AppColors.textMuted),
};

class TutorListTile extends StatelessWidget {
  const TutorListTile({
    super.key,
    required this.tutor,
    required this.onTap,
    this.matchedSubjects = const [],
  });

  final Tutor tutor;
  final VoidCallback onTap;

  /// Subjects (ar/en pairs) that matched the active search query, shown
  /// under the tutor's name so it's obvious *why* they matched.
  final List<Map<String, dynamic>> matchedSubjects;

  @override
  Widget build(BuildContext context) {
    final style = _statusStyles[tutor.status] ?? _statusStyles['inactive']!;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.surfaceVariant,
          child: Text(
            tutor.name.isNotEmpty ? tutor.name[0] : '؟',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        title: Row(
          children: [
            if (tutor.isFeatured)
              const Padding(
                padding: EdgeInsetsDirectional.only(end: 4),
                child: Text('⭐', style: TextStyle(fontSize: 13)),
              ),
            Flexible(
              child: Text(
                tutor.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tutor.facultyLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            if (matchedSubjects.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  matchedSubjects
                      .map((s) => '${s['ar']} (${s['en']})')
                      .join(' • '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        isThreeLine: matchedSubjects.isNotEmpty,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: style.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            style.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: style.color,
            ),
          ),
        ),
      ),
    );
  }
}
