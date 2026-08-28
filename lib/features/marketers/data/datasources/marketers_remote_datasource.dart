import 'package:supabase_flutter/supabase_flutter.dart';

class MarketersRemoteDatasource {
  MarketersRemoteDatasource(this._client);

  final SupabaseClient _client;

  Stream<List<Map<String, dynamic>>> watchMarketers() {
    return _client.from('marketers').stream(primaryKey: ['id']).order('name');
  }

  Future<Map<String, dynamic>> addMarketer({
    required String name,
    String? phoneWhatsapp,
    double? defaultCommissionAmount,
    String? notes,
  }) async {
    final row = await _client
        .from('marketers')
        .insert({
          'name': name,
          'phone_whatsapp': phoneWhatsapp,
          'default_commission_amount': defaultCommissionAmount,
          'notes': notes,
        })
        .select()
        .single();
    return row;
  }

  Future<void> updateMarketer(String id, Map<String, dynamic> patch) async {
    await _client.from('marketers').update(patch).eq('id', id);
  }

  Future<void> deleteMarketer(String id) async {
    await _client.from('marketers').delete().eq('id', id);
  }
}
