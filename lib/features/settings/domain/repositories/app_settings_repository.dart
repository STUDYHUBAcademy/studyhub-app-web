import '../entities/app_settings.dart';

abstract class AppSettingsRepository {
  Stream<AppSettings> watchSettings();
  Future<void> updateTabbyTamaraFeePct(double pct);
  Future<void> recordBackup({
    required String spreadsheetId,
    required String spreadsheetUrl,
  });
}
