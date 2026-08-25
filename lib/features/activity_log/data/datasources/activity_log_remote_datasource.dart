import 'package:supabase_flutter/supabase_flutter.dart';

class ActivityLogRemoteDatasource {
  ActivityLogRemoteDatasource(this._client);

  final SupabaseClient _client;

  Stream<List<Map<String, dynamic>>> watchRecent({int limit = 50}) {
    return _client
        .from('activity_log')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(limit);
  }
}
