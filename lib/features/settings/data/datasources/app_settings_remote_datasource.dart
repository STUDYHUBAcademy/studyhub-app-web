import 'package:supabase_flutter/supabase_flutter.dart';

class AppSettingsRemoteDatasource {
  AppSettingsRemoteDatasource(this._client);

  final SupabaseClient _client;

  Stream<List<Map<String, dynamic>>> watchSettings() {
    return _client.from('app_settings').stream(primaryKey: ['id']);
  }

  Future<void> updateTabbyTamaraFeePct(double pct) async {
    await _client
        .from('app_settings')
        .update({'tabby_tamara_fee_pct': pct})
        .eq('id', true);
  }

  Future<void> recordBackup({
    required String spreadsheetId,
    required String spreadsheetUrl,
  }) async {
    await _client
        .from('app_settings')
        .update({
          'backup_spreadsheet_id': spreadsheetId,
          'backup_spreadsheet_url': spreadsheetUrl,
          'last_backup_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', true);
  }
}
