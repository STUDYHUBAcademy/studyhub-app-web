import 'package:supabase_flutter/supabase_flutter.dart';

class FinanceRemoteDatasource {
  FinanceRemoteDatasource(this._client);

  final SupabaseClient _client;

  Stream<List<Map<String, dynamic>>> watchExpenses() {
    return _client
        .from('academy_expenses')
        .stream(primaryKey: ['id'])
        .order('date', ascending: false);
  }

  Future<void> addExpense(Map<String, dynamic> expense) async {
    await _client.from('academy_expenses').insert(expense);
  }

  Future<void> deleteExpense(String id) async {
    await _client.from('academy_expenses').delete().eq('id', id);
  }

  Stream<List<Map<String, dynamic>>> watchWithdrawals() {
    return _client
        .from('owner_withdrawals')
        .stream(primaryKey: ['id'])
        .order('date', ascending: false);
  }

  Future<void> addWithdrawal(Map<String, dynamic> withdrawal) async {
    await _client.from('owner_withdrawals').insert(withdrawal);
  }

  Future<void> deleteWithdrawal(String id) async {
    await _client.from('owner_withdrawals').delete().eq('id', id);
  }

  Stream<List<Map<String, dynamic>>> watchOwnerProfiles() {
    return _client.from('profiles').stream(primaryKey: ['id']).order('name');
  }
}
