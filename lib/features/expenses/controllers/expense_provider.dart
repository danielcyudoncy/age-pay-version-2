import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/repositories/expense_repository.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository();
});

final expensesStreamProvider = StreamProvider<List<ExpenseModel>>((ref) {
  return ref.watch(expenseRepositoryProvider).getExpenses();
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

final expenseTotalProvider = Provider<double>((ref) {
  final asyncExpenses = ref.watch(expensesStreamProvider);
  return asyncExpenses.whenOrNull(
        data: (list) => list.fold<double>(0.0, (sum, e) => sum + e.amount),
      ) ??
      0.0;
});

final expenseFilterProvider = StateProvider<ExpenseCategory?>((ref) => null);
