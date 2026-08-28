import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/google_sheets_backup_service.dart';
import '../../../../core/services/google_sign_in_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/full_backup_service.dart';
import '../providers/app_settings_providers.dart';

/// Resolves a signed-in Google account for the Sheets-backup scope,
/// prompting the owner to sign in (native picker on mobile, rendered button
/// on web) if there's no existing session to reuse silently.
Future<GoogleSignInAccount?> _resolveGoogleAccount(
  BuildContext context,
  GoogleSheetsBackupService service,
) async {
  final silent = await service.attemptSilentSignIn();
  if (silent != null) return silent;
  if (await service.supportsDirectSignIn) {
    return service.signInInteractively();
  }
  if (!context.mounted) return null;
  return showModalBottomSheet<GoogleSignInAccount>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _WebSignInSheet(service: service),
  );
}

class _WebSignInSheet extends StatefulWidget {
  const _WebSignInSheet({required this.service});

  final GoogleSheetsBackupService service;

  @override
  State<_WebSignInSheet> createState() => _WebSignInSheetState();
}

class _WebSignInSheetState extends State<_WebSignInSheet> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _sub;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sub = widget.service.authenticationEvents.listen(
      (event) {
        if (event is GoogleSignInAuthenticationEventSignIn && mounted) {
          Navigator.of(context).pop(event.user);
        }
      },
      onError: (Object e) {
        if (mounted) setState(() => _error = e.toString());
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'سجّل دخول بحساب جوجل عشان تقدر تعمل نسخة احتياطية',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(height: 44, child: renderGoogleSignInButton()),
          ],
        ),
      ),
    );
  }
}

class BackupCard extends ConsumerStatefulWidget {
  const BackupCard({super.key});

  @override
  ConsumerState<BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends ConsumerState<BackupCard> {
  final _sheetsService = GoogleSheetsBackupService();
  bool _running = false;
  String? _progressText;

  Future<void> _runBackup() async {
    setState(() {
      _running = true;
      _progressText = 'جاري تسجيل الدخول بجوجل...';
    });
    try {
      final account = await _resolveGoogleAccount(context, _sheetsService);
      if (account == null) {
        setState(() => _running = false);
        return;
      }
      final settings = ref.read(appSettingsProvider).valueOrNull;
      final backupService = FullBackupService(_sheetsService);
      final result = await backupService.run(
        account,
        existingSpreadsheetId: settings?.backupSpreadsheetId,
        existingSpreadsheetUrl: settings?.backupSpreadsheetUrl,
        onProgress: (table, i, total) {
          if (mounted) {
            setState(() => _progressText = 'جاري نسخ $table ($i من $total)');
          }
        },
      );
      await ref
          .read(appSettingsRepositoryProvider)
          .recordBackup(
            spreadsheetId: result.spreadsheetId,
            spreadsheetUrl: result.spreadsheetUrl,
          );
      if (!mounted) return;
      setState(() => _running = false);
      final failures = result.failures;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failures.isEmpty
                ? 'تم النسخ الاحتياطي بنجاح — ${result.totalRows} صف في ${result.tableResults.length} شيت'
                : 'اتعمل نسخ لمعظم الجداول، لكن فشل ${failures.length}: ${failures.map((f) => f.table).join('، ')}',
          ),
          backgroundColor: failures.isEmpty
              ? AppColors.success
              : AppColors.warning,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _running = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('فشل النسخ الاحتياطي: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    final lastBackupAt = settings?.lastBackupAt;
    final url = settings?.backupSpreadsheetUrl;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.cloud_upload_outlined,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'نسخة احتياطية على Google Sheets',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              lastBackupAt == null
                  ? 'لسه معملتش نسخة احتياطية'
                  : 'آخر نسخة: ${intl.DateFormat('d MMM yyyy — h:mm a', 'ar').format(lastBackupAt)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            if (_running) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _progressText ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _running ? null : _runBackup,
                  icon: const Icon(Icons.backup_outlined, size: 18),
                  label: const Text('نسخ احتياطي الآن'),
                ),
                if (url != null) ...[
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () => launchUrl(
                      Uri.parse(url),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: const Text('فتح الشيت'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
