import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_client.dart';
import '../../data/datasources/finance_remote_datasource.dart';
import '../../data/repositories/finance_repository_impl.dart';
import '../../domain/entities/academy_expense.dart';
import '../../domain/entities/owner_profile.dart';
import '../../domain/entities/owner_withdrawal.dart';
import '../../domain/repositories/finance_repository.dart';

final financeRemoteDatasourceProvider = Provider<FinanceRemoteDatasource>((
  ref,
) {
  return FinanceRemoteDatasource(AppSupabase.client);
});

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepositoryImpl(ref.watch(financeRemoteDatasourceProvider));
});

final expensesProvider = StreamProvider<List<AcademyExpense>>((ref) {
  return ref.watch(financeRepositoryProvider).watchExpenses();
});

final withdrawalsProvider = StreamProvider<List<OwnerWithdrawal>>((ref) {
  return ref.watch(financeRepositoryProvider).watchWithdrawals();
});

final ownerProfilesProvider = StreamProvider<List<OwnerProfile>>((ref) {
  return ref.watch(financeRepositoryProvider).watchOwnerProfiles();
});
