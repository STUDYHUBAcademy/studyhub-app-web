import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';

class MoreMenuItem {
  const MoreMenuItem({
    required this.title,
    required this.icon,
    required this.route,
  });

  final String title;
  final IconData icon;
  final String route;
}

const _moreItems = [
  MoreMenuItem(
    title: '💰 المالية',
    icon: Icons.payments_rounded,
    route: '/finance',
  ),
  MoreMenuItem(
    title: '👨‍🎓 الطلاب',
    icon: Icons.school_rounded,
    route: '/students',
  ),
  MoreMenuItem(
    title: '📣 المسوقين',
    icon: Icons.campaign_rounded,
    route: '/marketers',
  ),
  MoreMenuItem(
    title: '📝 الاختبارات',
    icon: Icons.quiz_rounded,
    route: '/quizzes',
  ),
  MoreMenuItem(title: '💬 الشات', icon: Icons.forum_rounded, route: '/chat'),
  MoreMenuItem(
    title: '✅ المهام والملاحظات',
    icon: Icons.checklist_rounded,
    route: '/tasks',
  ),
  MoreMenuItem(
    title: '⚙️ الإعدادات',
    icon: Icons.settings_rounded,
    route: '/settings',
  ),
];

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('☰ المزيد')),
      body: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: _moreItems.length,
        separatorBuilder: (context, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = _moreItems[index];
          return Card(
            child: ListTile(
              leading: Icon(item.icon, color: AppColors.accent),
              title: Text(item.title),
              trailing: const Icon(
                Icons.chevron_left_rounded,
                color: AppColors.textMuted,
              ),
              onTap: () => context.push(item.route),
            ),
          );
        },
      ),
    );
  }
}
