import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../universities/domain/entities/term.dart';
import '../../../universities/presentation/providers/universities_providers.dart';

/// Asks the owner which term they're sharing this quiz link for — tagging
/// the link (not guessing later from a submission timestamp) is what lets
/// results stay separated per term when the same quiz gets reused across
/// terms. Returns the chosen term's id, or null for "don't tag this link".
/// Skips the prompt entirely (returns null immediately) when there are no
/// terms to choose from yet.
Future<String?> pickShareTerm(BuildContext context, WidgetRef ref) async {
  final terms = ref.read(termsProvider).valueOrNull ?? [];
  if (terms.isEmpty) return null;

  return showModalBottomSheet<String?>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'لأي فصل دراسي هتشارك اللينك ده؟',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const Text(
              'ده بيساعد إنك تفلتر النتايج بعدين حسب الترم بدقة',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('بدون تحديد ترم'),
              onTap: () => Navigator.of(context).pop(null),
            ),
            for (final Term t in terms)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.name),
                onTap: () => Navigator.of(context).pop(t.id),
              ),
          ],
        ),
      ),
    ),
  );
}
