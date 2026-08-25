import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/acquisition_source.dart';
import '../../../../core/utils/contact_links.dart';
import '../../../../core/utils/reauth.dart';
import '../../../../core/widgets/phone_number_field.dart';
import '../../../../core/widgets/realtime_error_view.dart';
import '../../../students/domain/entities/student.dart';
import '../../../students/presentation/providers/students_providers.dart';
import '../../../students/presentation/widgets/student_source_fields.dart';
import '../../../tutors/domain/entities/tutor.dart';
import '../../../tutors/presentation/providers/tutors_providers.dart';
import '../../../universities/domain/entities/term.dart';
import '../../../universities/presentation/providers/universities_providers.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/course_demo.dart';
import '../../domain/entities/course_term.dart';
import '../../domain/entities/enrollment.dart';
import '../../domain/entities/enrollment_payment.dart';
import '../../domain/entities/tutor_payment.dart';
import '../course_status.dart';
import '../providers/courses_providers.dart';
import 'drive_folder_picker_screen.dart';

class CourseDetailScreen extends ConsumerWidget {
  const CourseDetailScreen({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(coursesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الكورس')),
      body: coursesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => RealtimeErrorView(
          error: err,
          onRetry: () => ref.invalidate(coursesProvider),
        ),
        data: (all) {
          final course = all.where((c) => c.id == courseId).firstOrNull;
          if (course == null) {
            return const Center(
              child: Text(
                'الكورس غير موجود',
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }
          return _CourseDetailBody(course: course);
        },
      ),
    );
  }
}

const _demoTelegramChannel = 'https://t.me/+_FTM7hBP961mNWM8';

class _CourseDetailBody extends ConsumerWidget {
  const _CourseDetailBody({required this.course});

  final Course course;

  Future<void> _editMaterialsLink(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: course.materialsLink ?? '');
    final link = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('لينك مواد الكورس'),
        content: TextField(
          controller: controller,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: 'لينك Google Drive'),
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
    if (link == null) return;
    await ref
        .read(coursesRepositoryProvider)
        .updateCourseMaterialsLink(course.id, link.isEmpty ? null : link);
  }

  Future<void> _editDemoLink(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: course.demoLink ?? '');
    final link = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('لينك الديمو'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'لينك الفيديو من تيليجرام',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => launchWebLink(_demoTelegramChannel),
              icon: const Icon(Icons.send_outlined, size: 18),
              label: const Text('افتح قناة الديمو على تيليجرام'),
            ),
          ],
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
    if (link == null) return;
    await ref
        .read(coursesRepositoryProvider)
        .updateCourseDemoLink(course.id, link.isEmpty ? null : link);
  }

  Future<void> _editGroupLink(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: course.groupLink ?? '');
    final link = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('لينك جروب الكورس'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'لينك جروب تيليجرام'),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => launchWebLink('https://t.me'),
              icon: const Icon(Icons.send_outlined, size: 18),
              label: const Text('افتح تيليجرام'),
            ),
          ],
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
    if (link == null) return;
    await ref
        .read(coursesRepositoryProvider)
        .updateCourseGroupLink(course.id, link.isEmpty ? null : link);
  }

  Future<void> _browseDrive(BuildContext context, WidgetRef ref) async {
    final link = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const DriveFolderPickerScreen()),
    );
    if (link == null) return;
    await ref
        .read(coursesRepositoryProvider)
        .updateCourseMaterialsLink(course.id, link);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmWithPassword(
      context,
      title: 'حذف الكورس نهائيًا',
      message:
          'هيتم حذف "${course.subjectName}" وكل الديمو والفصول الدراسية والطلاب المرتبطين بيه نهائيًا. اكتب كلمة المرور للتأكيد.',
    );
    if (!confirmed) return;
    await ref.read(coursesRepositoryProvider).deleteCourse(course.id);
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🗑️ تم حذف ${course.subjectName} نهائيًا')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final universities = ref.watch(universitiesProvider).valueOrNull ?? [];
    final universityName = universities
        .where((u) => u.id == course.universityId)
        .firstOrNull
        ?.name;
    final tutors = ref.watch(tutorsProvider).valueOrNull ?? [];
    final tutorName = tutors
        .where((t) => t.id == course.tutorId)
        .firstOrNull
        ?.name;

    return Scrollbar(
      thumbVisibility: true,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.subjectName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      ?universityName,
                      if (tutorName != null) '👨‍🏫 $tutorName',
                    ].join(' • '),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: courseStatusLabels.entries.map((e) {
                      final selected = course.status == e.key;
                      final c =
                          courseStatusColors[e.key] ?? AppColors.textMuted;
                      return ChoiceChip(
                        label: Text(e.value),
                        selected: selected,
                        onSelected: (_) => ref
                            .read(coursesRepositoryProvider)
                            .updateCourseStatus(course.id, e.key),
                        selectedColor: c.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: selected ? c : AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: selected ? c : AppColors.border,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _CourseSummaryCard(course: course, tutorName: tutorName),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.folder_outlined,
                color: AppColors.accent,
              ),
              title: Text(
                course.materialsLink == null || course.materialsLink!.isEmpty
                    ? 'إضافة لينك مواد الكورس'
                    : 'مواد الكورس (Drive)',
              ),
              subtitle:
                  course.materialsLink != null &&
                      course.materialsLink!.isNotEmpty
                  ? Text(
                      course.materialsLink!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    )
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (course.materialsLink != null &&
                      course.materialsLink!.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.share_outlined, size: 20),
                      tooltip: 'مشاركة اللينك',
                      onPressed: () => shareLink(course.materialsLink!),
                    ),
                  if (!kIsWeb)
                    IconButton(
                      icon: const Icon(
                        Icons.travel_explore_outlined,
                        size: 20,
                      ),
                      tooltip: 'تصفح Google Drive',
                      onPressed: () => _browseDrive(context, ref),
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => _editMaterialsLink(context, ref),
                  ),
                ],
              ),
              onTap:
                  (course.materialsLink != null &&
                      course.materialsLink!.isNotEmpty)
                  ? () => launchWebLink(course.materialsLink!)
                  : () => _editMaterialsLink(context, ref),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.smart_display_outlined,
                color: AppColors.accent,
              ),
              title: Text(
                course.demoLink == null || course.demoLink!.isEmpty
                    ? 'إضافة لينك الديمو'
                    : 'لينك الديمو',
              ),
              subtitle: course.demoLink != null && course.demoLink!.isNotEmpty
                  ? Text(
                      course.demoLink!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    )
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (course.demoLink != null && course.demoLink!.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.share_outlined, size: 20),
                      tooltip: 'مشاركة اللينك',
                      onPressed: () => shareLink(course.demoLink!),
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => _editDemoLink(context, ref),
                  ),
                ],
              ),
              onTap: (course.demoLink != null && course.demoLink!.isNotEmpty)
                  ? () => launchWebLink(course.demoLink!)
                  : () => _editDemoLink(context, ref),
            ),
          ),
          if (course.status != 'planning') ...[
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.groups_outlined, color: AppColors.accent),
                title: Text(
                  course.groupLink == null || course.groupLink!.isEmpty
                      ? 'إضافة لينك جروب الكورس'
                      : 'جروب الكورس',
                ),
                subtitle:
                    course.groupLink != null && course.groupLink!.isNotEmpty
                    ? Text(
                        course.groupLink!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      )
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (course.groupLink != null &&
                        course.groupLink!.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.share_outlined, size: 20),
                        tooltip: 'مشاركة اللينك',
                        onPressed: () => shareLink(course.groupLink!),
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _editGroupLink(context, ref),
                    ),
                  ],
                ),
                onTap:
                    (course.groupLink != null && course.groupLink!.isNotEmpty)
                    ? () => launchWebLink(course.groupLink!)
                    : () => _editGroupLink(context, ref),
              ),
            ),
          ],
          const SizedBox(height: 10),
          _DemosSection(course: course),
          const SizedBox(height: 10),
          _CourseTermsSection(course: course),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _delete(context, ref),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
            ),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('حذف الكورس نهائيًا'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

String _fmtMoney(double v) {
  return v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
}

String _enrollmentSourceLabel(Enrollment enrollment, Student? student) {
  final resolved = resolveAcquisitionSource(
    overrideSource: enrollment.acquisitionSource,
    overrideMarketerName: enrollment.marketerName,
    overrideCommissionPct: enrollment.commissionPct,
    studentSource: student?.acquisitionSource,
    studentMarketerName: student?.marketerName,
    studentCommissionPct: student?.commissionPct,
  );
  switch (resolved.source) {
    case 'haraj':
      return 'حراج';
    case 'marketer':
      final name = resolved.marketerName;
      return 'مسوق${name != null && name.isNotEmpty ? ' ($name)' : ''}';
    default:
      return 'مباشر';
  }
}

Future<void> _editEnrollmentSource(
  BuildContext context,
  WidgetRef ref,
  Enrollment enrollment,
  Student? student,
) async {
  final resolved = resolveAcquisitionSource(
    overrideSource: enrollment.acquisitionSource,
    overrideMarketerName: enrollment.marketerName,
    overrideCommissionPct: enrollment.commissionPct,
    studentSource: student?.acquisitionSource,
    studentMarketerName: student?.marketerName,
    studentCommissionPct: student?.commissionPct,
  );
  var source = resolved.source;
  String? marketerName = resolved.marketerName;
  double? commissionPct = resolved.commissionPct;

  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('تعديل مصدر الطالب لهذا الكورس'),
      content: SizedBox(
        width: double.maxFinite,
        child: StudentSourceFields(
          initialSource: source,
          initialMarketerName: marketerName,
          initialCommissionPct: commissionPct,
          onChanged: (s, m, pct) {
            source = s;
            marketerName = m;
            commissionPct = pct;
          },
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
  );
  if (saved != true) return;
  await ref
      .read(coursesRepositoryProvider)
      .updateEnrollmentSource(
        id: enrollment.id,
        acquisitionSource: source,
        marketerName: marketerName,
        commissionPct: commissionPct,
      );
}

class _CourseSummaryCard extends ConsumerWidget {
  const _CourseSummaryCard({required this.course, required this.tutorName});

  final Course course;
  final String? tutorName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseTermsAsync = ref.watch(courseTermsProvider(course.id));
    final courseTerms = courseTermsAsync.valueOrNull ?? [];

    if (courseTerms.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 18,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'المدرس: ${tutorName ?? 'لسه مفيش'} — لسه مفيش فصل دراسي مضاف عشان نحسب الإيراد والأرباح',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final termEnrollments = <String, List<Enrollment>>{};
    for (final ct in courseTerms) {
      final async = ref.watch(enrollmentsProvider(ct.id));
      termEnrollments[ct.id] = async.valueOrNull ?? [];
    }
    final allEnrollments = termEnrollments.values.expand((e) => e).toList();
    final studentsCount = allEnrollments.map((e) => e.studentId).toSet().length;

    // A cancelled enrollment only counts what was actually paid before the
    // cancellation — not the full amount they were originally contracted for.
    // Any write-off (discount / gateway fee) always reduces what's owed.
    double effectiveAmount(Enrollment e) {
      if (e.status != 'cancelled') return e.effectiveAmount;
      return (ref.watch(enrollmentPaymentsProvider(e.id)).valueOrNull ?? [])
          .fold<double>(0, (sum, p) => sum + p.amount);
    }

    final revenue = <String, double>{};
    final cost = <String, double>{};
    for (final ct in courseTerms) {
      final ctEnrollments = termEnrollments[ct.id] ?? [];
      for (final e in ctEnrollments) {
        revenue[e.currency] = (revenue[e.currency] ?? 0) + effectiveAmount(e);
      }
      if (ct.pricingModel == 'flat') {
        if (ct.tutorFlatFee != null) {
          cost[ct.tutorFlatFeeCurrency] =
              (cost[ct.tutorFlatFeeCurrency] ?? 0) + ct.tutorFlatFee!;
        }
      } else {
        final byCurrency = <String, double>{};
        for (final e in ctEnrollments) {
          byCurrency[e.currency] =
              (byCurrency[e.currency] ?? 0) + effectiveAmount(e);
        }
        byCurrency.forEach((currency, amount) {
          cost[currency] =
              (cost[currency] ?? 0) + amount * ct.revsharePct / 100;
        });
      }
    }

    var paid = <String, double>{};
    var paidSar = 0.0;
    if (course.tutorId != null) {
      final ledger =
          ref.watch(tutorLedgerProvider(course.tutorId!)).valueOrNull ?? [];
      final termIds = courseTerms.map((t) => t.id).toSet();
      for (final p in ledger) {
        if (p.courseTermId != null && termIds.contains(p.courseTermId)) {
          paid[p.currency] = (paid[p.currency] ?? 0) + p.amount;
          paidSar += p.currency == 'SAR'
              ? p.amount
              : (p.equivalentSarAmount ?? 0);
        }
      }
    }
    final revenueSar = revenue['SAR'] ?? 0;
    final profitSar = revenueSar - paidSar;

    final remaining = <String, double>{
      for (final currency in cost.keys)
        currency: cost[currency]! - (paid[currency] ?? 0),
    };
    // Profit is revenue minus what's actually been paid to the tutor so far
    // (not the target/owed amount) — matches cash actually settled.
    final profitCurrencies = {...revenue.keys, ...paid.keys};
    final profit = <String, double>{
      for (final currency in profitCurrencies)
        currency: (revenue[currency] ?? 0) - (paid[currency] ?? 0),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'نظرة عامة على الكورس',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 10),
            _SummaryLine(label: 'المدرس', value: tutorName ?? '— لسه مفيش —'),
            _SummaryLine(label: 'عدد الطلاب المسجلين', value: '$studentsCount'),
            if (revenue.isNotEmpty)
              _SummaryMoneySection(
                title: 'الإيراد',
                amounts: revenue,
                color: AppColors.info,
              ),
            if (cost.isNotEmpty) ...[
              _SummaryMoneySection(
                title: 'مستحق للمدرس (إجمالي الاتفاق)',
                amounts: cost,
                color: AppColors.textMuted,
              ),
              _SummaryMoneySection(
                title: '✅ المدفوع فعليًا للمدرس',
                amounts: paid,
                color: AppColors.success,
              ),
              _SummaryMoneySection(
                title: 'المتبقي للمدرس',
                amounts: remaining,
                color: AppColors.warning,
              ),
            ],
            if (profit.isNotEmpty)
              _SummaryMoneySection(
                title: 'ربح الأكاديمية (بعد دفع المدرس حتى الآن)',
                amounts: profit,
                color: AppColors.accent,
                signed: true,
              ),
            if (paid.isNotEmpty) ...[
              const Divider(height: 20),
              _SummaryLine(
                label: 'ربح الأكاديمية بالريال (بناءً على المدفوع فعليًا)',
                value:
                    '${profitSar >= 0 ? '+' : ''}${_fmtMoney(profitSar)} SAR',
                valueColor: profitSar >= 0
                    ? AppColors.success
                    : AppColors.error,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMoneySection extends StatelessWidget {
  const _SummaryMoneySection({
    required this.title,
    required this.amounts,
    required this.color,
    this.signed = false,
  });

  final String title;
  final Map<String, double> amounts;
  final Color color;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    if (amounts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Wrap(
            spacing: 10,
            runSpacing: 2,
            children: amounts.entries.map((e) {
              final negative = signed && e.value < 0;
              final valueColor = signed
                  ? (negative ? AppColors.error : AppColors.success)
                  : color;
              final prefix = signed && e.value > 0 ? '+' : '';
              return Text(
                '$prefix${_fmtMoney(e.value)} ${e.key}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

const _outcomeLabels = {
  'pending': 'قيد الانتظار',
  'selected': 'تم الاختيار',
  'rejected': 'مرفوض',
};
const _outcomeColors = {
  'pending': AppColors.warning,
  'selected': AppColors.success,
  'rejected': AppColors.error,
};

class _DemosSection extends ConsumerWidget {
  const _DemosSection({required this.course});

  final Course course;

  Future<void> _addDemo(BuildContext context, WidgetRef ref) async {
    final tutors = ref.read(tutorsProvider).valueOrNull ?? [];
    Tutor? selectedTutor;
    DateTime? demoAt;
    final notesController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: const Text('إضافة ديمو'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<Tutor>(
                    initialValue: selectedTutor,
                    decoration: const InputDecoration(labelText: 'المدرس'),
                    items: tutors
                        .map(
                          (t) =>
                              DropdownMenuItem(value: t, child: Text(t.name)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => selectedTutor = v),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (date == null) return;
                      if (!context.mounted) return;
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      setState(
                        () => demoAt = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time?.hour ?? 0,
                          time?.minute ?? 0,
                        ),
                      );
                    },
                    child: Text(
                      demoAt == null
                          ? 'موعد الديمو'
                          : intl.DateFormat(
                              'd MMM yyyy — h:mm a',
                              'ar',
                            ).format(demoAt!),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات (اختياري)',
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
              onPressed: selectedTutor == null
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || selectedTutor == null) return;
    await ref
        .read(coursesRepositoryProvider)
        .addDemo(
          courseId: course.id,
          tutorId: selectedTutor!.id,
          demoAt: demoAt,
          notes: notesController.text.trim().isEmpty
              ? null
              : notesController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demosAsync = ref.watch(courseDemosProvider(course.id));
    final tutors = ref.watch(tutorsProvider).valueOrNull ?? [];
    final tutorNames = {for (final t in tutors) t.id: t.name};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'الديمو',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _addDemo(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('إضافة'),
                ),
              ],
            ),
            demosAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, st) => Text(
                'حصل خطأ: $err',
                style: const TextStyle(color: AppColors.error),
              ),
              data: (demos) {
                if (demos.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'لسه مفيش ديمو مضاف',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  );
                }
                return Column(
                  children: demos
                      .map(
                        (d) => _DemoRow(
                          demo: d,
                          tutorName: tutorNames[d.tutorId] ?? '؟',
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoRow extends ConsumerWidget {
  const _DemoRow({required this.demo, required this.tutorName});

  final CourseDemo demo;
  final String tutorName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _outcomeColors[demo.outcome] ?? AppColors.textMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tutorName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (demo.demoAt != null)
                  Text(
                    intl.DateFormat(
                      'd MMM — h:mm a',
                      'ar',
                    ).format(demo.demoAt!),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          if (demo.outcome == 'pending') ...[
            IconButton(
              icon: const Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
              ),
              onPressed: () => ref
                  .read(coursesRepositoryProvider)
                  .setDemoOutcome(demo, 'selected'),
              tooltip: 'اختيار',
            ),
            IconButton(
              icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
              onPressed: () => ref
                  .read(coursesRepositoryProvider)
                  .setDemoOutcome(demo, 'rejected'),
              tooltip: 'رفض',
            ),
          ] else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _outcomeLabels[demo.outcome] ?? demo.outcome,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

const _termPricingLabels = {
  'flat': 'مبلغ مقطوع',
  'revshare': 'نسبة من الإيراد',
};
const _termStatusOptions = {
  'planning': 'تخطيط',
  'marketing': 'تسويق',
  'active': 'نشط',
  'completed': 'مكتمل',
  'cancelled': 'ملغي',
};

class _CourseTermsSection extends ConsumerWidget {
  const _CourseTermsSection({required this.course});

  final Course course;

  Future<void> _addTerm(BuildContext context, WidgetRef ref) async {
    final terms = await ref.read(termsProvider.future);
    if (!context.mounted) return;

    Term? selectedTerm;
    bool addingNewTerm = false;
    String newTermSemester = 'first';
    final newTermYearController = TextEditingController(
      text: DateTime.now().year.toString(),
    );
    bool openedBefore = false;
    final flatFeeController = TextEditingController();
    final revsharePctController = TextEditingController(text: '10');
    final studentPriceController = TextEditingController();
    String tutorCurrency = 'EGP';
    String studentCurrency = 'SAR';

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: const Text('إضافة فصل دراسي للكورس'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: openedBefore,
                    onChanged: (v) => setState(() => openedBefore = v ?? false),
                    title: const Text(
                      'الكورس اتفتح قبل كده؟',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      openedBefore
                          ? 'المدرس ياخد 10% من كل اشتراك'
                          : 'المدرس ياخد مبلغ ثابت (أول مرة)',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (!openedBefore)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: flatFeeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'مبلغ المدرس',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: tutorCurrency,
                          items: const ['EGP', 'SAR', 'USD']
                              .map(
                                (c) =>
                                    DropdownMenuItem(value: c, child: Text(c)),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => tutorCurrency = v ?? 'EGP'),
                        ),
                      ],
                    )
                  else
                    TextField(
                      controller: revsharePctController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'نسبة المدرس %',
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: studentPriceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'سعر الطالب',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: studentCurrency,
                        items: const ['SAR', 'EGP', 'USD', 'AED']
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => studentCurrency = v ?? 'SAR'),
                      ),
                    ],
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
              onPressed: (selectedTerm == null && !addingNewTerm)
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    String? termId = selectedTerm?.id;
    if (addingNewTerm) {
      final startYear = int.tryParse(newTermYearController.text.trim());
      if (startYear == null) return;
      final newTerm = await ref
          .read(universitiesRepositoryProvider)
          .addTerm(
            semester: newTermSemester,
            academicYear: '$startYear/${startYear + 1}',
            status: 'active',
          );
      termId = newTerm.id;
    }
    if (termId == null) return;
    final pricingModel = openedBefore ? 'revshare' : 'flat';
    await ref
        .read(coursesRepositoryProvider)
        .addCourseTerm(
          courseId: course.id,
          termId: termId,
          pricingModelOverride: pricingModel,
          tutorFlatFee: pricingModel == 'flat'
              ? double.tryParse(flatFeeController.text)
              : null,
          tutorFlatFeeCurrency: tutorCurrency,
          revsharePct: double.tryParse(revsharePctController.text) ?? 10,
          studentPrice: double.tryParse(studentPriceController.text),
          studentPriceCurrency: studentCurrency,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termsAsync = ref.watch(courseTermsProvider(course.id));
    final terms = ref.watch(termsProvider).valueOrNull ?? [];
    final termNames = {for (final t in terms) t.id: t.name};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'التسعير لكل فصل دراسي',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _addTerm(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('إضافة'),
                ),
              ],
            ),
            termsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, st) => Text(
                'حصل خطأ: $err',
                style: const TextStyle(color: AppColors.error),
              ),
              data: (courseTerms) {
                if (courseTerms.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'لسه مفيش فصل دراسي مضاف',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  );
                }
                return Column(
                  children: courseTerms
                      .map(
                        (ct) => _CourseTermCard(
                          courseTerm: ct,
                          termName: termNames[ct.termId] ?? '؟',
                          tutorId: course.tutorId,
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseTermCard extends ConsumerWidget {
  const _CourseTermCard({
    required this.courseTerm,
    required this.termName,
    required this.tutorId,
  });

  final CourseTerm courseTerm;
  final String termName;
  final String? tutorId;

  Future<void> _recordPayment(
    BuildContext context,
    WidgetRef ref,
    String currency,
  ) async {
    final amountController = TextEditingController();
    final sarEquivalentController = TextEditingController();
    final notesController = TextEditingController();
    final needsEquivalent = currency != 'SAR';

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: const Text('تسجيل دفعة للمدرس'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(labelText: 'المبلغ ($currency)'),
                ),
                if (needsEquivalent) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: sarEquivalentController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ما يعادلها بالريال (SAR)',
                      helperText: 'عشان نحسب ربح الأكاديمية بالريال',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
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
            child: const Text('تسجيل'),
          ),
        ],
      ),
    );

    if (saved != true || tutorId == null) return;
    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) return;
    await ref
        .read(coursesRepositoryProvider)
        .addTutorPayment(
          tutorId: tutorId!,
          courseTermId: courseTerm.id,
          amount: amount,
          currency: currency,
          equivalentSarAmount: needsEquivalent
              ? double.tryParse(sarEquivalentController.text.trim())
              : amount,
          notes: notesController.text.trim().isEmpty
              ? null
              : notesController.text.trim(),
        );
  }

  void _showPaymentHistory(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          _PaymentHistorySheet(courseTermId: courseTerm.id, tutorId: tutorId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrollments =
        ref.watch(enrollmentsProvider(courseTerm.id)).valueOrNull ?? [];

    double? targetAmount;
    var targetCurrency = courseTerm.tutorFlatFeeCurrency;
    if (courseTerm.pricingModel == 'flat') {
      targetAmount = courseTerm.tutorFlatFee;
    } else if (enrollments.isNotEmpty) {
      targetCurrency = enrollments.first.currency;
      final termRevenue = enrollments
          .where((e) => e.currency == targetCurrency)
          .fold(0.0, (sum, e) => sum + e.amount);
      targetAmount = termRevenue * courseTerm.revsharePct / 100;
    }

    double paid = 0;
    if (tutorId != null) {
      final ledger = ref.watch(tutorLedgerProvider(tutorId!)).valueOrNull ?? [];
      paid = ledger
          .where(
            (p) =>
                p.courseTermId == courseTerm.id && p.currency == targetCurrency,
          )
          .fold(0.0, (sum, p) => sum + p.amount);
    }
    final remaining = targetAmount != null ? targetAmount - paid : null;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  termName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _termPricingLabels[courseTerm.pricingModel] ??
                      courseTerm.pricingModel,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            courseTerm.pricingModel == 'flat'
                ? 'المدرس: ${courseTerm.tutorFlatFee?.toStringAsFixed(0) ?? '—'} ${courseTerm.tutorFlatFeeCurrency}'
                : 'المدرس: ${courseTerm.revsharePct.toStringAsFixed(0)}% من الإيراد',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          Text(
            'الطالب: ${courseTerm.studentPrice?.toStringAsFixed(0) ?? '—'} ${courseTerm.studentPriceCurrency}',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          if (tutorId != null && targetAmount != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'مدفوع: ${_fmtMoney(paid)} من ${_fmtMoney(targetAmount)} $targetCurrency',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: (remaining ?? 0) > 0
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _showPaymentHistory(context, ref),
                  child: const Text(
                    'سجل الدفعات',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () => _recordPayment(context, ref, targetCurrency),
                  child: const Text(
                    'تسجيل دفعة',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: courseTerm.status,
                  isDense: true,
                  decoration: const InputDecoration(isDense: true),
                  items: _termStatusOptions.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      ref
                          .read(coursesRepositoryProvider)
                          .updateCourseTermStatus(courseTerm.id, v);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _showEnrollments(context, ref, courseTerm),
                child: const Text('الطلاب'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEnrollments(
    BuildContext context,
    WidgetRef ref,
    CourseTerm courseTerm,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _EnrollmentsSheet(courseTerm: courseTerm),
    );
  }
}

const _ledgerTypeLabels = {
  'deposit': 'دفعة',
  'final_settlement': 'تسوية نهائية',
  'revshare_payout': 'نسبة من الإيراد',
  'private_session_payout': 'حصة خاصة',
};

class _PaymentHistorySheet extends ConsumerWidget {
  const _PaymentHistorySheet({
    required this.courseTermId,
    required this.tutorId,
  });

  final String courseTermId;
  final String? tutorId;

  Future<void> _editPayment(
    BuildContext context,
    WidgetRef ref,
    TutorPayment payment,
  ) async {
    final amountController = TextEditingController(
      text: _fmtMoney(payment.amount),
    );
    final sarEquivalentController = TextEditingController(
      text: payment.equivalentSarAmount != null
          ? _fmtMoney(payment.equivalentSarAmount!)
          : '',
    );
    final notesController = TextEditingController(text: payment.notes ?? '');
    var currency = payment.currency;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: const Text('تعديل الدفعة'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'المبلغ',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: currency,
                        items: const ['EGP', 'SAR', 'USD', 'AED']
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => currency = v ?? currency),
                      ),
                    ],
                  ),
                  if (currency != 'SAR') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: sarEquivalentController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'ما يعادلها بالريال (SAR)',
                        helperText: 'عشان نحسب ربح الأكاديمية بالريال',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات (اختياري)',
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
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) return;
    await ref
        .read(coursesRepositoryProvider)
        .updateTutorPayment(
          id: payment.id,
          amount: amount,
          currency: currency,
          equivalentSarAmount: currency == 'SAR'
              ? amount
              : double.tryParse(sarEquivalentController.text.trim()),
          notes: notesController.text.trim().isEmpty
              ? null
              : notesController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = tutorId == null
        ? <TutorPayment>[]
        : (ref.watch(tutorLedgerProvider(tutorId!)).valueOrNull ?? [])
              .where((p) => p.courseTermId == courseTermId)
              .toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'سجل الدفعات للمدرس',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 12),
            if (payments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'لسه مفيش دفعات مسجلة',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: payments.length,
                  separatorBuilder: (context, i) => const Divider(height: 16),
                  itemBuilder: (context, i) {
                    final p = payments[i];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_fmtMoney(p.amount)} ${p.currency}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              if (p.equivalentSarAmount != null &&
                                  p.currency != 'SAR')
                                Text(
                                  '≈ ${_fmtMoney(p.equivalentSarAmount!)} SAR',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              Text(
                                _ledgerTypeLabels[p.type] ?? p.type,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              if (p.notes != null && p.notes!.isNotEmpty)
                                Text(
                                  p.notes!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              intl.DateFormat(
                                'd MMM yyyy',
                                'ar',
                              ).format(p.date),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _editPayment(context, ref, p),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

const _paymentStatusLabels = {
  'pending': 'معلق',
  'partial': 'مدفوع جزئيًا',
  'paid': 'مدفوع',
  'overdue': 'متأخر',
};
const _paymentStatusColors = {
  'pending': AppColors.warning,
  'partial': AppColors.info,
  'paid': AppColors.success,
  'overdue': AppColors.error,
};
const _paymentMethodLabels = {
  'cash': '💵 كاش',
  'visa': '💳 فيزا',
  'tabby': '🟣 تابي',
  'tamara': '🟢 تمارا',
};

class _EnrollmentsSheet extends ConsumerWidget {
  const _EnrollmentsSheet({required this.courseTerm});

  final CourseTerm courseTerm;

  Future<void> _addEnrollment(BuildContext context, WidgetRef ref) async {
    final students = ref.read(studentsProvider).valueOrNull ?? [];
    Student? selectedStudent;
    final newStudentNameController = TextEditingController();
    String? newStudentPhone;
    String enrollmentSource = 'direct';
    String? enrollmentMarketer;
    double? enrollmentCommissionPct;
    final amountController = TextEditingController(
      text: courseTerm.studentPrice?.toStringAsFixed(0) ?? '',
    );
    String currency = courseTerm.studentPriceCurrency;
    String paymentMethod = 'cash';
    String? formError;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: const Text('إضافة طالب'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<Student?>(
                    initialValue: selectedStudent,
                    decoration: const InputDecoration(labelText: 'طالب موجود'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('— طالب جديد —'),
                      ),
                      ...students.map(
                        (s) => DropdownMenuItem(value: s, child: Text(s.name)),
                      ),
                    ],
                    onChanged: (v) => setState(() => selectedStudent = v),
                  ),
                  if (selectedStudent == null) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: newStudentNameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم الطالب الجديد',
                      ),
                    ),
                    const SizedBox(height: 12),
                    PhoneNumberField(
                      label: 'رقم الواتساب *',
                      onChanged: (v) => newStudentPhone = v,
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    'مصدر الطالب لهذا الكورس',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  StudentSourceFields(
                    key: ValueKey(selectedStudent?.id ?? 'new'),
                    initialSource:
                        selectedStudent?.acquisitionSource ?? 'direct',
                    initialMarketerName: selectedStudent?.marketerName,
                    initialCommissionPct: selectedStudent?.commissionPct,
                    onChanged: (source, marketer, pct) {
                      enrollmentSource = source;
                      enrollmentMarketer = marketer;
                      enrollmentCommissionPct = pct;
                    },
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'المبلغ',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: currency,
                        items: const ['SAR', 'EGP', 'USD', 'AED']
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => currency = v ?? 'SAR'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: paymentMethod,
                    decoration: const InputDecoration(labelText: 'وسيلة الدفع'),
                    items: _paymentMethodLabels.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => paymentMethod = v ?? 'cash'),
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
              onPressed: () {
                if (selectedStudent == null &&
                    (newStudentNameController.text.trim().isEmpty ||
                        newStudentPhone == null)) {
                  setState(
                    () => formError = 'لازم تكتب اسم ورقم واتساب الطالب',
                  );
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
    String studentId;
    if (selectedStudent != null) {
      studentId = selectedStudent!.id;
    } else {
      final newStudent = await ref
          .read(studentsRepositoryProvider)
          .addStudent(
            name: newStudentNameController.text.trim(),
            phoneWhatsapp: newStudentPhone,
            acquisitionSource: enrollmentSource,
            marketerName: enrollmentMarketer,
            commissionPct: enrollmentCommissionPct,
          );
      studentId = newStudent.id;
    }
    await ref
        .read(coursesRepositoryProvider)
        .addEnrollment(
          courseTermId: courseTerm.id,
          studentId: studentId,
          amount: double.tryParse(amountController.text) ?? 0,
          currency: currency,
          paymentMethod: paymentMethod,
          acquisitionSource: enrollmentSource,
          marketerName: enrollmentMarketer,
          commissionPct: enrollmentCommissionPct,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrollmentsAsync = ref.watch(enrollmentsProvider(courseTerm.id));
    final students = ref.watch(studentsProvider).valueOrNull ?? [];
    final studentNames = {for (final s in students) s.id: s.name};
    final studentById = {for (final s in students) s.id: s};

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'الطلاب المسجلين',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _addEnrollment(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('إضافة'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Flexible(
              child: enrollmentsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, st) => Text(
                  'حصل خطأ: $err',
                  style: const TextStyle(color: AppColors.error),
                ),
                data: (enrollments) {
                  if (enrollments.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'لسه مفيش طلاب مسجلين',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: enrollments.length,
                    itemBuilder: (context, i) {
                      final e = enrollments[i];
                      final color =
                          _paymentStatusColors[e.paymentStatus] ??
                          AppColors.textMuted;
                      final paid =
                          (ref
                                      .watch(enrollmentPaymentsProvider(e.id))
                                      .valueOrNull ??
                                  [])
                              .fold<double>(0, (sum, p) => sum + p.amount);
                      final remaining = e.effectiveAmount - paid;
                      final cancelled = e.status == 'cancelled';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                studentNames[e.studentId] ?? '؟',
                                style: cancelled
                                    ? const TextStyle(
                                        decoration: TextDecoration.lineThrough,
                                        color: AppColors.textMuted,
                                      )
                                    : null,
                              ),
                            ),
                            if (cancelled) ...[
                              const SizedBox(width: 6),
                              const Text(
                                'ملغي',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          '${_enrollmentSourceLabel(e, studentById[e.studentId])} • '
                          '${e.amount.toStringAsFixed(0)} ${e.currency} • ${_paymentMethodLabels[e.paymentMethod] ?? e.paymentMethod}'
                          '${e.writeOffAmount > 0.01 ? ' • ${enrollmentWriteOffReasons[e.writeOffReason] ?? 'خصم'} ${e.writeOffAmount.toStringAsFixed(0)}' : ''}'
                          '${!cancelled && remaining > 0.01 ? ' • متبقي ${remaining.toStringAsFixed(0)} ${e.currency}' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 20),
                              onSelected: (action) async {
                                if (action == 'edit_source') {
                                  await _editEnrollmentSource(
                                    context,
                                    ref,
                                    e,
                                    studentById[e.studentId],
                                  );
                                  return;
                                }
                                final studentName =
                                    studentNames[e.studentId] ?? 'الطالب';
                                final confirmed = await confirmWithPassword(
                                  context,
                                  title: cancelled
                                      ? 'إعادة اشتراك $studentName'
                                      : 'إلغاء اشتراك $studentName',
                                  message: cancelled
                                      ? 'هيتم اعتبار $studentName مشترك تاني في الكورس. اكتب كلمة المرور للتأكيد.'
                                      : 'هيتم اعتبار $studentName منسحب من الكورس — المبلغ المتبقي مش هيتحسب ضمن الإيرادات. اكتب كلمة المرور للتأكيد.',
                                );
                                if (!confirmed) return;
                                await ref
                                    .read(coursesRepositoryProvider)
                                    .updateEnrollmentStatus(
                                      e.id,
                                      cancelled ? 'active' : 'cancelled',
                                    );
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit_source',
                                  child: Text('تعديل مصدر الطالب'),
                                ),
                                PopupMenuItem(
                                  value: 'toggle_status',
                                  child: Text(
                                    cancelled
                                        ? 'إعادة الاشتراك'
                                        : 'إلغاء الاشتراك',
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.payments_outlined,
                                size: 20,
                              ),
                              tooltip: 'دفعات الطالب',
                              onPressed: () => showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: AppColors.surface,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                ),
                                builder: (context) =>
                                    _EnrollmentPaymentsSheet(enrollment: e),
                              ),
                            ),
                            DropdownButton<String>(
                              value: e.paymentStatus,
                              underline: const SizedBox.shrink(),
                              items: _paymentStatusLabels.entries
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s.key,
                                      child: Text(
                                        s.value,
                                        style: TextStyle(
                                          color: color,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) async {
                                if (v == null) return;
                                if (v == 'partial') {
                                  await _recordEnrollmentPayment(
                                    context,
                                    ref,
                                    e,
                                    remaining: remaining,
                                  );
                                } else if (v == 'paid' && remaining > 0.01) {
                                  await _recordEnrollmentPayment(
                                    context,
                                    ref,
                                    e,
                                    remaining: remaining,
                                    prefillAmount: remaining,
                                  );
                                } else {
                                  await ref
                                      .read(coursesRepositoryProvider)
                                      .updateEnrollmentPaymentStatus(e.id, v);
                                }
                              },
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
        ),
      ),
    );
  }
}

Future<void> _recordEnrollmentPayment(
  BuildContext context,
  WidgetRef ref,
  Enrollment enrollment, {
  required double remaining,
  double? prefillAmount,
}) async {
  final amountController = TextEditingController(
    text: prefillAmount != null && prefillAmount > 0
        ? _fmtMoney(prefillAmount)
        : '',
  );
  var paymentMethod = enrollment.paymentMethod;
  final notesController = TextEditingController();
  final writeOffController = TextEditingController();
  String? writeOffReason;
  String? formError;

  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        void useGapAsWriteOff() {
          final entered = double.tryParse(amountController.text.trim()) ?? 0;
          final gap = remaining - entered;
          if (gap > 0.01) {
            setState(() {
              writeOffController.text = _fmtMoney(gap);
              writeOffReason ??= 'gateway_fee';
            });
          }
        }

        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: const Text('إضافة دفعة'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'المبلغ المستلم (${enrollment.currency})',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: paymentMethod,
                    decoration: const InputDecoration(labelText: 'وسيلة الدفع'),
                    items: _paymentMethodLabels.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => paymentMethod = v ?? 'cash'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات (اختياري)',
                    ),
                  ),
                  if (remaining > 0.01) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: useGapAsWriteOff,
                        child: const Text(
                          'الفرق مش هيتحصّل؟ سجّله كخصم أو رسوم',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                  const Divider(height: 24),
                  const Text(
                    'خصم أو رسوم بوابة دفع (اختياري)',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: writeOffController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'المبلغ المتنازل عنه',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: writeOffReason,
                    decoration: const InputDecoration(labelText: 'السبب'),
                    items: enrollmentWriteOffReasons.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => writeOffReason = v),
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
                final amount =
                    double.tryParse(amountController.text.trim()) ?? 0;
                final writeOff =
                    double.tryParse(writeOffController.text.trim()) ?? 0;
                if (amount <= 0 && writeOff <= 0) {
                  setState(() => formError = 'اكتب مبلغ مدفوع أو مبلغ خصم');
                  return;
                }
                if (writeOff > 0 && writeOffReason == null) {
                  setState(() => formError = 'اختار سبب الخصم/الرسوم');
                  return;
                }
                if (amount + writeOff > remaining + 0.01) {
                  setState(
                    () => formError =
                        'المبلغ والخصم مع بعض أكبر من المتبقي (${_fmtMoney(remaining)} ${enrollment.currency})',
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    ),
  );

  if (saved != true) return;
  final amount = double.tryParse(amountController.text.trim()) ?? 0;
  final writeOff = double.tryParse(writeOffController.text.trim()) ?? 0;
  final repo = ref.read(coursesRepositoryProvider);
  if (amount > 0) {
    await repo.addEnrollmentPayment(
      enrollmentId: enrollment.id,
      amount: amount,
      currency: enrollment.currency,
      paymentMethod: paymentMethod,
      notes: notesController.text.trim().isEmpty
          ? null
          : notesController.text.trim(),
    );
  }
  if (writeOff > 0 && writeOffReason != null) {
    await repo.addEnrollmentWriteOff(
      enrollmentId: enrollment.id,
      amount: writeOff,
      reason: writeOffReason!,
    );
  }
}

Future<void> _editEnrollmentPayment(
  BuildContext context,
  WidgetRef ref,
  Enrollment enrollment,
  EnrollmentPayment payment, {
  required double remainingForOthers,
}) async {
  final amountController = TextEditingController(
    text: _fmtMoney(payment.amount),
  );
  var paymentMethod = payment.paymentMethod;
  final notesController = TextEditingController(text: payment.notes ?? '');
  String? formError;

  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: const Text('تعديل الدفعة'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'المبلغ (${enrollment.currency})',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: paymentMethod,
                  decoration: const InputDecoration(labelText: 'وسيلة الدفع'),
                  items: _paymentMethodLabels.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => paymentMethod = v ?? 'cash'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
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
              final amount = double.tryParse(amountController.text.trim());
              if (amount == null || amount <= 0) {
                setState(() => formError = 'اكتب مبلغ صحيح');
                return;
              }
              if (amount > remainingForOthers + 0.01) {
                setState(
                  () => formError =
                      'المبلغ أكبر من إجمالي الكورس (أقصى مبلغ ${_fmtMoney(remainingForOthers)} ${enrollment.currency})',
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );

  if (saved != true) return;
  final amount = double.tryParse(amountController.text.trim());
  if (amount == null || amount <= 0) return;
  await ref
      .read(coursesRepositoryProvider)
      .updateEnrollmentPayment(
        id: payment.id,
        enrollmentId: enrollment.id,
        amount: amount,
        currency: payment.currency,
        paymentMethod: paymentMethod,
        notes: notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
      );
}

Future<void> _deleteEnrollmentPayment(
  BuildContext context,
  WidgetRef ref,
  Enrollment enrollment,
  EnrollmentPayment payment,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('حذف الدفعة'),
      content: Text(
        'هيتم حذف دفعة ${_fmtMoney(payment.amount)} ${payment.currency}. متأكد؟',
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
  if (confirmed != true) return;
  await ref
      .read(coursesRepositoryProvider)
      .deleteEnrollmentPayment(id: payment.id, enrollmentId: enrollment.id);
}

class _EnrollmentPaymentsSheet extends ConsumerWidget {
  const _EnrollmentPaymentsSheet({required this.enrollment});

  final Enrollment enrollment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments =
        ref.watch(enrollmentPaymentsProvider(enrollment.id)).valueOrNull ?? [];
    final paid = payments.fold<double>(0, (sum, p) => sum + p.amount);
    final remaining = enrollment.effectiveAmount - paid;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'دفعات الطالب',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _recordEnrollmentPayment(
                    context,
                    ref,
                    enrollment,
                    remaining: remaining,
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('إضافة دفعة'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'الإجمالي ${enrollment.amount.toStringAsFixed(0)} ${enrollment.currency}'
              '${enrollment.writeOffAmount > 0.01 ? ' • ${enrollmentWriteOffReasons[enrollment.writeOffReason] ?? 'خصم'} ${enrollment.writeOffAmount.toStringAsFixed(0)}' : ''}'
              ' • المدفوع ${paid.toStringAsFixed(0)}'
              ' • المتبقي ${remaining.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: remaining > 0.01 ? AppColors.warning : AppColors.success,
              ),
            ),
            const SizedBox(height: 12),
            if (payments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'لسه مفيش دفعات مسجلة',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: payments.length,
                  separatorBuilder: (context, i) => const Divider(height: 16),
                  itemBuilder: (context, i) {
                    final p = payments[i];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${p.amount.toStringAsFixed(0)} ${p.currency}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _paymentMethodLabels[p.paymentMethod] ??
                                    p.paymentMethod,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              if (p.notes != null && p.notes!.isNotEmpty)
                                Text(
                                  p.notes!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              intl.DateFormat(
                                'd MMM yyyy',
                                'ar',
                              ).format(p.paidAt),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _editEnrollmentPayment(
                                    context,
                                    ref,
                                    enrollment,
                                    p,
                                    remainingForOthers:
                                        enrollment.effectiveAmount -
                                        (paid - p.amount),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: AppColors.error,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _deleteEnrollmentPayment(
                                    context,
                                    ref,
                                    enrollment,
                                    p,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
