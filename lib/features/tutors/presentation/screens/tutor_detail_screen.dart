import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/contact_links.dart';
import '../../../../core/utils/reauth.dart';
import '../../../../core/widgets/realtime_error_view.dart';
import '../../domain/entities/tutor.dart';
import '../../domain/entities/tutor_finance_summary.dart';
import '../providers/tutors_providers.dart';
import '../widgets/subject_chips.dart';

class TutorDetailScreen extends ConsumerWidget {
  const TutorDetailScreen({super.key, required this.tutorId});

  final String tutorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tutorsAsync = ref.watch(tutorsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('بيانات المدرس')),
      body: tutorsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => RealtimeErrorView(
          error: err,
          onRetry: () => ref.invalidate(tutorsProvider),
        ),
        data: (all) {
          final tutor = all.where((t) => t.id == tutorId).firstOrNull;
          if (tutor == null) {
            return const Center(
              child: Text(
                'المدرس غير موجود',
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }
          return _TutorDetailBody(tutor: tutor);
        },
      ),
    );
  }
}

const _statusLabels = {'active': 'نشط', 'inactive': 'غير نشط'};
const _statusColors = {
  'active': AppColors.success,
  'inactive': AppColors.textMuted,
};

class _TutorDetailBody extends ConsumerWidget {
  const _TutorDetailBody({required this.tutor});

