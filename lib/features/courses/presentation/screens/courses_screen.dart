import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/realtime_error_view.dart';
import '../../../tutors/domain/entities/tutor.dart';
import '../../../tutors/presentation/providers/tutors_providers.dart';
import '../../../universities/domain/entities/term.dart';
import '../../../universities/domain/entities/university.dart';
import '../../../universities/presentation/providers/universities_providers.dart';
import '../../domain/entities/course.dart';
import '../course_status.dart';
import '../providers/courses_providers.dart';

class CoursesScreen extends ConsumerStatefulWidget {
  const CoursesScreen({super.key});

  @override
  ConsumerState<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends ConsumerState<CoursesScreen> {
  String _statusFilter = 'all';
  String? _universityFilter;
  String? _tutorFilter;
  final _subjectController = TextEditingController();

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _createCourse(BuildContext context, WidgetRef ref) async {
    final subjectController = TextEditingController();
    final demoLinkController = TextEditingController();
    final universities = await ref.read(universitiesProvider.future);
    final terms = await ref.read(termsProvider.future);
    if (!context.mounted) return;

    University? selectedUniversity;
    final newUniversityController = TextEditingController();
    bool addingNewUniversity = false;

    Term? selectedTerm;
    bool addingNewTerm = false;
    String newTermSemester = 'first';
    final newTermYearController = TextEditingController(
      text: DateTime.now().year.toString(),
    );

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: const Text('إضافة كورس'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: subjectController,
                    decoration: const InputDecoration(labelText: 'اسم المادة'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 14),
                  if (!addingNewUniversity) ...[
                    DropdownButtonFormField<University?>(
                      initialValue: selectedUniversity,
                      decoration: const InputDecoration(labelText: 'الجامعة'),
                      items: [
                        ...universities.map(
                          (u) =>
                              DropdownMenuItem(value: u, child: Text(u.name)),
                        ),
                        const DropdownMenuItem(
                          value: null,
                          child: Text(
                            '+ جامعة جديدة',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null && selectedUniversity == null) {
                          setState(() => addingNewUniversity = true);
                        } else {
                          setState(() => selectedUniversity = v);
                        }
                      },
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newUniversityController,
                            decoration: const InputDecoration(
                              labelText: 'اسم الجامعة الجديدة',
                            ),
                            autofocus: true,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              setState(() => addingNewUniversity = false),
                        ),
                      ],
                    ),
                  const SizedBox(height: 14),
                  if (!addingNewTerm) ...[
                    DropdownButtonFormField<Term?>(
                      initialValue: selectedTerm,
                      decoration: const InputDecoration(
                        labelText: 'الفصل الدراسي',
                      ),
                      items: [
                        ...terms.map(
                          (t) =>
                              DropdownMenuItem(value: t, child: Text(t.name)),
                        ),
                        const DropdownMenuItem(
                          value: null,
                          child: Text(
                            '+ فصل دراسي جديد',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null && selectedTerm == null) {
                          setState(() => addingNewTerm = true);
                        } else {
                          setState(() => selectedTerm = v);
                        }
                      },
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: newTermSemester,
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
                            onChanged: (v) =>
                                setState(() => newTermSemester = v ?? 'first'),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              setState(() => addingNewTerm = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: newTermYearController,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: 'العام الدراسي (سنة البداية)',
                        helperText:
                            'هيتسجل كـ ${newTermYearController.text}/${(int.tryParse(newTermYearController.text) ?? DateTime.now().year) + 1}',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: demoLinkController,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'لينك الديمو (اختياري)',
                    ),
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
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );

    if (created != true || subjectController.text.trim().isEmpty) return;

    String? universityId = selectedUniversity?.id;
    if (addingNewUniversity && newUniversityController.text.trim().isNotEmpty) {
      final newUniversity = await ref
          .read(universitiesRepositoryProvider)
          .addUniversity(newUniversityController.text.trim());
      universityId = newUniversity.id;
    }

    String? termId = selectedTerm?.id;
    if (addingNewTerm) {
      final startYear = int.tryParse(newTermYearController.text.trim());
      if (startYear != null) {
        final newTerm = await ref
            .read(universitiesRepositoryProvider)
            .addTerm(
              semester: newTermSemester,
              academicYear: '$startYear/${startYear + 1}',
              status: 'active',
            );
        termId = newTerm.id;
      }
    }

    final course = await ref
        .read(coursesRepositoryProvider)
        .addCourse(
          subjectName: subjectController.text.trim(),
          universityId: universityId,
          firstTermId: termId,
          demoLink: demoLinkController.text.trim().isEmpty
              ? null
              : demoLinkController.text.trim(),
        );
    if (context.mounted) context.push('/courses/${course.id}');
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(coursesProvider);
    final universities = ref.watch(universitiesProvider).valueOrNull ?? [];
    final universityNames = {for (final u in universities) u.id: u.name};
    final tutors = ref.watch(tutorsProvider).valueOrNull ?? [];
    final tutorNames = {for (final t in tutors) t.id: t.name};

    return Scaffold(
      appBar: AppBar(title: const Text('📚 الكورسات')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: TextField(
              controller: _subjectController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'ابحث بالمادة...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              children: [
                Expanded(
                  child: Autocomplete<University>(
                    displayStringForOption: (u) => u.name,
                    initialValue: TextEditingValue(
                      text:
                          universities
                              .where((u) => u.id == _universityFilter)
                              .firstOrNull
                              ?.name ??
                          '',
                    ),
                    optionsBuilder: (value) {
                      if (value.text.isEmpty) return universities;
                      final q = value.text.toLowerCase();
                      return universities.where(
                        (u) => u.name.toLowerCase().contains(q),
                      );
                    },
                    onSelected: (u) => setState(() => _universityFilter = u.id),
                    fieldViewBuilder:
                        (context, controller, focusNode, onSubmit) => TextField(
                          controller: controller,
                          focusNode: focusNode,
                          onChanged: (v) {
                            if (v.isEmpty && _universityFilter != null) {
                              setState(() => _universityFilter = null);
                            }
                          },
                          decoration: const InputDecoration(
                            labelText: 'الجامعة (بحث)',
                            isDense: true,
                          ),
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Autocomplete<Tutor>(
                    displayStringForOption: (t) => t.name,
                    initialValue: TextEditingValue(
                      text:
                          tutors
                              .where((t) => t.id == _tutorFilter)
                              .firstOrNull
                              ?.name ??
                          '',
                    ),
                    optionsBuilder: (value) {
                      if (value.text.isEmpty) return tutors;
                      final q = value.text.toLowerCase();
                      return tutors.where(
                        (t) => t.name.toLowerCase().contains(q),
                      );
                    },
                    onSelected: (t) => setState(() => _tutorFilter = t.id),
                    fieldViewBuilder:
                        (context, controller, focusNode, onSubmit) => TextField(
                          controller: controller,
                          focusNode: focusNode,
                          onChanged: (v) {
                            if (v.isEmpty && _tutorFilter != null) {
                              setState(() => _tutorFilter = null);
                            }
                          },
                          decoration: const InputDecoration(
                            labelText: 'المدرس (بحث)',
                            isDense: true,
                          ),
                        ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _StatusChip(
                    label: 'الكل',
                    selected: _statusFilter == 'all',
                    onTap: () => setState(() => _statusFilter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  for (final entry in courseStatusLabels.entries) ...[
                    _StatusChip(
                      label: entry.value,
                      selected: _statusFilter == entry.key,
                      onTap: () => setState(() => _statusFilter = entry.key),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: coursesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => RealtimeErrorView(
                error: err,
                onRetry: () => ref.invalidate(coursesProvider),
              ),
              data: (courses) {
                final subjectQuery = _subjectController.text
                    .trim()
                    .toLowerCase();
                final filtered = courses.where((c) {
                  if (_statusFilter != 'all' && c.status != _statusFilter) {
                    return false;
                  }
                  if (_universityFilter != null &&
                      c.universityId != _universityFilter) {
                    return false;
                  }
                  if (_tutorFilter != null && c.tutorId != _tutorFilter) {
                    return false;
                  }
                  if (subjectQuery.isNotEmpty &&
                      !c.subjectName.toLowerCase().contains(subjectQuery)) {
                    return false;
                  }
                  return true;
                }).toList();
                bool missingDemo(Course c) =>
                    c.status == 'planning' &&
                    (c.demoLink == null || c.demoLink!.isEmpty);
                filtered.sort((a, b) {
                  final aMissing = missingDemo(a);
                  final bMissing = missingDemo(b);
                  if (aMissing == bMissing) return 0;
                  return aMissing ? -1 : 1;
                });
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'مفيش كورسات',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final course = filtered[i];
                    return _CourseTile(
                      course: course,
                      universityName: universityNames[course.universityId],
                      tutorName: tutorNames[course.tutorId],
                      onTap: () => context.push('/courses/${course.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createCourse(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
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

class _CourseTile extends StatelessWidget {
  const _CourseTile({
    required this.course,
    required this.universityName,
    required this.tutorName,
    required this.onTap,
  });

  final Course course;
  final String? universityName;
  final String? tutorName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = courseStatusColors[course.status] ?? AppColors.textMuted;
    final subtitleParts = [?universityName, ?tutorName];
    final missingDemo =
        course.status == 'planning' &&
        (course.demoLink == null || course.demoLink!.isEmpty);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        title: Text(
          course.subjectName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitleParts.isEmpty
                  ? 'بدون جامعة أو مدرس بعد'
                  : subtitleParts.join(' • '),
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            if (missingDemo)
              const Text(
                '🎬 منتظر إضافة تجريبي',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.info,
                ),
              ),
            Text(
              '📖 ${explanationStatusLabels[course.explanationStatus] ?? course.explanationStatus}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color:
                    explanationStatusColors[course.explanationStatus] ??
                    AppColors.textMuted,
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            courseStatusLabels[course.status] ?? course.status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
