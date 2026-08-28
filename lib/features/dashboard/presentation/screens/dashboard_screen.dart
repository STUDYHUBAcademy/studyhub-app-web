import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/acquisition_source.dart';
import '../../../../core/widgets/realtime_error_view.dart';
import '../../../activity_log/presentation/providers/activity_log_providers.dart';
import '../../../courses/domain/entities/enrollment.dart';
import '../../../courses/domain/entities/tutor_payment.dart';
import '../../../courses/presentation/providers/courses_providers.dart';
import '../../../finance/presentation/providers/finance_providers.dart';
import '../../../sessions/domain/entities/private_session.dart';
import '../../../sessions/presentation/providers/sessions_providers.dart';
import '../../../students/presentation/providers/students_providers.dart';
import '../../../tasks/presentation/providers/tasks_providers.dart';
import '../../../tutors/presentation/providers/tutors_providers.dart';
import '../../../universities/presentation/providers/universities_providers.dart';

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _fmtCurrencyMap(Map<String, double> m) {
  if (m.isEmpty) return '0';
  return m.entries
      .map((e) => '${e.value.toStringAsFixed(0)} ${e.key}')
      .join('، ');
}

/// One line item behind a tutor's total remaining balance — a specific
/// course term or private session, so "how much" always comes with "for what".
class _CostItem {
  const _CostItem({
    required this.label,
    required this.currency,
    required this.remaining,
  });

  final String label;
  final String currency;
  final double remaining;
}

/// One line item behind an unpaid-from-students total — which student, and
/// which course/session it's for.
class _UnpaidItem {
  const _UnpaidItem({
    required this.title,
    required this.subtitle,
    required this.remaining,
  });

  final String title;
  final String subtitle;
  final double remaining;
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(coursesProvider).valueOrNull ?? [];
    final tutors = ref.watch(tutorsProvider).valueOrNull ?? [];
    final applications = ref.watch(applicationsProvider).valueOrNull ?? [];
    final students = ref.watch(studentsProvider).valueOrNull ?? [];
    final sessions = ref.watch(sessionsProvider).valueOrNull ?? [];
    final enrollments = ref.watch(allEnrollmentsProvider).valueOrNull ?? [];
    final enrollmentPayments =
        ref.watch(allEnrollmentPaymentsProvider).valueOrNull ?? [];
    final ledger = ref.watch(allTutorLedgerProvider).valueOrNull ?? [];
    final tasks = ref.watch(tasksProvider).valueOrNull ?? [];
    final courseTerms = ref.watch(allCourseTermsProvider).valueOrNull ?? [];
    final terms = ref.watch(termsProvider).valueOrNull ?? [];
    final expenses = ref.watch(expensesProvider).valueOrNull ?? [];
    final withdrawals = ref.watch(withdrawalsProvider).valueOrNull ?? [];
    final ownerProfiles = ref.watch(ownerProfilesProvider).valueOrNull ?? [];

    final studentById = {for (final s in students) s.id: s};
    final studentSourceCounts = <String, int>{
      'direct': 0,
      'haraj': 0,
      'marketer': 0,
    };
    for (final s in students) {
      studentSourceCounts[s.acquisitionSource] =
          (studentSourceCounts[s.acquisitionSource] ?? 0) + 1;
    }
    final courseById = {for (final c in courses) c.id: c};
    final courseTermById = {for (final ct in courseTerms) ct.id: ct};
    final termById = {for (final t in terms) t.id: t};
    final paidByEnrollment = <String, double>{};
    for (final p in enrollmentPayments) {
      paidByEnrollment[p.enrollmentId] =
          (paidByEnrollment[p.enrollmentId] ?? 0) + p.amount;
    }

    String courseLabelForTerm(String courseTermId) {
      final ct = courseTermById[courseTermId];
      final subject = ct != null ? courseById[ct.courseId]?.subjectName : null;
      final termName = ct != null ? termById[ct.termId]?.name : null;
      return [subject, termName].whereType<String>().join(' — ');
    }

    // A cancelled enrollment counts for nothing — any money already
    // collected on it is treated as refunded once the enrollment is
    // cancelled, so it drops out of revenue/commission/tutor cost entirely.
    double effectiveEnrollmentAmount(Enrollment e) {
      if (e.status == 'cancelled') return 0;
      return e.effectiveAmount;
    }

    // Cash actually in hand for this enrollment — never more than what's
    // contracted (a stray overpayment shouldn't inflate revenue).
    double cashCollected(Enrollment e) {
      final contracted = effectiveEnrollmentAmount(e);
      final paid = paidByEnrollment[e.id] ?? 0;
      return paid < contracted ? paid : contracted;
    }

