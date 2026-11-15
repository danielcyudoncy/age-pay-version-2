import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/dashboard/controllers/treasurer_dashboard_provider.dart'
    show allPaymentsStreamProvider, membersStreamProvider;
import 'package:cls/features/obligations/controllers/obligation_provider.dart'
    show allObligationsProvider;
import 'package:cls/features/meetings/controllers/meeting_provider.dart'
    show meetingsStreamProvider;
import '../models/sitting_collection_model.dart';

enum SittingScopeMode {
  today,
  customDate,
  allTime,
}

/// Selected mode for filtering sitting collections (today, custom date, or all time).
final sittingScopeModeProvider =
    StateProvider.autoDispose<SittingScopeMode>((ref) => SittingScopeMode.today);

/// Selected calendar date for sitting collection calculation. Defaults to today.
final selectedSittingDateProvider =
    StateProvider.autoDispose<DateTime>((ref) => DateTime.now());

/// Selected meeting title if the user chose a specific sitting from the meetings register.
final selectedSittingMeetingTitleProvider =
    StateProvider.autoDispose<String?>((ref) => null);

/// Aggregates and calculates collections for the selected sitting / day.
final sittingCollectionSummaryProvider =
    Provider.autoDispose<AsyncValue<SittingCollectionModel>>((ref) {
  final paymentsAsync = ref.watch(allPaymentsStreamProvider);
  final obligationsAsync = ref.watch(allObligationsProvider);
  final membersAsync = ref.watch(membersStreamProvider);
  final meetingsAsync = ref.watch(meetingsStreamProvider);

  if (paymentsAsync is AsyncLoading ||
      obligationsAsync is AsyncLoading ||
      membersAsync is AsyncLoading) {
    return const AsyncValue.loading();
  }

  if (paymentsAsync.hasError) {
    return AsyncValue.error(paymentsAsync.error!, paymentsAsync.stackTrace ?? StackTrace.current);
  }

  try {
    final payments = paymentsAsync.valueOrNull ?? [];
    final obligations = obligationsAsync.valueOrNull ?? [];
    final members = membersAsync.valueOrNull ?? [];
    final meetings = meetingsAsync.valueOrNull ?? [];

    final scopeMode = ref.watch(sittingScopeModeProvider);
    final targetDate = ref.watch(selectedSittingDateProvider);
    var meetingTitle = ref.watch(selectedSittingMeetingTitleProvider);

    // Auto-detect meeting title if none explicitly picked and a meeting is scheduled on targetDate
    if (meetingTitle == null && meetings.isNotEmpty) {
      final matchingMeeting = meetings.where((m) =>
          m.meetingDate.year == targetDate.year &&
          m.meetingDate.month == targetDate.month &&
          m.meetingDate.day == targetDate.day).firstOrNull;
      if (matchingMeeting != null) {
        meetingTitle = matchingMeeting.title;
      }
    }

    // Filter payments for the selected day unless in allTime mode
    final sittingPayments = payments.where((p) {
      if (scopeMode == SittingScopeMode.allTime) return true;
      final isSameDay = p.createdAt.year == targetDate.year &&
          p.createdAt.month == targetDate.month &&
          p.createdAt.day == targetDate.day;
      if (isSameDay) return true;
      // Match if linked directly to a meeting occurring on the target date
      if (p.meetingId != null &&
          meetings.any((m) =>
              m.id == p.meetingId &&
              m.meetingDate.year == targetDate.year &&
              m.meetingDate.month == targetDate.month &&
              m.meetingDate.day == targetDate.day)) {
        return true;
      }
      return false;
    }).toList();

    // Map members by docId and userId
    final memberMap = <String, String>{};
    for (final m in members) {
      memberMap[m.id] = m.fullName;
      if (m.userId.isNotEmpty) {
        memberMap[m.userId] = m.fullName;
      }
    }

    // Map obligations by id
    final obligationMap = <String, String>{};
    for (final o in obligations) {
      obligationMap[o.id] = o.title;
    }

    double totalCollected = 0.0;
    double cashCollected = 0.0;
    double bankCollected = 0.0;
    double onlineCollected = 0.0;
    final uniqueMemberIds = <String>{};
    final levyTotals = <String, double>{};
    final levyCounts = <String, int>{};
    final contributors = <SittingContributor>[];

    for (final p in sittingPayments) {
      if (p.status != PaymentStatus.approved) continue;

      totalCollected += p.amount;
      uniqueMemberIds.add(p.memberId);

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

      // Breakdown by levy from allocations
      if (p.allocations.isNotEmpty) {
        for (final a in p.allocations) {
          final title = obligationMap[a.obligationId] ??
              (p.notes?.trim().isNotEmpty == true ? p.notes!.trim() : 'General Dues/Levy');
          levyTotals[title] = (levyTotals[title] ?? 0.0) + a.amount;
          levyCounts[title] = (levyCounts[title] ?? 0) + 1;
        }
      } else {
        final title = (p.notes != null && p.notes!.trim().isNotEmpty)
            ? p.notes!.trim()
            : 'General Contribution';
        levyTotals[title] = (levyTotals[title] ?? 0.0) + p.amount;
        levyCounts[title] = (levyCounts[title] ?? 0) + 1;
      }

      final resolvedName = memberMap[p.memberId] ??
          (p.memberName?.isNotEmpty == true ? p.memberName! : 'Member (${p.memberId.substring(0, p.memberId.length.clamp(0, 6))})');

      contributors.add(
        SittingContributor(
          memberId: p.memberId,
          memberName: resolvedName,
          amount: p.amount,
          method: p.method,
          time: p.createdAt,
          notes: p.notes,
        ),
      );
    }

    // Sort contributors descending by amount
    contributors.sort((a, b) => b.amount.compareTo(a.amount));

    final levyBreakdowns = levyTotals.entries.map((e) {
      return SittingLevyBreakdown(
        title: e.key,
        amount: e.value,
        count: levyCounts[e.key] ?? 1,
      );
    }).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final model = SittingCollectionModel(
      date: targetDate,
      meetingTitle: meetingTitle,
      totalCollected: totalCollected,
      cashCollected: cashCollected,
      bankCollected: bankCollected,
      onlineCollected: onlineCollected,
      totalTransactions: contributors.length,
      uniqueContributorsCount: uniqueMemberIds.length,
      levyBreakdowns: levyBreakdowns,
      contributors: contributors,
      rawPayments: sittingPayments,
    );

    return AsyncValue.data(model);
  } catch (e, st) {
    return AsyncValue.error(e, st);
  }
});
