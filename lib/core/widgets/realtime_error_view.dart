import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A friendlier, actionable replacement for a raw exception on screen.
/// The most common cause is a stale realtime connection — the app sat
/// backgrounded long enough for the access token to expire before its
/// usual proactive refresh could fire, so every subscription fails with
/// "Token has expired" until something re-subscribes with a fresh token.
///
/// Connection-flavored errors are usually transient (the underlying socket
/// reconnects within a couple of seconds on its own), so this retries
/// automatically with backoff instead of leaving the owner staring at an
/// error until they think to tap the button themselves. The manual button
/// stays available for a retry that isn't self-healing.
class RealtimeErrorView extends StatefulWidget {
  const RealtimeErrorView({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  State<RealtimeErrorView> createState() => _RealtimeErrorViewState();
}

class _RealtimeErrorViewState extends State<RealtimeErrorView> {
  Timer? _autoRetryTimer;
  int _attempt = 0;

  bool get _isConnectionIssue {
    final message = widget.error.toString();
    return message.contains('channelError') ||
        message.contains('Token has expired') ||
        message.contains('RealtimeSubscribeException');
  }

  @override
  void initState() {
    super.initState();
    _scheduleAutoRetryIfNeeded();
  }

  @override
  void didUpdateWidget(RealtimeErrorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A fresh error instance means the retry above didn't fix it — back off
    // a bit further before trying again, capped so it doesn't hammer.
    if (oldWidget.error != widget.error) {
      _scheduleAutoRetryIfNeeded();
    }
  }

  void _scheduleAutoRetryIfNeeded() {
    _autoRetryTimer?.cancel();
    if (!_isConnectionIssue || _attempt >= 4) return;
    _attempt++;
    final delay = Duration(seconds: _attempt * 2);
    _autoRetryTimer = Timer(delay, () {
      if (mounted) widget.onRetry();
    });
  }

  @override
  void dispose() {
    _autoRetryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.error.toString();
    final isConnectionIssue = _isConnectionIssue;

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
              onPressed: widget.onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