    // Revenue — money actually collected, not the full contracted amount.
    // Net profit/sadaqah/owner split are all derived from this, and you
    // can't distribute or tithe on money that hasn't come in yet.
    final revenue = <String, double>{};
    for (final e in enrollments) {
      revenue[e.currency] = (revenue[e.currency] ?? 0) + cashCollected(e);
    }
    for (final s in sessions) {
      if (s.status == 'cancelled' || s.studentTotal == null) continue;
      final received = s.studentPaid
          ? (s.studentAmountReceived ?? s.effectiveTotal)
          : 0.0;
      revenue[s.studentTotalCurrency] =
          (revenue[s.studentTotalCurrency] ?? 0) + received;
    }

    var tutorPaidSar = 0.0;
    final tutorPaidByCurrency = <String, double>{};
    for (final l in ledger) {
      tutorPaidByCurrency[l.currency] =
          (tutorPaidByCurrency[l.currency] ?? 0) + l.amount;
      tutorPaidSar += l.currency == 'SAR'
          ? l.amount
          : (l.equivalentSarAmount ?? 0);
    }

    // Money not collected yet + commission owed to Haraj/marketers — scoped
    // to SAR since that's the currency students actually pay in, matching
    // how the rest of the dashboard treats SAR as the trustworthy bottom line.
    var unpaidCoursesSar = 0.0;
    var commissionSar = 0.0;
    var harajCommissionSar = 0.0;
    final marketerCommissionSar = <String, double>{};
    final unpaidCourseItems = <_UnpaidItem>[];

    void addCommission(ResolvedSource resolved, double base) {
      // No cash collected yet on this deal means no commission is owed on
      // it yet either — matches revenue being cash-basis above.
      if (base <= 0) return;
      double amount;
      if (resolved.source == 'marketer') {
        // Marketer commission is a flat negotiated amount, not a cut of
        // this specific transaction — unlike haraj's percentage.
        final flat = resolved.commissionAmount;
        if (flat == null || flat <= 0) return;
        amount = flat;
      } else {
        final pct = resolved.commissionPct;
        if (pct == null || pct <= 0) return;
        amount = base * pct / 100;
      }
      commissionSar += amount;
      if (resolved.source == 'haraj') {
        harajCommissionSar += amount;
      } else if (resolved.source == 'marketer') {
        final name = resolved.marketerName?.trim().isNotEmpty == true
            ? resolved.marketerName!.trim()
            : 'مسوق بدون اسم';
        marketerCommissionSar[name] =
            (marketerCommissionSar[name] ?? 0) + amount;
      }
    }

    for (final e in enrollments) {
      if (e.currency != 'SAR') continue;
      final paidSoFar = paidByEnrollment[e.id] ?? 0;
      final effectiveAmount = effectiveEnrollmentAmount(e);
      final remaining = effectiveAmount - paidSoFar;
      if (remaining > 0.01) {
        unpaidCoursesSar += remaining;
        unpaidCourseItems.add(
          _UnpaidItem(
            title: studentById[e.studentId]?.name ?? '؟',
            subtitle: courseLabelForTerm(e.courseTermId),
            remaining: remaining,
          ),
        );
      }
      final student = studentById[e.studentId];
      addCommission(
        resolveAcquisitionSource(
          overrideSource: e.acquisitionSource,
          overrideMarketerName: e.marketerName,
          overrideCommissionPct: e.commissionPct,
          overrideCommissionAmount: e.commissionAmount,
          studentSource: student?.acquisitionSource,
          studentMarketerName: student?.marketerName,
          studentCommissionPct: student?.commissionPct,
          studentCommissionAmount: student?.commissionAmount,
        ),
        cashCollected(e),
      );
    }
    var unpaidSessionsSar = 0.0;
    final unpaidSessionItems = <_UnpaidItem>[];
    for (final s in sessions) {
      if (s.status == 'cancelled' || s.studentTotalCurrency != 'SAR') {
        continue;
      }
      final total = s.effectiveTotal;
      final received = s.studentPaid ? (s.studentAmountReceived ?? total) : 0.0;
      final remaining = total - received;
      if (remaining > 0.01) {
        unpaidSessionsSar += remaining;
        unpaidSessionItems.add(
          _UnpaidItem(
            title: s.studentId != null
                ? (studentById[s.studentId]?.name ?? '؟')
                : '؟',
            subtitle: s.scheduledAt != null
                ? '${s.subject} — ${intl.DateFormat('d MMM', 'ar').format(s.scheduledAt!)}'
                : s.subject,
            remaining: remaining,
          ),
        );
      }
      if (s.studentId != null && received > 0) {
        final student = studentById[s.studentId];
        addCommission(
          resolveAcquisitionSource(
            overrideSource: s.acquisitionSource,
            overrideMarketerName: s.marketerName,
            overrideCommissionPct: s.commissionPct,
            overrideCommissionAmount: s.commissionAmount,
            studentSource: student?.acquisitionSource,
            studentMarketerName: student?.marketerName,
            studentCommissionPct: student?.commissionPct,
            studentCommissionAmount: student?.commissionAmount,
          ),
          received,
        );
      }
    }

