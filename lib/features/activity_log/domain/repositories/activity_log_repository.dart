import '../entities/activity_log_entry.dart';

abstract class ActivityLogRepository {
  Stream<List<ActivityLogEntry>> watchRecent();
}
