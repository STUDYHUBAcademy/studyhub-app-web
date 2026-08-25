import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/realtime_error_view.dart';
import '../../domain/entities/term.dart';
import '../../domain/entities/university.dart';
import '../providers/universities_providers.dart';

class UniversitiesTermsScreen extends StatelessWidget {
  const UniversitiesTermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الجامعات والفصول الدراسية'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'الجامعات'),
              Tab(text: 'الفصول الدراسية'),
            ],
          ),
        ),
        body: const TabBarView(children: [_UniversitiesTab(), _TermsTab()]),
      ),
    );
  }
}

class _UniversitiesTab extends ConsumerWidget {
  const _UniversitiesTab();

  Future<void> _addOrEdit(
    BuildContext context,
    WidgetRef ref, {
    University? existing,
  }) async {
    final controller = TextEditingController(text: existing?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'إضافة جامعة' : 'تعديل الجامعة'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'اسم الجامعة'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final repo = ref.read(universitiesRepositoryProvider);
    if (existing == null) {
      await repo.addUniversity(name);
    } else {
      await repo.renameUniversity(existing.id, name);
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    University u,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الجامعة؟'),
        content: Text('هيتم حذف "${u.name}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(universitiesRepositoryProvider).deleteUniversity(u.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final universitiesAsync = ref.watch(universitiesProvider);
    return Scaffold(
      body: universitiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => RealtimeErrorView(
          error: err,
          onRetry: () => ref.invalidate(universitiesProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text(
                'مفيش جامعات مضافة',
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final u = list[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(u.name),
                  onTap: () => _addOrEdit(context, ref, existing: u),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () => _delete(context, ref, u),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEdit(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}

const _termStatusLabels = {
  'upcoming': 'قادم',
  'active': 'نشط',
  'closed': 'منتهي',
};

class _TermsTab extends ConsumerWidget {
  const _TermsTab();

  Future<void> _addOrEdit(
    BuildContext context,
    WidgetRef ref, {
    Term? existing,
  }) async {
    String semester = existing?.semester ?? 'first';
    final startYear =
        existing?.academicYear?.split('/').firstOrNull ??
        DateTime.now().year.toString();
    final yearController = TextEditingController(text: startYear);
    DateTime? start = existing?.startDate;
    DateTime? end = existing?.endDate;
    String status = existing?.status ?? 'upcoming';

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: Text(
            existing == null ? 'إضافة فصل دراسي' : 'تعديل الفصل الدراسي',
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: semester,
                    decoration: const InputDecoration(
                      labelText: 'الفصل الدراسي',
                    ),
                    items: semesterLabels.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => semester = v ?? 'first'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: yearController,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: 'العام الدراسي (سنة البداية)',
                      helperText:
                          'هيتسجل كـ ${yearController.text}/${(int.tryParse(yearController.text) ?? DateTime.now().year) + 1}',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: start ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) setState(() => start = picked);
                          },
                          child: Text(
                            start == null
                                ? 'تاريخ البداية'
                                : '${start!.year}-${start!.month}-${start!.day}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: end ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) setState(() => end = picked);
                          },
                          child: Text(
                            end == null
                                ? 'تاريخ النهاية'
                                : '${end!.year}-${end!.month}-${end!.day}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: _termStatusLabels.entries.map((e) {
                      return ChoiceChip(
                        label: Text(e.value),
                        selected: status == e.key,
                        onSelected: (_) => setState(() => status = e.key),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
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
      ),
    );

    if (saved != true) return;
    final startYearNum = int.tryParse(yearController.text.trim());
    if (startYearNum == null) return;
    final academicYear = '$startYearNum/${startYearNum + 1}';

    final repo = ref.read(universitiesRepositoryProvider);
    if (existing == null) {
      await repo.addTerm(
        semester: semester,
        academicYear: academicYear,
        startDate: start,
        endDate: end,
        status: status,
      );
    } else {
      await repo.updateTerm(
        existing.id,
        semester: semester,
        academicYear: academicYear,
        startDate: start,
        endDate: end,
        status: status,
      );
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Term t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الفصل الدراسي؟'),
        content: Text(
          'هيتم حذف "${t.name}" وكل الكورسات المرتبطة بيه في الفصل ده.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(universitiesRepositoryProvider).deleteTerm(t.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termsAsync = ref.watch(termsProvider);
    return Scaffold(
      body: termsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => RealtimeErrorView(
          error: err,
          onRetry: () => ref.invalidate(termsProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text(
                'مفيش فصول دراسية مضافة',
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final t = list[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(t.name),
                  subtitle: Text(
                    _termStatusLabels[t.status] ?? t.status,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  onTap: () => _addOrEdit(context, ref, existing: t),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () => _delete(context, ref, t),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEdit(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}