  final Tutor tutor;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmWithPassword(
      context,
      title: 'حذف المدرس نهائيًا',
      message:
          'هيتم حذف "${tutor.name}" نهائيًا من قائمة المدرسين ومش هترجع تاني. اكتب كلمة المرور للتأكيد.',
    );
    if (!confirmed) return;
    await ref.read(tutorsRepositoryProvider).deleteTutor(tutor.id);
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🗑️ تم حذف ${tutor.name} نهائيًا')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    tutor.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tutor.facultyLabel,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final entry in _statusLabels.entries)
                        ChoiceChip(
                          label: Text(entry.value),
                          selected: tutor.status == entry.key,
                          onSelected: (_) => ref
                              .read(tutorsRepositoryProvider)
                              .setTutorStatus(tutor.id, entry.key),
                          selectedColor:
                              (_statusColors[entry.key] ?? AppColors.accent)
                                  .withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: tutor.status == entry.key
                                ? _statusColors[entry.key]
                                : AppColors.textMuted,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          side: BorderSide(
                            color: tutor.status == entry.key
                                ? (_statusColors[entry.key] ?? AppColors.accent)
                                : AppColors.border,
                          ),
                        ),
                      ChoiceChip(
                        label: const Text('⭐ مميز'),
                        selected: tutor.isFeatured,
                        onSelected: (v) => ref
                            .read(tutorsRepositoryProvider)
                            .setTutorFeatured(tutor.id, v),
                        selectedColor: AppColors.accent.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: tutor.isFeatured
                              ? AppColors.accent
                              : AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: tutor.isFeatured
                              ? AppColors.accent
                              : AppColors.border,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'التواصل',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  if (tutor.phonePrimary != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.call_outlined,
                        color: AppColors.accent,
                      ),
                      title: Text(tutor.phonePrimary!),
                      onTap: () => launchTel(tutor.phonePrimary!),
                    ),
                  if (tutor.phoneWhatsapp != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.chat_bubble_outline,
                        color: AppColors.accent,
                      ),
                      title: const Text('واتساب'),
                      onTap: () => launchWhatsapp(tutor.phoneWhatsapp!),
                    ),
                  if (tutor.email != null && tutor.email!.isNotEmpty)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.mail_outline,
                        color: AppColors.accent,
                      ),
                      title: Text(tutor.email!),
                      onTap: () => launchEmail(tutor.email!),
                    ),
                  if (tutor.demoLink != null && tutor.demoLink!.isNotEmpty)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.play_circle_outline,
                        color: AppColors.accent,
                      ),
                      title: const Text('لينك الشرح التجريبي'),
                      onTap: () => launchWebLink(tutor.demoLink!),
                      trailing: IconButton(
                        icon: const Icon(Icons.share_outlined, size: 20),
                        tooltip: 'مشاركة اللينك',
                        onPressed: () => shareLink(tutor.demoLink!),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'المواد',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  SubjectChips(subjects: tutor.subjects),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'سجل الحالة',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Consumer(
                    builder: (context, ref, _) {
                      final historyAsync = ref.watch(
                        tutorStatusHistoryProvider(tutor.id),
                      );
                      return historyAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (err, st) => Text(
                          'حصل خطأ: $err',
                          style: const TextStyle(color: AppColors.error),
                        ),
                        data: (periods) {
                          if (periods.isEmpty) {
                            return const Text(
                              'لا يوجد سجل',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            );
                          }
                          final fmt = DateFormat('d MMM yyyy', 'ar');
                          return Column(
                            children: periods.map((p) {
                              final c =
                                  _statusColors[p.status] ??
                                  AppColors.textMuted;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: c,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _statusLabels[p.status] ?? p.status,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: c,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${fmt.format(p.from)} — ${p.isOngoing ? 'الآن' : fmt.format(p.to!)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الإيرادات والأرباح',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'من الكورسات والحصص الخصوصي — تُستخدم في ترتيب المدرسين',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 10),
                  Consumer(
                    builder: (context, ref, _) {
                      final financeAsync = ref.watch(
                        tutorFinanceSummaryProvider(tutor.id),
                      );
                      return financeAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (err, st) => Text(
                          'حصل خطأ: $err',
                          style: const TextStyle(color: AppColors.error),
                        ),
                        data: (summary) =>
                            _FinanceSummaryView(summary: summary),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _delete(context, ref),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
            ),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('حذف المدرس نهائيًا'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _FinanceSummaryView extends StatelessWidget {
  const _FinanceSummaryView({required this.summary});

  final TutorFinanceSummary summary;

  @override
  Widget build(BuildContext context) {
    if (summary.isEmpty) {
      return const Text(
        'لا توجد بيانات بعد — هتظهر لما تضيف كورسات أو حصص خصوصي لهذا المدرس',
        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
      );
    }
    final profit = summary.profitByCurrency;
    final currencies = {
      ...summary.revenueByCurrency.keys,
      ...summary.paidByCurrency.keys,
    }.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ملحوظة: كل صف عملة منفصل عن التاني (مفيش تحويل عملة) — الرقم اللي تقدر تعتمد عليه فعليًا هو صافي الربح بالريال تحت.',
          style: TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(1.2),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1),
            3: FlexColumnWidth(1),
          },
          children: [
            const TableRow(
              children: [
                _Cell('العملة', bold: true),
                _Cell('الإيرادات', bold: true),
                _Cell('المدفوع للمدرس', bold: true),
                _Cell('الفرق (نفس العملة)', bold: true),
              ],
            ),
            for (final c in currencies)
              TableRow(
                children: [
                  _Cell(c),
                  _Cell(
                    (summary.revenueByCurrency[c] ?? 0).toStringAsFixed(0),
                    color: AppColors.success,
                  ),
                  _Cell(
                    (summary.paidByCurrency[c] ?? 0).toStringAsFixed(0),
                    color: AppColors.error,
                  ),
                  _Cell(
                    (profit[c] ?? 0).toStringAsFixed(0),
                    color: (profit[c] ?? 0) >= 0
                        ? AppColors.success
                        : AppColors.error,
                  ),
                ],
              ),
          ],
        ),
        const Divider(height: 20),
        Row(
          children: [
            const Expanded(
              child: Text(
                'صافي ربح الأكاديمية بالريال (بعد دفع المدرس فعليًا)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${summary.netProfitSar >= 0 ? '+' : ''}${summary.netProfitSar.toStringAsFixed(0)} SAR',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: summary.netProfitSar >= 0
                    ? AppColors.success
                    : AppColors.error,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.text, {this.bold = false, this.color});

  final String text;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          fontSize: 12,
          color: color ?? AppColors.textPrimary,
        ),
      ),
    );
  }
}
