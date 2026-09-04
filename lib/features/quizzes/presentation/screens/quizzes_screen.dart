import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/contact_links.dart';
import '../../../../core/utils/reauth.dart';
import '../../../../core/widgets/realtime_error_view.dart';
import '../../../universities/domain/entities/term.dart';
import '../../../universities/presentation/providers/universities_providers.dart';
import '../../domain/entities/quiz.dart';
import '../../domain/entities/quiz_attempt.dart';
import '../../quiz_link.dart';
import '../providers/quizzes_providers.dart';
import '../widgets/term_picker.dart';
import 'create_quiz_screen.dart';

class QuizzesScreen extends ConsumerWidget {
  const QuizzesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizzesAsync = ref.watch(quizzesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('📝 الاختبارات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const CreateQuizScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('اختبار جديد'),
      ),
      body: quizzesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => RealtimeErrorView(
          error: err,
          onRetry: () => ref.invalidate(quizzesProvider),
        ),
        data: (quizzes) {
          if (quizzes.isEmpty) {
            return const Center(
              child: Text(
                'لسه مفيش اختبارات مضافة',
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: quizzes.length,
            itemBuilder: (context, i) => _QuizCard(quiz: quizzes[i]),
          );
        },
      ),
    );
  }
}

class _QuizCard extends ConsumerWidget {
  const _QuizCard({required this.quiz});

  final Quiz quiz;

  void _showAttempts(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AttemptsSheet(quiz: quiz),
    );
  }

  Future<void> _copyLink(BuildContext context, WidgetRef ref) async {
    final termId = await pickShareTerm(context, ref);
    if (!context.mounted) return;
    Clipboard.setData(
      ClipboardData(text: quizLinkFor(quiz.id, termId: termId)),
    );
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('اتنسخ اللينك')));
  }

  Future<void> _shareLink(BuildContext context, WidgetRef ref) async {
    final termId = await pickShareTerm(context, ref);
    if (!context.mounted) return;
    shareLink(quizLinkFor(quiz.id, termId: termId));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmWithPassword(
      context,
      title: 'حذف الاختبار نهائيًا',
      message:
          'هيتم حذف "${quiz.title}" وكل محاولات الطلاب المسجلة عليه نهائيًا — الأسئلة والنتايج كلها هتضيع. اكتب كلمة المرور للتأكيد.',
    );
    if (!confirmed) return;
    await ref.read(quizzesRepositoryProvider).deleteQuiz(quiz.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attempts = ref.watch(quizAttemptsProvider(quiz.id)).valueOrNull;
    final count = attempts?.length ?? 0;
    final avg = (attempts == null || attempts.isEmpty)
        ? null
        : attempts.fold<double>(0, (sum, a) => sum + a.scorePct) /
              attempts.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showAttempts(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      quiz.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (!quiz.isPublished)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Text(
                        'موقّف',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 15,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$count محاولة',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (avg != null) ...[
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.percent_rounded,
                      size: 15,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'متوسط ${avg.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _shareLink(context, ref),
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: const Text(
                      'مشاركة اللينك',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _copyLink(context, ref),
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    label: const Text('نسخ', style: TextStyle(fontSize: 12)),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                    tooltip: 'حذف الاختبار',
                    onPressed: () => _delete(context, ref),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttemptsSheet extends ConsumerStatefulWidget {
  const _AttemptsSheet({required this.quiz});

  final Quiz quiz;

  @override
  ConsumerState<_AttemptsSheet> createState() => _AttemptsSheetState();
}

class _AttemptsSheetState extends ConsumerState<_AttemptsSheet> {
  Term? _selectedTerm;

  @override
  Widget build(BuildContext context) {
    final attemptsAsync = ref.watch(quizAttemptsProvider(widget.quiz.id));
    final terms = ref.watch(termsProvider).valueOrNull ?? [];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.quiz.title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            if (terms.isNotEmpty) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<Term?>(
                initialValue: _selectedTerm,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'فلترة حسب الفصل الدراسي',
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('كل الفصول الدراسية'),
                  ),
                  ...terms.map(
                    (t) => DropdownMenuItem(value: t, child: Text(t.name)),
                  ),
                ],
                onChanged: (v) => setState(() => _selectedTerm = v),
              ),
            ],
            const SizedBox(height: 12),
            Flexible(
              child: attemptsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, st) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: RealtimeErrorView(
                    error: err,
                    onRetry: () =>
                        ref.invalidate(quizAttemptsProvider(widget.quiz.id)),
                  ),
                ),
                data: (allAttempts) {
                  final term = _selectedTerm;
                  final attempts = term == null
                      ? allAttempts
                      : allAttempts.where((a) => a.termId == term.id).toList();
                  if (attempts.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        term == null
                            ? 'لسه محدش عمل الاختبار ده'
                            : 'لا توجد محاولات في هذا الفصل الدراسي',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: attempts.length,
                    separatorBuilder: (context, i) => const Divider(height: 16),
                    itemBuilder: (context, i) =>
                        _AttemptRow(attempt: attempts[i]),
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

class _AttemptRow extends StatelessWidget {
  const _AttemptRow({required this.attempt});

  final QuizAttempt attempt;

  Color get _scoreColor {
    if (attempt.scorePct >= 85) return AppColors.success;
    if (attempt.scorePct >= 50) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                attempt.studentName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Text(
                [
                  ?attempt.studentPhone,
                  intl.DateFormat(
                    'd MMM yyyy — h:mm a',
                    'ar',
                  ).format(attempt.createdAt),
                ].join(' • '),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        Text(
          '${attempt.correctCount}/${attempt.totalQuestions} (${attempt.scorePct.toStringAsFixed(0)}%)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: _scoreColor,
          ),
        ),
      ],
    );
  }
}
