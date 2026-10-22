import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../models/expense_model.dart';
import '../repositories/expense_repository.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository();
});

final expensesStreamProvider = StreamProvider<List<ExpenseModel>>((ref) {
  return ref.watch(expenseRepositoryProvider).getExpenses();
});

final pendingExpensesStreamProvider = StreamProvider<List<ExpenseModel>>((ref) {
  return ref.watch(expenseRepositoryProvider).getPendingExpenses();
});

final expensesByCategoryProvider =
    Provider.family<AsyncValue<List<ExpenseModel>>, ExpenseCategory>((
      ref,
      category,
    ) {
      final asyncExpenses = ref.watch(expensesStreamProvider);
      return asyncExpenses.whenData(
        (list) => list.where((e) => e.category == category).toList(),
      );
    });

/// Only approved expenses are deducted from organization funds
final expenseTotalProvider = Provider<double>((ref) {
  final asyncExpenses = ref.watch(expensesStreamProvider);
  return asyncExpenses.whenOrNull(
        data: (list) => list
            .where((e) => e.status == ExpenseStatus.approved)
            .fold<double>(0.0, (sum, e) => sum + e.amount),
      ) ??
      0.0;
});

/// Total amount of expenses currently awaiting executive approvals
final pendingExpenseTotalProvider = Provider<double>((ref) {
  final asyncExpenses = ref.watch(expensesStreamProvider);
  return asyncExpenses.whenOrNull(
        data: (list) => list
            .where((e) => e.status == ExpenseStatus.pendingApproval)
            .fold<double>(0.0, (sum, e) => sum + e.amount),
      ) ??
      0.0;
});

final expenseFilterProvider = StateProvider<ExpenseCategory?>((ref) => null);
