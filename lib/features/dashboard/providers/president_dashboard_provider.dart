import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/data/models/payment_model.dart';
import 'package:cls/data/models/expense_model.dart';
import 'package:cls/data/models/member_model.dart';
import 'package:cls/features/dashboard/providers/member_dashboard_provider.dart';
import 'package:cls/features/obligations/providers/obligation_provider.dart';
import 'package:cls/features/levies/providers/levy_provider.dart'
    hide obligationRepositoryProvider;
import 'package:cls/features/expenses/providers/expense_provider.dart';
import 'package:cls/features/dashboard/providers/treasurer_dashboard_provider.dart';

// ---------------------------------------------------------------------------
// Stream providers
// ---------------------------------------------------------------------------
final presidentAllPaymentsStreamProvider =
    StreamProvider.autoDispose<List<PaymentModel>>((ref) {
      return ref.watch(paymentRepositoryProvider).getAllPayments();
    });

final presidentMembersStreamProvider =
    StreamProvider.autoDispose<List<MemberModel>>((ref) {
      return ref.watch(memberRepositoryProvider).getMembers();
    });

final presidentExpensesStreamProvider =
    StreamProvider.autoDispose<List<ExpenseModel>>((ref) {
      return ref.watch(expenseRepositoryProvider).getExpenses();
    });

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------
class MonthlyCollection {
  final String monthLabel;
  final double amount;

  MonthlyCollection({required this.monthLabel, required this.amount});
}

class ActiveLevySummary {
  final String title;
  final double totalCollected;
  final double totalTarget;
  final double percentage;
  final int memberCount;

  ActiveLevySummary({
    required this.title,
    required this.totalCollected,
    required this.totalTarget,
    required this.percentage,
    required this.memberCount,
  });
}

class PresidentDashboardData {
  final int totalMembers;
  final double totalCollections;
  final double totalOutstandingLevies;
  final List<MonthlyCollection> monthlyCollections;
  final Map<PaymentMethod, double> collectionsByMethod;
  final List<ActiveLevySummary> activeLeviesSummary;
  final List<ExpenseModel> recentExpenses;
  final double totalExpenses;
  final double netPosition;

