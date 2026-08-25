import '../../domain/entities/activity_log_entry.dart';
import '../../domain/repositories/activity_log_repository.dart';
import '../datasources/activity_log_remote_datasource.dart';

class ActivityLogRepositoryImpl implements ActivityLogRepository {
  ActivityLogRepositoryImpl(this._remote);

  final ActivityLogRemoteDatasource _remote;

  @override
  Stream<List<ActivityLogEntry>> watchRecent() {
    return _remote.watchRecent().map(
      (rows) => rows.map(ActivityLogEntry.fromJson).toList(),
    );
  }
}
