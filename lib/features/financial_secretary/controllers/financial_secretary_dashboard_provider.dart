import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/obligations/models/obligation_model.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/payments/models/payment_model.dart';
import 'package:cls/features/obligations/controllers/obligation_provider.dart';
import 'package:cls/features/levies/controllers/levy_provider.dart'
    hide obligationRepositoryProvider;
import 'package:cls/features/dashboard/controllers/treasurer_dashboard_provider.dart'
    show
        allPaymentsStreamProvider,
        membersStreamProvider,
        MemberArrears,
        LevyCollectionSummary,
        RecentPaymentItem;

class FinancialSecretaryDashboardData {
  final double totalCollected;
  final double totalOutstanding;
  final double cashCollected;
  final double bankCollected;
  final double onlineCollected;
  final int pendingVerificationsCount;
  final int totalMembers;
  final List<MemberArrears> memberArrears;
  final List<LevyCollectionSummary> levySummaries;
  final List<RecentPaymentItem> recentPayments;

  const FinancialSecretaryDashboardData({
    required this.totalCollected,
    required this.totalOutstanding,
    required this.cashCollected,
    required this.bankCollected,
    required this.onlineCollected,
    required this.pendingVerificationsCount,
    required this.totalMembers,
    required this.memberArrears,
    required this.levySummaries,
    required this.recentPayments,
  });
}

