import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/app_settings_providers.dart';
import '../widgets/backup_card.dart';

Future<void> _editTabbyTamaraFee(
  BuildContext context,
  WidgetRef ref,
  double current,
) async {
  final controller = TextEditingController(
    text: current.truncateToDouble() == current
        ? current.toStringAsFixed(0)
        : current.toString(),
  );
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('نسبة رسوم تابي/تمارا الافتراضية'),
      content: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'النسبة %'),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
  if (saved != true) return;
  final pct = double.tryParse(controller.text.trim());
  if (pct == null) return;
  await ref.read(appSettingsRepositoryProvider).updateTabbyTamaraFeePct(pct);
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final tabbyTamaraFeePct =
        ref.watch(appSettingsProvider).valueOrNull?.tabbyTamaraFeePct ?? 8;

    return Scaffold(
      appBar: AppBar(title: const Text('⚙️ الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.person_rounded,
                color: AppColors.accent,
              ),
              title: Text(user?.email ?? ''),
              subtitle: const Text('مالك الأكاديمية'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.school_outlined,
                color: AppColors.accent,
              ),
              title: const Text('الجامعات والفصول الدراسية'),
              trailing: const Icon(
                Icons.chevron_left_rounded,
                color: AppColors.textMuted,
              ),
              onTap: () => context.push('/universities'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.percent_rounded,
                color: AppColors.accent,
              ),
              title: const Text('نسبة رسوم تابي/تمارا الافتراضية'),
              subtitle: Text('${tabbyTamaraFeePct.toStringAsFixed(0)}%'),
              trailing: const Icon(Icons.edit_outlined, size: 20),
              onTap: () => _editTabbyTamaraFee(context, ref, tabbyTamaraFeePct),
            ),
          ),
          const SizedBox(height: 8),
          const BackupCard(),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.error),
              title: const Text('تسجيل الخروج'),
              onTap: () => ref.read(authRepositoryProvider).signOut(),
            ),
          ),
        ],
      ),
    );
  }
}
