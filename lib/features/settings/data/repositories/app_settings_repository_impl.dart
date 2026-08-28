import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/app_settings_repository.dart';
import '../datasources/app_settings_remote_datasource.dart';

class AppSettingsRepositoryImpl implements AppSettingsRepository {
  AppSettingsRepositoryImpl(this._remote);

  final AppSettingsRemoteDatasource _remote;

  @override
  Stream<AppSettings> watchSettings() {
    return _remote.watchSettings().map(
      (rows) => rows.isEmpty
          ? const AppSettings(tabbyTamaraFeePct: 8)
          : AppSettings.fromJson(rows.first),
    );
  }

  @override
  Future<void> updateTabbyTamaraFeePct(double pct) {
    return _remote.updateTabbyTamaraFeePct(pct);
  }

  @override
  Future<void> recordBackup({
    required String spreadsheetId,
    required String spreadsheetUrl,
  }) {
    return _remote.recordBackup(
      spreadsheetId: spreadsheetId,
      spreadsheetUrl: spreadsheetUrl,
    );
  }
}
