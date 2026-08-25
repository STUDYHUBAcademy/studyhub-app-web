import '../../domain/entities/academy_expense.dart';
import '../../domain/entities/owner_profile.dart';
import '../../domain/entities/owner_withdrawal.dart';
import '../../domain/repositories/finance_repository.dart';
import '../datasources/finance_remote_datasource.dart';

class FinanceRepositoryImpl implements FinanceRepository {
  FinanceRepositoryImpl(this._remote);

  final FinanceRemoteDatasource _remote;

  @override
  Stream<List<AcademyExpense>> watchExpenses() {
    return _remote.watchExpenses().map(
      (rows) => rows.map(AcademyExpense.fromJson).toList(),
    );
  }

  @override
  Future<void> addExpense({
    required String category,
    required String name,
    required double amount,
    required String currency,
    DateTime? date,
    String? notes,
  }) {
    return _remote.addExpense({
      'category': category,
      'name': name,
      'amount': amount,
      'currency': currency,
      'date': (date ?? DateTime.now()).toIso8601String().split('T').first,
      'notes': notes,
    });
  }

  @override
  Future<void> deleteExpense(String id) => _remote.deleteExpense(id);

  @override
  Stream<List<OwnerWithdrawal>> watchWithdrawals() {
    return _remote.watchWithdrawals().map(
      (rows) => rows.map(OwnerWithdrawal.fromJson).toList(),
    );
  }

  @override
  Future<void> addWithdrawal({
    required String profileId,
    required double amount,
    required String currency,
    DateTime? date,
    String? notes,
  }) {
    return _remote.addWithdrawal({
      'profile_id': profileId,
      'amount': amount,
      'currency': currency,
      'date': (date ?? DateTime.now()).toIso8601String().split('T').first,
      'notes': notes,
    });
  }

  @override
  Future<void> deleteWithdrawal(String id) => _remote.deleteWithdrawal(id);

  @override
  Stream<List<OwnerProfile>> watchOwnerProfiles() {
    return _remote.watchOwnerProfiles().map(
      (rows) => rows.map(OwnerProfile.fromJson).toList(),
    );
  }
}
