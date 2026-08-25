import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/contact_links.dart';
import '../../domain/entities/tutor_application.dart';
import 'subject_chips.dart';

class ApplicationCard extends StatelessWidget {
  const ApplicationCard({
    super.key,
    required this.application,
    required this.onPromote,
    required this.onReject,
    required this.onDelete,
  });

  final TutorApplication application;
  final VoidCallback onPromote;
  final VoidCallback onReject;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    application.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              application.facultyLabel,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (application.phonePrimary != null)
                  _ContactAction(
                    icon: Icons.call_outlined,
                    label: application.phonePrimary!,
                    onTap: () => launchTel(application.phonePrimary!),
                  ),
                if (application.phoneWhatsapp != null)
                  _ContactAction(
                    icon: Icons.chat_bubble_outline,
                    label: 'واتساب',
                    onTap: () => launchWhatsapp(application.phoneWhatsapp!),
                  ),
                if (application.email != null && application.email!.isNotEmpty)
                  _ContactAction(
                    icon: Icons.mail_outline,
                    label: application.email!,
                    onTap: () => launchEmail(application.email!),
                  ),
              ],
            ),
            if (application.demoLink != null &&
                application.demoLink!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _ContactAction(
                icon: Icons.play_circle_outline,
                label: 'لينك الشرح التجريبي',
                onTap: () => launchWebLink(application.demoLink!),
              ),
            ],
            const SizedBox(height: 10),
            SubjectChips(subjects: application.subjects),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    child: const Text('رفض'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onPromote,
                    child: const Text('قبول كمدرس'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactAction extends StatelessWidget {
  const _ContactAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
