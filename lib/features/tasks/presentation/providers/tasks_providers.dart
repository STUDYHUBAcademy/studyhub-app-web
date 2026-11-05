import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/network/supabase_client.dart';
import '../../../../core/services/notification_service.dart';
import '../../../finance/presentation/providers/finance_providers.dart';
import '../../data/datasources/tasks_remote_datasource.dart';
import '../../data/repositories/tasks_repository_impl.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/tasks_repository.dart';

final tasksRemoteDatasourceProvider = Provider<TasksRemoteDatasource>((ref) {
  return TasksRemoteDatasource(AppSupabase.client);
});

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return TasksRepositoryImpl(ref.watch(tasksRemoteDatasourceProvider));
});

final tasksProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(tasksRepositoryProvider).watchTasks();
});

/// Watched once from the app root so every device reschedules its local
/// "task due soon" reminders (1 day and 6 hours before the due date)
/// whenever the tasks list syncs — same pattern as sessionsReminderSyncProvider.
final taskDueReminderSyncProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<List<Task>>>(tasksProvider, (previous, next) {
    final tasks = next.valueOrNull;
    if (tasks == null) return;
    for (final t in tasks) {
      final due = t.dueDate;
      if (t.status != 'done' && due != null) {
        final dueMoment = DateTime(due.year, due.month, due.day, 23, 59);
        NotificationService.instance.scheduleTaskReminder(
          taskId: t.id,
          title: '📌 تذكير بمهمة',
          body:
              'المهمة "${t.title}" موعدها ${intl.DateFormat('d MMMM', 'ar').format(due)}.',
          dueMoment: dueMoment,
        );
      } else {
        NotificationService.instance.cancelTaskReminder(t.id);
      }
    }
  }, fireImmediately: true);
});

/// Watched once from the app root — fires an instant local notification
/// when the OTHER owner adds a task while this device is running (never
/// for the owner's own tasks, and never replays the backlog that already
/// existed when the app launched).
final taskCreationAlertProvider = Provider<void>((ref) {
  final sessionStart = DateTime.now();
  final notified = <String>{};
  ref.listen<AsyncValue<List<Task>>>(tasksProvider, (previous, next) {
    final tasks = next.valueOrNull;
    if (tasks == null) return;
    final myId = AppSupabase.client.auth.currentUser?.id;
    final owners = ref.read(ownerProfilesProvider).valueOrNull ?? [];
    for (final t in tasks) {
      if (!notified.add(t.id)) continue;
      if (!t.createdAt.isAfter(sessionStart)) continue;
      if (t.createdBy == null || t.createdBy == myId) continue;
      final creatorName = owners
          .where((o) => o.id == t.createdBy)
          .firstOrNull
          ?.name;
      NotificationService.instance.showInstant(
        id: ('new_task_${t.id}').hashCode & 0x7fffffff,
        title: '✅ مهمة جديدة',
        body: creatorName != null
            ? '$creatorName أضاف مهمة: ${t.title}'
            : 'مهمة جديدة: ${t.title}',
      );
    }
  });
});