    var expensesSar = 0.0;
    for (final e in expenses) {
      if (e.currency == 'SAR') expensesSar += e.amount;
    }

    // How money actually comes in, by payment method — actual installments
    // received on courses plus what's been collected on private sessions.
    final paymentMethodSar = <String, double>{};
    for (final p in enrollmentPayments) {
      if (p.currency != 'SAR') continue;
      paymentMethodSar[p.paymentMethod] =
          (paymentMethodSar[p.paymentMethod] ?? 0) + p.amount;
    }
    for (final s in sessions) {
      if (s.status == 'cancelled' || s.studentTotalCurrency != 'SAR') {
        continue;
      }
      final total = s.effectiveTotal;
      final received = s.studentPaid ? (s.studentAmountReceived ?? total) : 0;
      if (received > 0) {
        paymentMethodSar[s.paymentMethod] =
            (paymentMethodSar[s.paymentMethod] ?? 0) + received;
      }
    }

    final revenueSar = revenue['SAR'] ?? 0;
    final netProfitSar =
        revenueSar - tutorPaidSar - commissionSar - expensesSar;
    final sadaqah = netProfitSar > 0 ? netProfitSar * 0.01 : 0.0;
    final distributable = netProfitSar - sadaqah;

    final withdrawalsByOwner = <String, double>{};
    for (final w in withdrawals) {
      if (w.currency != 'SAR') continue;
      withdrawalsByOwner[w.profileId] =
          (withdrawalsByOwner[w.profileId] ?? 0) + w.amount;
    }
    final ownerNames = {for (final o in ownerProfiles) o.id: o.name};

    // What's still owed to each tutor: their contracted cost (flat fee or
    // revshare cut of actual enrollments, plus non-cancelled private-session
    // payouts) minus what's actually been paid out via the ledger so far.
    // Ledger entries linked to a specific course term / session are
    // attributed to that item; unlinked ("general") payments are shown
    // separately since we can't know which item they were meant to cover.
    final tutorCost = <String, Map<String, double>>{};
    final tutorItems = <String, List<_CostItem>>{};
    void addCost(
      String tutorId,
      String currency,
      double amount, {
      String? label,
      double linkedPaid = 0,
    }) {
      final inner = tutorCost.putIfAbsent(tutorId, () => {});
      inner[currency] = (inner[currency] ?? 0) + amount;
      if (label != null) {
        final rem = amount - linkedPaid;
        if (rem > 0.01) {
          tutorItems
              .putIfAbsent(tutorId, () => [])
              .add(_CostItem(label: label, currency: currency, remaining: rem));
        }
      }
    }

    final linkedPaidByCourseTerm = <String, double>{};
    final linkedPaidBySession = <String, double>{};
    final tutorGeneralPaid = <String, Map<String, double>>{};
    for (final l in ledger) {
      if (l.courseTermId != null) {
        final key = '${l.courseTermId}|${l.currency}';
        linkedPaidByCourseTerm[key] =
            (linkedPaidByCourseTerm[key] ?? 0) + l.amount;
      } else if (l.privateSessionId != null) {
        linkedPaidBySession[l.privateSessionId!] =
            (linkedPaidBySession[l.privateSessionId!] ?? 0) + l.amount;
      } else {
        final inner = tutorGeneralPaid.putIfAbsent(l.tutorId, () => {});
        inner[l.currency] = (inner[l.currency] ?? 0) + l.amount;
      }
    }

