import 'package:supabase_flutter/supabase_flutter.dart';

class StudentsRemoteDatasource {
  StudentsRemoteDatasource(this._client);

  final SupabaseClient _client;

  Stream<List<Map<String, dynamic>>> watchStudents() {
    return _client.from('students').stream(primaryKey: ['id']).order('name');
  }

  Future<Map<String, dynamic>> addStudent({
    required String name,
    String? phoneWhatsapp,
    String? universityId,
    String acquisitionSource = 'direct',
    String? marketerName,
    double? commissionPct,
    double? commissionAmount,
  }) async {
    final row = await _client
        .from('students')
        .insert({
          'name': name,
          'phone_whatsapp': phoneWhatsapp,
          'university_id': universityId,
          'acquisition_source': acquisitionSource,
          'marketer_name': marketerName,
          'commission_pct': commissionPct,
          // Omitted rather than sent as null: Supabase's schema cache for
          // this column has been intermittently stale, and leaving it out
          // entirely when unused sidesteps that instead of erroring.
          'commission_amount': ?commissionAmount,
        })
        .select()
        .single();
    return row;
  }

  Future<void> updateStudent(String id, Map<String, dynamic> patch) async {
    await _client.from('students').update(patch).eq('id', id);
  }

  Future<void> deleteStudent(String id) async {
    await _client.from('students').delete().eq('id', id);
  }
}
