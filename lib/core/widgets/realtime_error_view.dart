import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A friendlier, actionable replacement for a raw exception on screen.
/// The most common cause is a stale realtime connection — the app sat
/// backgrounded long enough for the access token to expire before its
/// usual proactive refresh could fire, so every subscription fails with
/// "Token has expired" until something re-subscribes with a fresh token.
class RealtimeErrorView extends StatelessWidget {
  const RealtimeErrorView({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error.toString();
    final isConnectionIssue =
        message.contains('channelError') ||
        message.contains('Token has expired') ||
        message.contains('RealtimeSubscribeException');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isConnectionIssue
                  ? Icons.wifi_off_rounded
                  : Icons.error_outline_rounded,
              size: 36,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              isConnectionIssue ? 'حصل خطأ في الاتصال' : 'حصل خطأ: $message',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
