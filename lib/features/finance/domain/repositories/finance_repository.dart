import '../entities/academy_expense.dart';
import '../entities/owner_profile.dart';
import '../entities/owner_withdrawal.dart';

abstract class FinanceRepository {
  Stream<List<AcademyExpense>> watchExpenses();
  Future<void> addExpense({
    required String category,
    required String name,
    required double amount,
    required String currency,
    DateTime? date,
    String? notes,
  });
  Future<void> deleteExpense(String id);

  Stream<List<OwnerWithdrawal>> watchWithdrawals();
  Future<void> addWithdrawal({
    required String profileId,
    required double amount,
    required String currency,
    DateTime? date,
    String? notes,
  });
  Future<void> deleteWithdrawal(String id);

  Stream<List<OwnerProfile>> watchOwnerProfiles();
}