    for (final ct in courseTerms) {
      final tutorId = courseById[ct.courseId]?.tutorId;
      if (tutorId == null) continue;
      final label = courseLabelForTerm(ct.id);
      if (ct.pricingModel == 'flat') {
        if (ct.tutorFlatFee != null) {
          addCost(
            tutorId,
            ct.tutorFlatFeeCurrency,
            ct.tutorFlatFee!,
            label: label,
            linkedPaid:
                linkedPaidByCourseTerm['${ct.id}|${ct.tutorFlatFeeCurrency}'] ??
                0,
          );
        }
      } else {
        // Revshare owed to the tutor is their cut of money actually
        // collected from students, not the full contracted price — you
        // can't split revenue that hasn't come in yet.
        final byCurrency = <String, double>{};
        for (final e in enrollments.where((e) => e.courseTermId == ct.id)) {
          byCurrency[e.currency] =
              (byCurrency[e.currency] ?? 0) + cashCollected(e);
        }
        byCurrency.forEach((currency, amount) {
          addCost(
            tutorId,
            currency,
            amount * ct.revsharePct / 100,
            label: label,
            linkedPaid: linkedPaidByCourseTerm['${ct.id}|$currency'] ?? 0,
          );
        });
      }
    }
    for (final s in sessions) {
      if (s.status == 'cancelled') continue;
      final tutorId = s.tutorId;
      final payout = s.tutorPayout;
      if (tutorId == null || payout == null) continue;
      final label = s.scheduledAt != null
          ? '${s.subject} — ${intl.DateFormat('d MMM', 'ar').format(s.scheduledAt!)}'
          : s.subject;
      addCost(
        tutorId,
        s.tutorPayoutCurrency,
        payout,
        label: label,
        linkedPaid: linkedPaidBySession[s.id] ?? 0,
      );
    }

    final tutorPaidMap = <String, Map<String, double>>{};
    for (final l in ledger) {
      final inner = tutorPaidMap.putIfAbsent(l.tutorId, () => {});
      inner[l.currency] = (inner[l.currency] ?? 0) + l.amount;
    }

    final tutorRemaining = <String, Map<String, double>>{};
    tutorCost.forEach((tutorId, costMap) {
      final paidMap = tutorPaidMap[tutorId] ?? {};
      final remMap = <String, double>{};
      costMap.forEach((currency, cost) {
        final rem = cost - (paidMap[currency] ?? 0);
        if (rem > 0.01) remMap[currency] = rem;
      });
      if (remMap.isNotEmpty) tutorRemaining[tutorId] = remMap;
    });
    final totalTutorRemaining = <String, double>{};
    tutorRemaining.forEach((_, m) {
      m.forEach(
        (c, a) => totalTutorRemaining[c] = (totalTutorRemaining[c] ?? 0) + a,
      );
    });

    final activeCourses = courses.where((c) => c.status == 'active').length;
    final activeTutors = tutors.where((t) => t.status == 'active').length;
    final pendingApplications = applications
        .where((a) => a.status == 'new')
        .length;
    final pendingPayments = enrollments
        .where((e) => e.status != 'cancelled' && e.paymentStatus != 'paid')
        .length;
    final overduePayments = enrollments
        .where((e) => e.status != 'cancelled' && e.paymentStatus == 'overdue')
        .length;
    final unpaidSessionsCount = sessions
        .where((s) => s.status != 'cancelled' && !s.studentPaid)
        .length;
    final openTasks = tasks.where((t) => t.status == 'open').toList();
    final overdueTasks = openTasks
        .where((t) => t.dueDate != null && t.dueDate!.isBefore(DateTime.now()))
        .length;