final financialSecretaryDashboardProvider =
    Provider.autoDispose<AsyncValue<FinancialSecretaryDashboardData>>((ref) {
      final paymentsAsync = ref.watch(allPaymentsStreamProvider);
      final obligationsAsync = ref.watch(allObligationsProvider);
      final leviesAsync = ref.watch(activeLeviesProvider);
      final membersAsync = ref.watch(membersStreamProvider);

      final inputs = [paymentsAsync, obligationsAsync, leviesAsync, membersAsync];
      for (final input in inputs) {
        if (input is AsyncLoading) return const AsyncValue.loading();
      }
      for (final input in inputs) {
        if (input.hasError) {
          return AsyncValue.error(
            input.error!,
            input.stackTrace ?? StackTrace.current,
          );
        }
      }

      try {
        final payments = paymentsAsync.valueOrNull ?? [];
        final obligations = obligationsAsync.valueOrNull ?? [];
        final levies = leviesAsync.valueOrNull ?? [];
        final members = membersAsync.valueOrNull ?? [];

        // Total collected from obligations
        final totalCollected = obligations.fold<double>(
          0.0,
          (sum, o) => sum + o.paidAmount,
        );

        // Total outstanding dues
        final totalOutstanding = obligations
            .where((o) => o.status != ObligationStatus.paid)
            .fold<double>(0.0, (sum, o) => sum + o.outstandingBalance);

        // Channel breakdown
        double cashCollected = 0.0;
        double bankCollected = 0.0;
        double onlineCollected = 0.0;
        int pendingCount = 0;

        for (final p in payments) {
          if (p.status == PaymentStatus.pending) {
            pendingCount++;
          }
          if (p.status == PaymentStatus.approved) {
            switch (p.method) {
              case PaymentMethod.cash:
                cashCollected += p.amount;
                break;
              case PaymentMethod.bankTransfer:
                bankCollected += p.amount;
                break;
              case PaymentMethod.online:
                onlineCollected += p.amount;
                break;
            }
          }
        }

        // Member ID mapping (docId & userId)
        final memberByDocId = <String, MemberModel>{};
        final memberByUserId = <String, String>{};
        for (final m in members) {
          memberByDocId[m.id] = m;
          if (m.userId.isNotEmpty) {
            memberByUserId[m.userId] = m.id;
          }
        }

        // Member arrears (Debtors list)
        final memberObligations = <String, List<ObligationModel>>{};
        for (final o in obligations) {
          if (o.outstandingBalance <= 0) continue;
          String resolvedMemberId = o.memberId;
          if (!memberByDocId.containsKey(o.memberId) &&
              memberByUserId.containsKey(o.memberId)) {
            resolvedMemberId = memberByUserId[o.memberId]!;
          }
          (memberObligations[resolvedMemberId] ??= []).add(o);
        }

        final memberArrears = memberObligations.entries.map((e) {
          final member = memberByDocId[e.key];
          final totalOutstanding = e.value.fold<double>(
            0.0,
            (sum, o) => sum + o.outstandingBalance,
          );
          return MemberArrears(
            memberId: e.key,
            memberName: member?.fullName ?? 'Unknown Member',
            totalOutstanding: totalOutstanding,
            unpaidCount: e.value
                .where((o) => o.status != ObligationStatus.paid)
                .length,
          );
        }).toList();
        memberArrears.sort(
          (a, b) => b.totalOutstanding.compareTo(a.totalOutstanding),
        );

        // Levies progress summary
        final levySummaries = <LevyCollectionSummary>[];
        final accountedTitles = <String>{};

        for (final levy in levies) {
          accountedTitles.add(levy.title.trim().toLowerCase());
          final levyObligations = obligations
              .where((o) =>
                  o.levyId == levy.id ||
                  (o.levyId.isEmpty &&
                      o.title.trim().toLowerCase() ==
                          levy.title.trim().toLowerCase()))
              .toList();
          final target = levyObligations.fold<double>(
            0.0,
            (sum, o) => sum + o.amount,
          );
          final collected = levyObligations.fold<double>(
            0.0,
            (sum, o) => sum + o.paidAmount,
          );
          final percentage = target > 0 ? (collected / target) : 0.0;
          levySummaries.add(LevyCollectionSummary(
            levyId: levy.id,
            title: levy.title,
            collected: collected,
            target: target,
            percentage: percentage,
            memberCount: levyObligations.length,
          ));
        }

        final remainingObligations = obligations.where(
          (o) => !accountedTitles.contains(o.title.trim().toLowerCase()),
        );

        final groupedObligations = <String, List<ObligationModel>>{};
        for (final o in remainingObligations) {
          final t = o.title.trim();
          if (t.isEmpty) continue;
          groupedObligations.putIfAbsent(t, () => []).add(o);
        }

        for (final entry in groupedObligations.entries) {
          final title = entry.key;
          final list = entry.value;
          final target = list.fold<double>(0.0, (sum, o) => sum + o.amount);
          final collected = list.fold<double>(0.0, (sum, o) => sum + o.paidAmount);
          final percentage = target > 0 ? (collected / target) : 0.0;

          levySummaries.add(LevyCollectionSummary(
            levyId: 'derived_$title',
            title: title,
            collected: collected,
            target: target,
            percentage: percentage,
            memberCount: list.length,
          ));
        }

        // Recent payments
        final sortedPayments = List<PaymentModel>.from(payments)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final recentPayments = sortedPayments.take(15).map((p) {
          String resolvedId = p.memberId;
          if (!memberByDocId.containsKey(p.memberId) &&
              memberByUserId.containsKey(p.memberId)) {
            resolvedId = memberByUserId[p.memberId]!;
          }
          final member = memberByDocId[resolvedId];
          return RecentPaymentItem(
            payment: p,
            memberName: member?.fullName ?? 'Unknown Member',
          );
        }).toList();

        return AsyncValue.data(
          FinancialSecretaryDashboardData(
            totalCollected: totalCollected,
            totalOutstanding: totalOutstanding,
            cashCollected: cashCollected,
            bankCollected: bankCollected,
            onlineCollected: onlineCollected,
            pendingVerificationsCount: pendingCount,
            totalMembers: members.length,
            memberArrears: memberArrears,
            levySummaries: levySummaries,
            recentPayments: recentPayments,
          ),
        );
      } catch (e, st) {
        return AsyncValue.error(e, st);
      }
    });
