import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/data/models/obligation_model.dart';
import 'package:cls/data/models/member_model.dart';
import 'package:cls/data/models/payment_model.dart';
import 'package:cls/data/repositories/member_repository.dart';
import 'package:cls/features/dashboard/providers/member_dashboard_provider.dart'
    show paymentRepositoryProvider;
import 'package:cls/features/obligations/providers/obligation_provider.dart';
import 'package:cls/features/levies/providers/levy_provider.dart'
    hide obligationRepositoryProvider;
import 'package:cls/features/expenses/providers/expense_provider.dart';

// ---------------------------------------------------------------------------
// Repositories
// ---------------------------------------------------------------------------
final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  return MemberRepository();
});

// ---------------------------------------------------------------------------
// Streams
// ---------------------------------------------------------------------------
final allPaymentsStreamProvider = StreamProvider.autoDispose<List<PaymentModel>>(
  (ref) {
    return ref.watch(paymentRepositoryProvider).getAllPayments();
  },
);

final membersStreamProvider = StreamProvider.autoDispose<List<MemberModel>>(
  (ref) {
    return ref.watch(memberRepositoryProvider).getMembers();
  },
);

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------
class MemberArrears {
  final String memberId;
  final String memberName;
  final double totalOutstanding;
  final int unpaidCount;

  MemberArrears({
    required this.memberId,
    required this.memberName,
    required this.totalOutstanding,
    required this.unpaidCount,
  });
}

class LevyCollectionSummary {
  final String levyId;
  final String title;
  final double collected;
  final double target;
  final double percentage;
  final int memberCount;

  LevyCollectionSummary({
    required this.levyId,
    required this.title,
    required this.collected,
    required this.target,
    required this.percentage,
    required this.memberCount,
  });
}

class RecentPaymentItem {
  final PaymentModel payment;
  final String memberName;

  RecentPaymentItem({
    required this.payment,
    required this.memberName,
  });
}

class TreasurerDashboardData {
  final double totalCollected;
  final double totalOutstanding;
  final double totalPending;
  final int totalMembers;
  final List<MemberArrears> memberArrears;
  final List<LevyCollectionSummary> levyCollection;
  final double expenseTotal;
  final double netPosition;
  final List<RecentPaymentItem> recentPayments;

