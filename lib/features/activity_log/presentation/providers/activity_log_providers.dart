import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_client.dart';
import '../../data/datasources/activity_log_remote_datasource.dart';
import '../../data/repositories/activity_log_repository_impl.dart';
import '../../domain/entities/activity_log_entry.dart';
import '../../domain/repositories/activity_log_repository.dart';

final activityLogRemoteDatasourceProvider =
    Provider<ActivityLogRemoteDatasource>((ref) {
      return ActivityLogRemoteDatasource(AppSupabase.client);
    });

final activityLogRepositoryProvider = Provider<ActivityLogRepository>((ref) {
  return ActivityLogRepositoryImpl(
    ref.watch(activityLogRemoteDatasourceProvider),
  );
});

final activityLogProvider = StreamProvider<List<ActivityLogEntry>>((ref) {
  return ref.watch(activityLogRepositoryProvider).watchRecent();
});
