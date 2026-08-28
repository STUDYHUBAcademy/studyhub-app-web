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
}