  TreasurerDashboardData({
    required this.totalCollected,
    required this.totalOutstanding,
    required this.totalPending,
    required this.totalMembers,
    required this.memberArrears,
    required this.levyCollection,
    required this.expenseTotal,
    required this.netPosition,
    required this.recentPayments,
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

// ---------------------------------------------------------------------------
// Metric providers
// ---------------------------------------------------------------------------
final totalCollectedProvider = Provider.autoDispose<AsyncValue<double>>((ref) {
  // Sum paidAmount from obligations directly - this captures both manual
  // payment updates (via "Update Payment Status") and actual payment transactions.
  final obligationsAsync = ref.watch(allObligationsProvider);
  return obligationsAsync.whenData((list) =>
      list.fold<double>(0.0, (sum, o) => sum + o.paidAmount));
});

final totalOutstandingProvider = Provider.autoDispose<AsyncValue<double>>((ref) {
  final obligationsAsync = ref.watch(allObligationsProvider);
  return obligationsAsync.whenData((list) => list
      .where((o) => o.status != ObligationStatus.paid)
      .fold<double>(0.0, (sum, o) => sum + o.outstandingBalance));
});

final totalPendingProvider = Provider.autoDispose<AsyncValue<double>>((ref) {
  final paymentsAsync = ref.watch(allPaymentsStreamProvider);
  return paymentsAsync.whenData((list) => list
      .where((p) => p.status == PaymentStatus.pending)
      .fold<double>(0.0, (sum, p) => sum + p.amount));
});

final totalMembersProvider = Provider.autoDispose<AsyncValue<int>>((ref) {
  final membersAsync = ref.watch(membersStreamProvider);
  return membersAsync.whenData((list) => list.length);
});

final memberArrearsProvider =
    Provider.autoDispose<AsyncValue<List<MemberArrears>>>((ref) {
  final obligationsAsync = ref.watch(allObligationsProvider);
  final membersAsync = ref.watch(membersStreamProvider);

  return _combine<List<MemberArrears>>([obligationsAsync, membersAsync], () {
    final obligations = obligationsAsync.valueOrNull ?? [];
    final members = membersAsync.valueOrNull ?? [];

    final map = <String, List<ObligationModel>>{};
    for (final o in obligations) {
      if (o.outstandingBalance > 0) {
        map.putIfAbsent(o.memberId, () => []).add(o);
      }
    }

    final result = map.entries.map((e) {
      final member = members.firstWhere(
        (m) => m.userId == e.key || m.id == e.key,
        orElse: () => MemberModel(
          id: e.key,
          userId: e.key,
          fullName: 'Unknown',
          email: '',
          phoneNumber: '',
          dateOfBirth: DateTime(2000),
          joinedDate: DateTime(2000),
          createdAt: DateTime(2000),
          updatedAt: DateTime(2000),
        ),
      );
      final total =
          e.value.fold<double>(0.0, (sum, o) => sum + o.outstandingBalance);
      return MemberArrears(
        memberId: e.key,
        memberName: member.fullName,
        totalOutstanding: total,
        unpaidCount: e.value.where((o) => o.status != ObligationStatus.paid).length,
      );
    }).toList();

    result.sort((a, b) => b.totalOutstanding.compareTo(a.totalOutstanding));
    return result;
  });
});

final levyCollectionProvider =
    Provider.autoDispose<AsyncValue<List<LevyCollectionSummary>>>((ref) {
  final leviesAsync = ref.watch(activeLeviesProvider);
  final obligationsAsync = ref.watch(allObligationsProvider);

  return _combine<List<LevyCollectionSummary>>(
    [leviesAsync, obligationsAsync],
    () {
      final levies = leviesAsync.valueOrNull ?? [];
      final obligations = obligationsAsync.valueOrNull ?? [];

      return levies.map((levy) {
        final levyObligations =
            obligations.where((o) => o.levyId == levy.id).toList();
        final target =
            levyObligations.fold<double>(0.0, (sum, o) => sum + o.amount);
        final collected =
            levyObligations.fold<double>(0.0, (sum, o) => sum + o.paidAmount);
        final percentage = target > 0 ? (collected / target).clamp(0.0, 1.0) : 0.0;
        return LevyCollectionSummary(
          levyId: levy.id,
          title: levy.title,
          collected: collected,
          target: target,
          percentage: percentage,
          memberCount: levyObligations.length,
        );
      }).toList();
    },
  );
});

final expenseTotalProvider = Provider.autoDispose<AsyncValue<double>>((ref) {
  final expensesAsync = ref.watch(expensesStreamProvider);
  return expensesAsync.whenData((list) {
    final now = DateTime.now();
    return list
        .where((e) =>
            e.expenseDate.year == now.year && e.expenseDate.month == now.month)
        .fold<double>(0.0, (sum, e) => sum + e.amount);
  });
});

final treasurerFinancialSummaryProvider =
    Provider.autoDispose<AsyncValue<double>>((ref) {
  final collectedAsync = ref.watch(totalCollectedProvider);
  final expenseAsync = ref.watch(expenseTotalProvider);

  return _combine<double>([collectedAsync, expenseAsync], () {
    final collected = collectedAsync.valueOrNull ?? 0.0;
    final expenses = expenseAsync.valueOrNull ?? 0.0;
    return collected - expenses;
  });
});

// ---------------------------------------------------------------------------
// Main dashboard provider
// ---------------------------------------------------------------------------
final treasurerDashboardProvider =
    Provider.autoDispose<AsyncValue<TreasurerDashboardData>>((ref) {
  final collectedAsync = ref.watch(totalCollectedProvider);
  final outstandingAsync = ref.watch(totalOutstandingProvider);
  final pendingAsync = ref.watch(totalPendingProvider);
  final membersCountAsync = ref.watch(totalMembersProvider);
  final arrearsAsync = ref.watch(memberArrearsProvider);
  final levyAsync = ref.watch(levyCollectionProvider);
  final expenseAsync = ref.watch(expenseTotalProvider);
  final netAsync = ref.watch(treasurerFinancialSummaryProvider);
  final paymentsAsync = ref.watch(allPaymentsStreamProvider);
  final membersAsync = ref.watch(membersStreamProvider);

  return _combine<TreasurerDashboardData>(
    [
      collectedAsync,
      outstandingAsync,
      pendingAsync,
      membersCountAsync,
      arrearsAsync,
      levyAsync,
      expenseAsync,
      netAsync,
      paymentsAsync,
      membersAsync,
    ],
    () {
      final payments = paymentsAsync.valueOrNull ?? [];
      final members = membersAsync.valueOrNull ?? [];
      final sorted = [...payments]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final recent = sorted.take(5).map((p) {
        final member = members.firstWhere(
          (m) => m.userId == p.memberId || m.id == p.memberId,
          orElse: () => MemberModel(
            id: p.memberId,
            userId: p.memberId,
            fullName: 'Unknown',
            email: '',
            phoneNumber: '',
            dateOfBirth: DateTime(2000),
            joinedDate: DateTime(2000),
            createdAt: DateTime(2000),
            updatedAt: DateTime(2000),
          ),
        );
        return RecentPaymentItem(payment: p, memberName: member.fullName);
      }).toList();

      return TreasurerDashboardData(
        totalCollected: collectedAsync.valueOrNull ?? 0.0,
        totalOutstanding: outstandingAsync.valueOrNull ?? 0.0,
        totalPending: pendingAsync.valueOrNull ?? 0.0,
        totalMembers: membersCountAsync.valueOrNull ?? 0,
        memberArrears: arrearsAsync.valueOrNull ?? [],
        levyCollection: levyAsync.valueOrNull ?? [],
        expenseTotal: expenseAsync.valueOrNull ?? 0.0,
        netPosition: netAsync.valueOrNull ?? 0.0,
        recentPayments: recent,
      );
    },
  );
});