    final now = DateTime.now();
    final todaySessionsCount = sessions
        .where(
          (s) =>
              s.status == 'scheduled' &&
              s.scheduledAt != null &&
              _isSameDay(s.scheduledAt!, now),
        )
        .length;
    final upcomingSessions =
        sessions
            .where(
              (s) =>
                  s.status == 'scheduled' &&
                  s.scheduledAt != null &&
                  s.scheduledAt!.isAfter(now),
            )
            .toList()
          ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));

    final tutorNames = {for (final t in tutors) t.id: t.name};

    // Non-SAR tutor payments with no SAR equivalent recorded silently drop
    // out of every SAR-based calculation on this dashboard (net profit,
    // sadaqah, owner split...) — this is urgent, not just informational.
    final missingSarEquivalent = ledger
        .where((l) => l.currency != 'SAR' && l.equivalentSarAmount == null)
        .toList();

    // A course still in planning with no demo link means the tutor hasn't
    // sent a trial lesson yet — surface it so it doesn't get forgotten.
    final coursesMissingDemo = courses
        .where(
          (c) =>
              c.status == 'planning' &&
              (c.demoLink == null || c.demoLink!.isEmpty),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 الرئيسية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'آخر التحديثات',
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: AppColors.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (context) => const _ActivityLogSheet(),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (coursesMissingDemo.isNotEmpty) ...[
            Card(
              color: AppColors.info.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.info, width: 1),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.push('/courses'),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.movie_creation_outlined,
                        color: AppColors.info,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'منتظر إضافة تجريبي: ${coursesMissingDemo.length} كورس',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: AppColors.info,
                              ),
                            ),
                            Text(
                              coursesMissingDemo
                                  .map((c) => c.subjectName)
                                  .join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_left_rounded,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (missingSarEquivalent.isNotEmpty) ...[
            Card(
              color: AppColors.error.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.error, width: 1),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: AppColors.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder: (context) =>
                      _MissingSarEquivalentSheet(tutorNames: tutorNames),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'مهمة عاجلة: ${missingSarEquivalent.length} دفعة للمدرسين بدون معادل بالريال',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: AppColors.error,
                              ),
                            ),
                            const Text(
                              'ده بيأثر على صافي الربح ونصيب رب العالمين وتوزيع الشركاء — اضغط للتحديد',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_left_rounded,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  label: 'صافي الربح (SAR)',
                  value:
                      '${netProfitSar >= 0 ? '+' : ''}${netProfitSar.toStringAsFixed(0)}',
                  color: netProfitSar >= 0
                      ? AppColors.success
                      : AppColors.error,
                  icon: Icons.trending_up_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiCard(
                  label: 'الإيرادات (SAR)',
                  value: revenueSar.toStringAsFixed(0),
                  color: AppColors.info,
                  icon: Icons.payments_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _KpiCard(
                label: 'الكورسات النشطة',
                value: '$activeCourses',
                color: AppColors.accent,
                icon: Icons.menu_book_rounded,
                onTap: () => context.go('/courses'),
              ),
              _KpiCard(
                label: 'المدرسين ($activeTutors نشط)',
                value: '${tutors.length}',
                color: AppColors.accent,
                icon: Icons.groups_rounded,
                onTap: () => context.go('/tutors'),
              ),
              _KpiCard(
                label: 'حصص فردية اليوم',
                value: '$todaySessionsCount',
                color: AppColors.accent,
                icon: Icons.today_rounded,
                onTap: () => context.go('/sessions'),
              ),
              _KpiCard(
                label: 'مهام مفتوحة',
                value: '${openTasks.length}',
                color: AppColors.accent,
                icon: Icons.checklist_rounded,
                onTap: () => context.push('/tasks'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'التقرير المالي (SAR)',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _MoneyRow(label: 'الإيرادات', value: revenueSar),
                  _MoneyRow(
                    label: 'مدفوع للمدرسين (ما يعادل SAR)',
                    value: -tutorPaidSar,
                  ),
                  _MoneyRow(
                    label: 'عمولات مستحقة (حراج / مسوقين)',
                    value: -commissionSar,
                  ),
                  _MoneyRow(label: 'مصروفات الأكاديمية', value: -expensesSar),
                  const Divider(height: 20),
                  _MoneyRow(
                    label: 'صافي الربح',
                    value: netProfitSar,
                    bold: true,
                  ),
                  _MoneyRow(
                    label: 'نصيب رب العالمين (1%)',
                    value: -sadaqah,
                    color: AppColors.info,
                  ),
                  const Divider(height: 20),
                  _MoneyRow(
                    label: 'الموزع بين الشريكين',
                    value: distributable,
                    color: AppColors.success,
                    bold: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _ChartsSection(
            financialItems: [
              (label: 'الإيرادات', value: revenueSar, color: AppColors.info),
              (
                label: 'المدرسين',
                value: tutorPaidSar,
                color: AppColors.warning,
              ),
              (
                label: 'العمولات',
                value: commissionSar,
                color: AppColors.accent,
              ),
              (label: 'المصروفات', value: expensesSar, color: AppColors.error),
              (
                label: 'صافي الربح',
                value: netProfitSar,
                color: AppColors.success,
              ),
            ],
            studentSourceCounts: studentSourceCounts,
            paymentMethodSar: paymentMethodSar,
          ),
          if (harajCommissionSar > 0.01 ||
              marketerCommissionSar.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'تفصيل العمولات (SAR)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    if (harajCommissionSar > 0.01)
                      _MoneyRow(
                        label: 'حراج',
                        value: harajCommissionSar,
                        color: AppColors.warning,
                      ),
                    for (final entry in marketerCommissionSar.entries)
                      _MoneyRow(
                        label: entry.key,
                        value: entry.value,
                        color: AppColors.warning,
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (withdrawalsByOwner.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'مسحوبات الشركاء قبل نهاية الترم',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    for (final entry in withdrawalsByOwner.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                ownerNames[entry.key] ?? '؟',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                            Text(
                              '${entry.value.toStringAsFixed(0)} SAR',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            'المتبقي للمدرسين',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: AppColors.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) => _TutorsRemainingSheet(
                  remaining: tutorRemaining,
                  tutorNames: tutorNames,
                  items: tutorItems,
                  generalPaid: tutorGeneralPaid,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 20,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'إجمالي المتبقي',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                          Text(
                            totalTutorRemaining.isEmpty
                                ? 'مفيش حاجة متأخرة'
                                : _fmtCurrencyMap(totalTutorRemaining),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_left_rounded,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'مبالغ لسه ما اتحصلتش (SAR)',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  label: 'من الكورسات',
                  value: unpaidCoursesSar.toStringAsFixed(0),
                  color: AppColors.warning,
                  icon: Icons.menu_book_rounded,
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: AppColors.surface,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    builder: (context) => _UnpaidItemsSheet(
                      title: 'مبالغ لسه ما اتحصلتش من الكورسات',
                      items: unpaidCourseItems,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiCard(
                  label: 'من الحصص الفردية',
                  value: unpaidSessionsSar.toStringAsFixed(0),
                  color: AppColors.warning,
                  icon: Icons.event_note_rounded,
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: AppColors.surface,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    builder: (context) => _UnpaidItemsSheet(
                      title: 'مبالغ لسه ما اتحصلتش من الحصص الفردية',
                      items: unpaidSessionItems,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (pendingApplications > 0 ||
              pendingPayments > 0 ||
              unpaidSessionsCount > 0 ||
              overdueTasks > 0) ...[
            const SizedBox(height: 20),
            const Text(
              'تنبيهات مهمة',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            if (pendingApplications > 0)
              _AlertRow(
                icon: Icons.person_add_alt_1_rounded,
                text:
                    'في انتظار مراجعة $pendingApplications طلب تقديم مدرس جديد',
                onTap: () => context.go('/tutors'),
              ),
            if (pendingPayments > 0)
              _AlertRow(
                icon: Icons.receipt_long_rounded,
                text:
                    '$pendingPayments دفعة طالب لسه معلقة${overduePayments > 0 ? ' ($overduePayments متأخرة)' : ''}',
                onTap: () => context.go('/courses'),
                color: overduePayments > 0 ? AppColors.error : null,
              ),
            if (unpaidSessionsCount > 0)
              _AlertRow(
                icon: Icons.event_busy_rounded,
                text: '$unpaidSessionsCount حصة فردية لسه مالهاش تحصيل',
                onTap: () => context.go('/sessions'),
              ),
            if (overdueTasks > 0)
              _AlertRow(
                icon: Icons.assignment_late_rounded,
                text: '$overdueTasks مهمة متأخرة عن موعدها',
                onTap: () => context.push('/tasks'),
                color: AppColors.error,
              ),
          ],
          const SizedBox(height: 20),
          const Text(
            'الحصص القادمة',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          if (upcomingSessions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'مفيش حصص فردية مجدولة قدام',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            )
          else
            ...upcomingSessions
                .take(5)
                .map(
                  (s) => _UpcomingSessionTile(
                    session: s,
                    tutorName: tutorNames[s.tutorId],
                  ),
                ),
        ],
      ),
    );
  }
}

class _TutorsRemainingSheet extends StatelessWidget {
  const _TutorsRemainingSheet({
    required this.remaining,
    required this.tutorNames,
    required this.items,
    required this.generalPaid,
  });

  final Map<String, Map<String, double>> remaining;
  final Map<String, String> tutorNames;
  final Map<String, List<_CostItem>> items;
  final Map<String, Map<String, double>> generalPaid;

  @override
  Widget build(BuildContext context) {
    final entries = remaining.entries.toList()
      ..sort(
        (a, b) => (tutorNames[a.key] ?? '').compareTo(tutorNames[b.key] ?? ''),
      );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'المتبقي للمدرسين',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const Text(
              'اضغط على اسم المدرس عشان تشوف تفاصيل المبلغ',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'كل المدرسين مستلمين مستحقاتهم',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  separatorBuilder: (context, i) => const Divider(height: 4),
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    final tutorItems = items[e.key] ?? [];
                    final general = generalPaid[e.key] ?? {};
                    return ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 8),
                      title: Text(
                        tutorNames[e.key] ?? '؟',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        _fmtCurrencyMap(e.value),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.warning,
                        ),
                      ),
                      children: [
                        for (final it in tutorItems)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    it.label,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${it.remaining.toStringAsFixed(0)} ${it.currency}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (general.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'دفعات مسجلة بدون ربط ببند معين (متخصمة من الإجمالي)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                                Text(
                                  '- ${_fmtCurrencyMap(general)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (tutorItems.isEmpty && general.isEmpty)
                          const Text(
                            'مفيش تفاصيل إضافية',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
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

class _UnpaidItemsSheet extends StatelessWidget {
  const _UnpaidItemsSheet({required this.title, required this.items});

  final String title;
  final List<_UnpaidItem> items;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'مفيش حاجة متأخرة',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (context, i) => const Divider(height: 16),
                  itemBuilder: (context, i) {
                    final it = items[i];
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                it.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              if (it.subtitle.isNotEmpty)
                                Text(
                                  it.subtitle,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '${it.remaining.toStringAsFixed(0)} SAR',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.warning,
                          ),
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

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.value,
    this.color,
    this.bold = false,
  });

  final String label;
  final double value;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        color ?? (value < 0 ? AppColors.error : AppColors.textPrimary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: bold ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ),
          Text(
            '${value >= 0 ? '' : '-'}${value.abs().toStringAsFixed(0)} SAR',
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              color: resolvedColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({
    required this.icon,
    required this.text,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.warning;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: c),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
              const Icon(
                Icons.chevron_left_rounded,
                size: 18,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingSessionTile extends StatelessWidget {
  const _UpcomingSessionTile({required this.session, this.tutorName});

  final PrivateSession session;
  final String? tutorName;

  @override
  Widget build(BuildContext context) {
    final scheduledAt = session.scheduledAt!;
    final date = intl.DateFormat('d MMMM', 'ar').format(scheduledAt);
    final time = intl.DateFormat('h:mm a', 'ar').format(scheduledAt);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.event_note_rounded,
              size: 18,
              color: AppColors.info,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.subject,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  if (tutorName != null)
                    Text(
                      tutorName!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              '$date\n$time',
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _ChartItem = ({String label, double value, Color color});

/// All dashboard charts are hidden by default behind one toggle — the
/// numbers above already tell the story, charts are opt-in extra detail.
class _ChartsSection extends StatefulWidget {
  const _ChartsSection({
    required this.financialItems,
    required this.studentSourceCounts,
    required this.paymentMethodSar,
  });

  final List<_ChartItem> financialItems;
  final Map<String, int> studentSourceCounts;
  final Map<String, double> paymentMethodSar;

  @override
  State<_ChartsSection> createState() => _ChartsSectionState();
}

class _ChartsSectionState extends State<_ChartsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: () => setState(() => _expanded = !_expanded),
          icon: Icon(
            _expanded ? Icons.expand_less_rounded : Icons.bar_chart_rounded,
            size: 18,
          ),
          label: Text(
            _expanded ? 'إخفاء الرسومات البيانية' : 'عرض الرسومات البيانية',
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 12),
          const Text(
            'الأداء المالي',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _FinancialBarChart(items: widget.financialItems),
            ),
          ),
          if (widget.studentSourceCounts.values.any((c) => c > 0)) ...[
            const SizedBox(height: 16),
            const Text(
              'مصادر الطلاب',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _StudentSourceDonut(counts: widget.studentSourceCounts),
              ),
            ),
          ],
          if (widget.paymentMethodSar.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'وسائل الدفع (SAR)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _PaymentMethodDonut(totals: widget.paymentMethodSar),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _FinancialBarChart extends StatelessWidget {
  const _FinancialBarChart({required this.items});

  final List<_ChartItem> items;

  @override
  Widget build(BuildContext context) {
    final maxVal = items
        .map((e) => e.value.abs())
        .fold<double>(0, (a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 150,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxVal <= 0 ? 1 : maxVal * 1.2,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(show: false),
              barTouchData: BarTouchData(enabled: false),
              barGroups: [
                for (var i = 0; i < items.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: items[i].value.abs(),
                        color: items[i].color,
                        width: 22,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (final it in items)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: it.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${it.label} (${it.value.toStringAsFixed(0)})',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

const _studentSourceLabels = {
  'direct': 'مباشر',
  'haraj': 'حراج',
  'marketer': 'مسوق',
};
const _studentSourceColors = {
  'direct': AppColors.info,
  'haraj': AppColors.accent,
  'marketer': AppColors.success,
};

class _StudentSourceDonut extends StatelessWidget {
  const _StudentSourceDonut({required this.counts});

  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    return Row(
      children: [
        SizedBox(
          height: 120,
          width: 120,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 32,
              sections: [
                for (final entry in counts.entries)
                  if (entry.value > 0)
                    PieChartSectionData(
                      value: entry.value.toDouble(),
                      color: _studentSourceColors[entry.key],
                      title: '${entry.value}',
                      radius: 26,
                      titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.background,
                      ),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in counts.entries)
                if (entry.value > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _studentSourceColors[entry.key],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_studentSourceLabels[entry.key] ?? entry.key} — ${entry.value}'
                          '${total > 0 ? ' (${(entry.value / total * 100).toStringAsFixed(0)}%)' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

const _paymentMethodChartLabels = {
  'cash': '💵 كاش',
  'visa': '💳 فيزا',
  'tabby': '🟣 تابي',
  'tamara': '🟢 تمارا',
};
const _paymentMethodChartColors = {
  'cash': AppColors.success,
  'visa': AppColors.info,
  'tabby': AppColors.accent,
  'tamara': AppColors.warning,
};

class _PaymentMethodDonut extends StatelessWidget {
  const _PaymentMethodDonut({required this.totals});

  final Map<String, double> totals;

  @override
  Widget build(BuildContext context) {
    final total = totals.values.fold<double>(0, (a, b) => a + b);
    return Row(
      children: [
        SizedBox(
          height: 120,
          width: 120,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 32,
              sections: [
                for (final entry in totals.entries)
                  if (entry.value > 0)
                    PieChartSectionData(
                      value: entry.value,
                      color:
                          _paymentMethodChartColors[entry.key] ??
                          AppColors.textMuted,
                      title: entry.value.toStringAsFixed(0),
                      radius: 26,
                      titleStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.background,
                      ),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in totals.entries)
                if (entry.value > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color:
                                _paymentMethodChartColors[entry.key] ??
                                AppColors.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_paymentMethodChartLabels[entry.key] ?? entry.key} — ${entry.value.toStringAsFixed(0)}'
                          '${total > 0 ? ' (${(entry.value / total * 100).toStringAsFixed(0)}%)' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MissingSarEquivalentSheet extends ConsumerWidget {
  const _MissingSarEquivalentSheet({required this.tutorNames});

  final Map<String, String> tutorNames;

  Future<void> _fix(BuildContext context, WidgetRef ref, TutorPayment p) async {
    final controller = TextEditingController();
    String? formError;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('تحديد المعادل بالريال'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${tutorNames[p.tutorId] ?? '؟'} — ${p.amount.toStringAsFixed(0)} ${p.currency}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'المعادل بالريال (SAR)',
                ),
              ),
              if (formError != null) ...[
                const SizedBox(height: 8),
                Text(
                  formError!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (double.tryParse(controller.text.trim()) == null) {
                  setState(() => formError = 'اكتب مبلغ صحيح');
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
    final value = double.tryParse(controller.text.trim());
    if (value == null) return;
    await ref
        .read(coursesRepositoryProvider)
        .updateTutorPayment(
          id: p.id,
          amount: p.amount,
          currency: p.currency,
          equivalentSarAmount: value,
          notes: p.notes,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(allTutorLedgerProvider).valueOrNull ?? [];
    final payments = ledger
        .where((l) => l.currency != 'SAR' && l.equivalentSarAmount == null)
        .toList();

    if (payments.isEmpty) {
      // The last entry just got fixed while this sheet was open — close it
      // automatically instead of leaving an empty urgent-task sheet behind.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'دفعات محتاجة معادل بالريال',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: payments.length,
                separatorBuilder: (context, i) => const Divider(height: 16),
                itemBuilder: (context, i) {
                  final p = payments[i];
                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tutorNames[p.tutorId] ?? '؟',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${p.amount.toStringAsFixed(0)} ${p.currency} • ${intl.DateFormat('d MMM yyyy', 'ar').format(p.date)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _fix(context, ref, p),
                        child: const Text('تحديد'),
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

class _ActivityLogSheet extends ConsumerWidget {
  const _ActivityLogSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(activityLogProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'آخر التحديثات',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: entriesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, st) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: RealtimeErrorView(
                    error: err,
                    onRetry: () => ref.invalidate(activityLogProvider),
                  ),
                ),
                data: (entries) {
                  if (entries.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'مفيش تحديثات لسه',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    separatorBuilder: (context, i) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final entry = entries[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.message,
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              intl.DateFormat(
                                'd MMM yyyy — h:mm a',
                                'ar',
                              ).format(entry.createdAt),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
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
        ),
      ),
    );
  }
}