  PresidentDashboardData({
    required this.totalMembers,
    required this.totalCollections,
    required this.totalOutstandingLevies,
    required this.monthlyCollections,
    required this.collectionsByMethod,
    required this.activeLeviesSummary,
    required this.recentExpenses,
    required this.totalExpenses,
    required this.netPosition,
  });
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------
AsyncValue<T> _combine<T>(List<AsyncValue> inputs, T Function() build) {
  for (final input in inputs) {
    if (input is AsyncLoading) return const AsyncValue.loading();
  }
  for (final input in inputs) {
    if (input is AsyncError) {
      return AsyncValue.error(input.error, input.stackTrace);
    }
  }
  try {
    return AsyncValue.data(build());
  } catch (e, st) {
    return AsyncValue.error(e, st);
  }
}

String _monthLabel(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

// ---------------------------------------------------------------------------
// Metric providers
// ---------------------------------------------------------------------------
final totalMembersProvider = Provider.autoDispose<AsyncValue<int>>((ref) {
  final membersAsync = ref.watch(presidentMembersStreamProvider);
  return membersAsync.whenData((list) => list.length);
});

final totalCollectionsProvider = Provider.autoDispose<AsyncValue<double>>((
  ref,
) {
  final paymentsAsync = ref.watch(presidentAllPaymentsStreamProvider);
  return paymentsAsync.whenData(
    (list) => list
        .where((p) => p.status == PaymentStatus.approved)
        .fold<double>(0.0, (sum, p) => sum + p.amount),
  );
});

final totalOutstandingLeviesProvider = Provider.autoDispose<AsyncValue<double>>(
  (ref) {
    final obligationsAsync = ref.watch(allObligationsProvider);
    return obligationsAsync.whenData(
      (list) => list
          .where(
            (o) => o.status != ObligationStatus.paid && o.levyId.isNotEmpty,
          )
          .fold<double>(0.0, (sum, o) => sum + o.outstandingBalance),
    );
  },
);

final monthlyCollectionsProvider =
    Provider.autoDispose<AsyncValue<List<MonthlyCollection>>>((ref) {
      final paymentsAsync = ref.watch(presidentAllPaymentsStreamProvider);
      return paymentsAsync.whenData((list) {
        final now = DateTime.now();
        final approved = list
            .where((p) => p.status == PaymentStatus.approved)
            .toList();

        final result = <MonthlyCollection>[];
        for (int i = 11; i >= 0; i--) {
          final date = DateTime(now.year, now.month - i, 1);
          final label = _monthLabel(date);
          final keyYear = date.year;
          final keyMonth = date.month;
          final amount = approved
              .where(
                (p) =>
                    p.createdAt.year == keyYear &&
                    p.createdAt.month == keyMonth,
              )
              .fold<double>(0.0, (sum, p) => sum + p.amount);
          result.add(MonthlyCollection(monthLabel: label, amount: amount));
        }
        return result;
      });
    });

final collectionsByMethodProvider =
    Provider.autoDispose<AsyncValue<Map<PaymentMethod, double>>>((ref) {
      final paymentsAsync = ref.watch(presidentAllPaymentsStreamProvider);
      return paymentsAsync.whenData((list) {
        final result = <PaymentMethod, double>{};
        for (final method in PaymentMethod.values) {
          result[method] = 0.0;
        }
        for (final payment in list.where(
          (p) => p.status == PaymentStatus.approved,
        )) {
          result[payment.method] =
              (result[payment.method] ?? 0.0) + payment.amount;
        }
        return result;
      });
    });

final activeLeviesSummaryProvider =
    Provider.autoDispose<AsyncValue<List<ActiveLevySummary>>>((ref) {
      final leviesAsync = ref.watch(activeLeviesProvider);
      final obligationsAsync = ref.watch(allObligationsProvider);

      return _combine<List<ActiveLevySummary>>(
        [leviesAsync, obligationsAsync],
        () {
          final levies = leviesAsync.valueOrNull ?? [];
          final obligations = obligationsAsync.valueOrNull ?? [];

          return levies.map((levy) {
            final levyObligations = obligations
                .where((o) => o.levyId == levy.id)
                .toList();
            final target = levyObligations.fold<double>(
              0.0,
              (sum, o) => sum + o.amount,
            );
            final collected = levyObligations.fold<double>(
              0.0,
              (sum, o) => sum + o.paidAmount,
            );
            final percentage = target > 0
                ? (collected / target).clamp(0.0, 1.0)
                : 0.0;
            return ActiveLevySummary(
              title: levy.title,
              totalCollected: collected,
              totalTarget: target,
              percentage: percentage,
              memberCount: levyObligations.length,
            );
          }).toList();
        },
      );
    });

final recentExpensesProvider =
    Provider.autoDispose<AsyncValue<List<ExpenseModel>>>((ref) {
      final expensesAsync = ref.watch(presidentExpensesStreamProvider);
      return expensesAsync.whenData((list) {
        final sorted = [...list]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return sorted.take(10).toList();
      });
    });

final financialOverviewProvider =
    Provider.autoDispose<AsyncValue<Map<String, double>>>((ref) {
      final collectionsAsync = ref.watch(totalCollectionsProvider);
      final expensesAsync = ref.watch(presidentExpensesStreamProvider);

      return _combine<Map<String, double>>(
        [collectionsAsync, expensesAsync],
        () {
          final collections = collectionsAsync.valueOrNull ?? 0.0;
          final allExpenses = expensesAsync.valueOrNull ?? [];
          final totalExpenses = allExpenses.fold<double>(
            0.0,
            (sum, e) => sum + e.amount,
          );
          return {
            'totalCollections': collections,
            'totalExpenses': totalExpenses,
            'netPosition': collections - totalExpenses,
          };
        },
      );
    });

// ---------------------------------------------------------------------------
// Main dashboard provider
// ---------------------------------------------------------------------------
final presidentDashboardProvider =
    Provider.autoDispose<AsyncValue<PresidentDashboardData>>((ref) {
      final membersAsync = ref.watch(totalMembersProvider);
      final collectionsAsync = ref.watch(totalCollectionsProvider);
      final outstandingAsync = ref.watch(totalOutstandingLeviesProvider);
      final monthlyAsync = ref.watch(monthlyCollectionsProvider);
      final methodAsync = ref.watch(collectionsByMethodProvider);
      final leviesAsync = ref.watch(activeLeviesSummaryProvider);
      final recentExpensesAsync = ref.watch(recentExpensesProvider);
      final financialAsync = ref.watch(financialOverviewProvider);

      return _combine<PresidentDashboardData>(
        [
          membersAsync,
          collectionsAsync,
          outstandingAsync,
          monthlyAsync,
          methodAsync,
          leviesAsync,
          recentExpensesAsync,
          financialAsync,
        ],
        () {
          final financial =
              financialAsync.valueOrNull ??
              {
                'totalCollections': 0.0,
                'totalExpenses': 0.0,
                'netPosition': 0.0,
              };
          return PresidentDashboardData(
            totalMembers: membersAsync.valueOrNull ?? 0,
            totalCollections: collectionsAsync.valueOrNull ?? 0.0,
            totalOutstandingLevies: outstandingAsync.valueOrNull ?? 0.0,
            monthlyCollections: monthlyAsync.valueOrNull ?? [],
            collectionsByMethod: methodAsync.valueOrNull ?? {},
            activeLeviesSummary: leviesAsync.valueOrNull ?? [],
            recentExpenses: recentExpensesAsync.valueOrNull ?? [],
            totalExpenses: financial['totalExpenses'] ?? 0.0,
            netPosition: financial['netPosition'] ?? 0.0,
          );
        },
      );
    });
