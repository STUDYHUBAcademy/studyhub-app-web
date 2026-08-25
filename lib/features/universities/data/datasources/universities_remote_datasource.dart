import 'package:supabase_flutter/supabase_flutter.dart';

class UniversitiesRemoteDatasource {
  UniversitiesRemoteDatasource(this._client);

  final SupabaseClient _client;

  Stream<List<Map<String, dynamic>>> watchUniversities() {
    return _client
        .from('universities')
        .stream(primaryKey: ['id'])
        .order('name');
  }

  Stream<List<Map<String, dynamic>>> watchTerms() {
    return _client
        .from('terms')
        .stream(primaryKey: ['id'])
        .order('start_date', ascending: false);
  }

  Future<Map<String, dynamic>> addUniversity(String name) async {
    return _client
        .from('universities')
        .insert({'name': name})
        .select()
        .single();
  }

  Future<void> renameUniversity(String id, String name) async {
    await _client.from('universities').update({'name': name}).eq('id', id);
  }

  Future<void> deleteUniversity(String id) async {
    await _client.from('universities').delete().eq('id', id);
  }

  Future<Map<String, dynamic>> addTerm(Map<String, dynamic> term) async {
    return _client.from('terms').insert(term).select().single();
  }

  Future<void> updateTerm(String id, Map<String, dynamic> term) async {
    await _client.from('terms').update(term).eq('id', id);
  }

  Future<void> deleteTerm(String id) async {
    await _client.from('terms').delete().eq('id', id);
  }
}
