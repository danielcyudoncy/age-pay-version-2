import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../models/expense_model.dart';
import '../repositories/expense_repository.dart';
import '../../auth/controllers/auth_provider.dart';
import '../../national/controllers/national_provider.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository();
});

final expensesStreamProvider = StreamProvider.autoDispose<List<ExpenseModel>>((ref) {
  final user = ref.watch(authProvider).valueOrNull;
  if (user == null) return const Stream.empty();

  final activeScope = ref.watch(activeExecutiveScopeProvider);
  final isNationalScope = activeScope == ExecutiveScope.national &&
      (user.nationalRole != null || user.role == UserRole.superAdmin);

  return ref.watch(expenseRepositoryProvider).getExpenses().map((expenses) {
    if (isNationalScope) {
      return expenses.where((e) {
        return e.branchId == 'national' ||
            ((user.branchId == null || user.branchId!.isEmpty) &&
                (e.branchId == null || e.branchId!.isEmpty));
      }).toList();
    }
    if (user.role == UserRole.superAdmin) {
      return expenses;
    }
    if (user.branchId != null && user.branchId!.isNotEmpty) {
      return expenses.where((e) {
        if (e.branchId != null && e.branchId!.isNotEmpty) {
          return e.branchId == user.branchId;
        }
        return e.createdBy == user.uid;
      }).toList();
    }
    return expenses;
  });
});

final pendingExpensesStreamProvider = StreamProvider.autoDispose<List<ExpenseModel>>((ref) {
  final user = ref.watch(authProvider).valueOrNull;
  if (user == null) return const Stream.empty();

  final activeScope = ref.watch(activeExecutiveScopeProvider);
  final isNationalScope = activeScope == ExecutiveScope.national &&
      (user.nationalRole != null || user.role == UserRole.superAdmin);

  return ref.watch(expenseRepositoryProvider).getPendingExpenses().map((expenses) {
    if (isNationalScope) {
      return expenses.where((e) {
        return e.branchId == 'national' ||
            ((user.branchId == null || user.branchId!.isEmpty) &&
                (e.branchId == null || e.branchId!.isEmpty));
      }).toList();
    }
    if (user.role == UserRole.superAdmin) {
      return expenses;
    }
    if (user.branchId != null && user.branchId!.isNotEmpty) {
      return expenses.where((e) {
        if (e.branchId != null && e.branchId!.isNotEmpty) {
          return e.branchId == user.branchId;
        }
        return e.createdBy == user.uid;
      }).toList();
    }
    return expenses;
  });
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
