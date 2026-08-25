import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/network/supabase_client.dart';
import '../../../../core/services/notification_service.dart';
import '../../data/datasources/sessions_remote_datasource.dart';
import '../../data/repositories/sessions_repository_impl.dart';
import '../../domain/entities/private_session.dart';
import '../../domain/repositories/sessions_repository.dart';

final sessionsRemoteDatasourceProvider = Provider<SessionsRemoteDatasource>((
  ref,
) {
  return SessionsRemoteDatasource(AppSupabase.client);
});

final sessionsRepositoryProvider = Provider<SessionsRepository>((ref) {
  return SessionsRepositoryImpl(ref.watch(sessionsRemoteDatasourceProvider));
});

final sessionsProvider = StreamProvider<List<PrivateSession>>((ref) {
  return ref.watch(sessionsRepositoryProvider).watchSessions();
});

/// Watched once from the app root so every device (both owners) reschedules
/// its local reminders whenever the sessions list syncs — not just the
/// device that created/edited the session.
final sessionsReminderSyncProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<List<PrivateSession>>>(sessionsProvider, (
    previous,
    next,
  ) {
    final sessions = next.valueOrNull;
    if (sessions == null) return;
    for (final s in sessions) {
      final scheduledAt = s.scheduledAt;
      if (s.status == 'scheduled' &&
          scheduledAt != null &&
          scheduledAt.isAfter(DateTime.now())) {
        NotificationService.instance.scheduleSessionReminder(
          sessionId: s.id,
          title: '🗓️ تذكير بحصة',
          body:
              'عندك حصة مع أكاديمية StudyHub الساعة ${intl.DateFormat('h:mm a', 'ar').format(scheduledAt)} في مادة ${s.subject}.',
          scheduledAt: scheduledAt,
        );
      } else {
        NotificationService.instance.cancelSessionReminder(s.id);
      }
    }
  }, fireImmediately: true);
});
