import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/realtime_error_view.dart';
import '../../domain/entities/academy_expense.dart';
import '../../domain/entities/owner_profile.dart';
import '../providers/finance_providers.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('💰 المالية'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'المصروفات'),
              Tab(text: 'مسحوبات الشركاء'),
            ],
          ),
        ),
        body: const TabBarView(children: [_ExpensesTab(), _WithdrawalsTab()]),
      ),
    );
  }
}

const _currencies = ['SAR', 'EGP', 'USD', 'AED'];

class _ExpensesTab extends ConsumerWidget {
  const _ExpensesTab();

  Future<void> _addExpense(BuildContext context, WidgetRef ref) async {
    var category = 'admin';
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    var currency = 'SAR';
    DateTime date = DateTime.now();
    final notesController = TextEditingController();
    String? formError;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: const Text('إضافة مصروف'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'التصنيف'),
                    items: expenseCategoryLabels.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => category = v ?? 'admin'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم المصروف (مثلاً: اشتراك زووم)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'المبلغ',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: currency,
                        items: _currencies
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => currency = v ?? 'SAR'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => date = picked);
                    },
                    child: Text(
                      intl.DateFormat('d MMMM yyyy', 'ar').format(date),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات (اختياري)',
                    ),
                  ),
                  if (formError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      formError!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty ||
                    double.tryParse(amountController.text.trim()) == null) {
                  setState(() => formError = 'اكتب اسم المصروف ومبلغ صحيح');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final amount = double.tryParse(amountController.text.trim());
    if (amount == null) return;
    await ref
        .read(financeRepositoryProvider)
        .addExpense(
          category: category,
          name: nameController.text.trim(),
          amount: amount,
          currency: currency,
          date: date,
          notes: notesController.text.trim().isEmpty
              ? null
              : notesController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'expenses_fab',
        onPressed: () => _addExpense(context, ref),
        child: const Icon(Icons.add),
      ),
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => RealtimeErrorView(
          error: err,
          onRetry: () => ref.invalidate(expensesProvider),
        ),
        data: (expenses) {
          if (expenses.isEmpty) {
            return const Center(
              child: Text(
                'لسه مفيش مصروفات مسجلة',
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
            itemCount: expenses.length,
            itemBuilder: (context, i) {
              final e = expenses[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(e.name),
                  subtitle: Text(
                    '${expenseCategoryLabels[e.category] ?? e.category} • ${intl.DateFormat('d MMM yyyy', 'ar').format(e.date)}'
                    '${e.notes != null && e.notes!.isNotEmpty ? '\n${e.notes}' : ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  isThreeLine: e.notes != null && e.notes!.isNotEmpty,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${e.amount.toStringAsFixed(0)} ${e.currency}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppColors.warning,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => ref
                            .read(financeRepositoryProvider)
                            .deleteExpense(e.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _WithdrawalsTab extends ConsumerWidget {
  const _WithdrawalsTab();

  Future<void> _addWithdrawal(
    BuildContext context,
    WidgetRef ref,
    List<OwnerProfile> owners,
  ) async {
    OwnerProfile? owner = owners.firstOrNull;
    final amountController = TextEditingController();
    var currency = 'SAR';
    DateTime date = DateTime.now();
    final notesController = TextEditingController();
    String? formError;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: const Text('تسجيل مسحوبات'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<OwnerProfile>(
                    initialValue: owner,
                    decoration: const InputDecoration(labelText: 'الشريك'),
                    items: owners
                        .map(
                          (o) =>
                              DropdownMenuItem(value: o, child: Text(o.name)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => owner = v),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'المبلغ',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: currency,
                        items: _currencies
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => currency = v ?? 'SAR'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => date = picked);
                    },
                    child: Text(
                      intl.DateFormat('d MMMM yyyy', 'ar').format(date),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات (اختياري)',
                    ),
                  ),
                  if (formError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      formError!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (owner == null ||
                    double.tryParse(amountController.text.trim()) == null) {
                  setState(() => formError = 'اختار الشريك واكتب مبلغ صحيح');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || owner == null) return;
    final amount = double.tryParse(amountController.text.trim());
    if (amount == null) return;
    await ref
        .read(financeRepositoryProvider)
        .addWithdrawal(
          profileId: owner!.id,
          amount: amount,
          currency: currency,
          date: date,
          notes: notesController.text.trim().isEmpty
              ? null
              : notesController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final withdrawalsAsync = ref.watch(withdrawalsProvider);
    final owners = ref.watch(ownerProfilesProvider).valueOrNull ?? [];
    final ownerNames = {for (final o in owners) o.id: o.name};

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'withdrawals_fab',
        onPressed: owners.isEmpty
            ? null
            : () => _addWithdrawal(context, ref, owners),
        child: const Icon(Icons.add),
      ),
      body: withdrawalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => RealtimeErrorView(
          error: err,
          onRetry: () => ref.invalidate(withdrawalsProvider),
        ),
        data: (withdrawals) {
          if (withdrawals.isEmpty) {
            return const Center(
              child: Text(
                'لسه مفيش مسحوبات مسجلة',
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
            itemCount: withdrawals.length,
            itemBuilder: (context, i) {
              final w = withdrawals[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(ownerNames[w.profileId] ?? '؟'),
                  subtitle: Text(
                    '${intl.DateFormat('d MMM yyyy', 'ar').format(w.date)}'
                    '${w.notes != null && w.notes!.isNotEmpty ? '\n${w.notes}' : ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  isThreeLine: w.notes != null && w.notes!.isNotEmpty,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${w.amount.toStringAsFixed(0)} ${w.currency}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppColors.error,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => ref
                            .read(financeRepositoryProvider)
                            .deleteWithdrawal(w.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
