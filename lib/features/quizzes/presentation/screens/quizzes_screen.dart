import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/contact_links.dart';
import '../../../../core/widgets/realtime_error_view.dart';
import '../../domain/entities/quiz.dart';
import '../../domain/entities/quiz_attempt.dart';
import '../../quiz_link.dart';
import '../providers/quizzes_providers.dart';
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

  void _copyLink(BuildContext context) {
    Clipboard.setData(ClipboardData(text: quizLinkFor(quiz.id)));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('اتنسخ اللينك')));
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
                    onPressed: () => shareLink(quizLinkFor(quiz.id)),
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: const Text(
                      'مشاركة اللينك',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _copyLink(context),
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    label: const Text('نسخ', style: TextStyle(fontSize: 12)),
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

class _AttemptsSheet extends ConsumerWidget {
  const _AttemptsSheet({required this.quiz});

  final Quiz quiz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attemptsAsync = ref.watch(quizAttemptsProvider(quiz.id));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              quiz.title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
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
                        ref.invalidate(quizAttemptsProvider(quiz.id)),
                  ),
                ),
                data: (attempts) {
                  if (attempts.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'لسه محدش عمل الاختبار ده',
                        style: TextStyle(color: AppColors.textMuted),
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
