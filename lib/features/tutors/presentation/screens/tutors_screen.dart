import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/reauth.dart';
import '../../../../core/widgets/realtime_error_view.dart';
import '../../domain/entities/tutor_application.dart';
import '../providers/tutors_providers.dart';
import '../widgets/application_card.dart';
import '../widgets/tutor_list_tile.dart';

class TutorsScreen extends StatelessWidget {
  const TutorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('👨‍🏫 المدرسين'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'طلبات جديدة'),
              Tab(text: 'القائمة'),
              Tab(text: 'المواد المسجلة'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_ApplicationsTab(), _RosterTab(), _SubjectsTab()],
        ),
      ),
    );
  }
}

class _ApplicationsTab extends ConsumerWidget {
  const _ApplicationsTab();

  Future<void> _promote(
    BuildContext context,
    WidgetRef ref,
    TutorApplication app,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('قبول كمدرس؟'),
        content: Text(
          'هيتم إضافة "${app.name}" لقائمة المدرسين — غير نشط لحد ما يتحدد له كورس.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(tutorsRepositoryProvider).promoteApplication(app);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('✅ تم قبول ${app.name}')));
    }
  }

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    TutorApplication app,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رفض الطلب؟'),
        content: Text('هيتم رفض طلب "${app.name}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('رفض'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(tutorsRepositoryProvider).rejectApplication(app.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('🗑️ تم رفض ${app.name}')));
    }
  }

  Future<void> _promoteAll(
    BuildContext context,
    WidgetRef ref,
    List<TutorApplication> pending,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('قبول كل الطلبات؟'),
        content: Text(
          'هيتم إضافة ${pending.length} متقدم لقائمة المدرسين — غير نشطين لحد ما يتحدد لهم كورس.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('جارِ قبول الطلبات...')),
          ],
        ),
      ),
    );

    final repo = ref.read(tutorsRepositoryProvider);
    var success = 0;
    for (final app in pending) {
      try {
        await repo.promoteApplication(app);
        success++;
      } catch (_) {
        // Keep going so one bad row doesn't block the rest of the batch.
      }
    }

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ تم قبول $success من ${pending.length} متقدم'),
        ),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    TutorApplication app,
  ) async {
    final confirmed = await confirmWithPassword(
      context,
      title: 'حذف الطلب نهائيًا',
      message:
          'هيتم حذف طلب "${app.name}" نهائيًا ومش هترجع تاني. اكتب كلمة المرور للتأكيد.',
    );
    if (!confirmed) return;
    await ref.read(tutorsRepositoryProvider).deleteApplication(app.id);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('🗑️ تم حذف ${app.name} نهائيًا')));
    }
  }

  Future<void> _deleteAlreadyInRoster(
    BuildContext context,
    WidgetRef ref,
    List<TutorApplication> pending,
  ) async {
    final confirmed = await confirmWithPassword(
      context,
      title: 'حذف الطلبات المكررة',
      message: 'هيتم فحص كل طلب لسه في الانتظار، ولو صاحبه موجود بالفعل في قائمة المدرسين هيتحذف الطلب نهائيًا. اكتب كلمة المرور للتأكيد.',
    );
    if (!confirmed) return;
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('جارِ الفحص والحذف...')),
          ],
        ),
      ),
    );

    final repo = ref.read(tutorsRepositoryProvider);
    var deleted = 0;
    for (final app in pending) {
      try {
        if (await repo.tutorExistsFor(app)) {
          await repo.deleteApplication(app.id);
          deleted++;
        }
      } catch (_) {
        // Keep going so one bad row doesn't block the rest of the batch.
      }
    }

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🗑️ اتحذف $deleted طلب موجودين في القائمة بالفعل'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationsAsync = ref.watch(applicationsProvider);

    return applicationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => RealtimeErrorView(
        error: err,
        onRetry: () => ref.invalidate(applicationsProvider),
      ),
      data: (all) {
        final pending = all.where((a) => a.status == 'new').toList();
        if (pending.isEmpty) {
          return const Center(
            child: Text(
              'مفيش طلبات جديدة',
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${pending.length} طلب في الانتظار',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Wrap(
                    alignment: WrapAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () =>
                            _deleteAlreadyInRoster(context, ref, pending),
                        icon: const Icon(
                          Icons.playlist_remove,
                          size: 18,
                          color: AppColors.error,
                        ),
                        label: const Text(
                          'حذف الموجودين بالفعل',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _promoteAll(context, ref, pending),
                        icon: const Icon(Icons.done_all, size: 18),
                        label: const Text('قبول الكل'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: pending.length,
                itemBuilder: (context, i) {
                  final app = pending[i];
                  return ApplicationCard(
                    application: app,
                    onPromote: () => _promote(context, ref, app),
                    onReject: () => _reject(context, ref, app),
                    onDelete: () => _delete(context, ref, app),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RosterTab extends ConsumerStatefulWidget {
  const _RosterTab();

  @override
  ConsumerState<_RosterTab> createState() => _RosterTabState();
}

class _RosterTabState extends ConsumerState<_RosterTab> {
  final _searchController = TextEditingController();
  String _statusFilter = 'all';
  bool _featuredOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addTutor() async {
    final nameController = TextEditingController();
    final phonePrimaryController = TextEditingController();
    final phoneWhatsappController = TextEditingController();
    final emailController = TextEditingController();
    final notesController = TextEditingController();
    String? formError;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: const Text('إضافة مدرس'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'اسم المدرس'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phonePrimaryController,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneWhatsappController,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'رقم الواتساب',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(labelText: 'الإيميل'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات (اختياري)',
                    ),
                  ),
                  if (formError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      formError!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
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
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  setState(() => formError = 'لازم تكتب اسم المدرس');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    await ref
        .read(tutorsRepositoryProvider)
        .addTutor(
          name: nameController.text.trim(),
          phonePrimary: phonePrimaryController.text.trim().isEmpty
              ? null
              : phonePrimaryController.text.trim(),
          phoneWhatsapp: phoneWhatsappController.text.trim().isEmpty
              ? null
              : phoneWhatsappController.text.trim(),
          email: emailController.text.trim().isEmpty
              ? null
              : emailController.text.trim(),
          notes: notesController.text.trim().isEmpty
              ? null
              : notesController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final tutorsAsync = ref.watch(tutorsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'القائمة',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              TextButton.icon(
                onPressed: _addTutor,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة مدرس'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'ابحث بالاسم أو المادة...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'الكل',
                  selected: _statusFilter == 'all',
                  onTap: () => setState(() => _statusFilter = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'نشط',
                  selected: _statusFilter == 'active',
                  onTap: () => setState(() => _statusFilter = 'active'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'غير نشط',
                  selected: _statusFilter == 'inactive',
                  onTap: () => setState(() => _statusFilter = 'inactive'),
                ),
                const SizedBox(width: 14),
                Container(width: 1, height: 20, color: AppColors.border),
                const SizedBox(width: 10),
                _FilterChip(
                  label: '⭐ مميز',
                  selected: _featuredOnly,
                  onTap: () => setState(() => _featuredOnly = !_featuredOnly),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: tutorsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => RealtimeErrorView(
              error: err,
              onRetry: () => ref.invalidate(tutorsProvider),
            ),
            data: (all) {
              final query = _searchController.text.trim().toLowerCase();

              bool subjectMatches(Map<String, dynamic> s) =>
                  (s['ar'] as String? ?? '').toLowerCase().contains(query) ||
                  (s['en'] as String? ?? '').toLowerCase().contains(query);

              final filtered = all.where((t) {
                if (_statusFilter != 'all' && t.status != _statusFilter) {
                  return false;
                }
                if (_featuredOnly && !t.isFeatured) return false;
                if (query.isEmpty) return true;
                if (t.name.toLowerCase().contains(query)) return true;
                return t.subjects.any(subjectMatches);
              }).toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Text(
                    'مفيش نتائج',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final tutor = filtered[i];
                  final matched = query.isEmpty
                      ? const <Map<String, dynamic>>[]
                      : tutor.subjects.where(subjectMatches).toList();
                  return TutorListTile(
                    tutor: tutor,
                    matchedSubjects: matched,
                    onTap: () => context.push('/tutors/${tutor.id}'),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SubjectTutor {
  const _SubjectTutor(this.name, this.facultyLabel);
  final String name;
  final String facultyLabel;
}

class _SubjectEntry {
  _SubjectEntry(this.name, this.en);
  final String name;
  final String en;
  final List<_SubjectTutor> tutors = [];

  String get displayName => en.isEmpty ? name : '$name ($en)';
}

class _SubjectsTab extends ConsumerStatefulWidget {
  const _SubjectsTab();

  @override
  ConsumerState<_SubjectsTab> createState() => _SubjectsTabState();
}

class _SubjectsTabState extends ConsumerState<_SubjectsTab> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tutorsAsync = ref.watch(tutorsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'ابحث عن مادة...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: tutorsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => Center(child: Text('حصل خطأ: $err')),
            data: (tutors) {
              final bySubject = <String, _SubjectEntry>{};
              for (final tutor in tutors) {
                for (final s in tutor.subjects) {
                  final name = (s['ar'] as String? ?? '').trim();
                  if (name.isEmpty) continue;
                  final en = (s['en'] as String? ?? '').trim();
                  final entry = bySubject.putIfAbsent(
                    name,
                    () => _SubjectEntry(name, en),
                  );
                  entry.tutors.add(
                    _SubjectTutor(tutor.name, tutor.facultyLabel),
                  );
                }
              }
              final query = _searchController.text.trim().toLowerCase();
              final entries =
                  bySubject.values
                      .where(
                        (e) =>
                            query.isEmpty ||
                            e.name.toLowerCase().contains(query),
                      )
                      .toList()
                    ..sort((a, b) => a.name.compareTo(b.name));

              if (entries.isEmpty) {
                return const Center(
                  child: Text(
                    'مفيش مواد مسجلة لسه',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                itemCount: entries.length,
                itemBuilder: (context, i) {
                  final entry = entries[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ExpansionTile(
                      title: Text(
                        entry.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        '${entry.tutors.length} مدرس',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: entry.tutors.map((t) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.person_outline,
                                      size: 15,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            t.name,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            t.facultyLabel,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.accent.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: selected ? AppColors.accent : AppColors.textMuted,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      side: BorderSide(color: selected ? AppColors.accent : AppColors.border),
    );
  }
}
