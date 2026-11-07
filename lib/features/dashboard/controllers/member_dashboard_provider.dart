import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/payments/models/payment_model.dart';
import 'package:cls/features/payments/repositories/payment_repository.dart';
import 'package:cls/features/obligations/controllers/obligation_provider.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository();
});

final memberPaymentsStreamProvider = StreamProvider.autoDispose
    .family<List<PaymentModel>, String>((ref, memberId) {
      final auth = ref.watch(authProvider);
      if (auth.hasValue && auth.value == null) return const Stream.empty();
      return ref.watch(paymentRepositoryProvider).getMemberPayments(memberId);
    });

final memberTotalPaidProvider = Provider.autoDispose
    .family<AsyncValue<double>, String>((ref, memberId) {
      final asyncPayments = ref.watch(memberPaymentsStreamProvider(memberId));
      final asyncObligations = ref.watch(memberObligationsProvider(memberId));

      return asyncPayments.when(
        data: (payments) {
          final approvedPaymentsTotal = payments
              .where((p) => p.status == PaymentStatus.approved)
              .fold<double>(0.0, (sum, p) => sum + p.amount);

          final obligationsPaidTotal =
              asyncObligations.valueOrNull?.fold<double>(
                0.0,
                (sum, o) => sum + o.paidAmount,
              ) ??
              0.0;

          // Total paid is the total of approved payments recorded for this member,
          // or the total paid across obligations if manual status updates were applied.
          final total = approvedPaymentsTotal > obligationsPaidTotal
              ? approvedPaymentsTotal
              : obligationsPaidTotal;

          return AsyncValue.data(total);
        },
        loading: () => asyncObligations.when(
          data: (obs) => AsyncValue.data(
            obs.fold<double>(0.0, (sum, o) => sum + o.paidAmount),
          ),
          loading: () => const AsyncValue.loading(),
          error: (e, st) => AsyncValue.error(e, st),
        ),
        error: (err, st) => asyncObligations.when(
          data: (obs) => AsyncValue.data(
            obs.fold<double>(0.0, (sum, o) => sum + o.paidAmount),
          ),
          loading: () => const AsyncValue.loading(),
          error: (e, s) => AsyncValue.error(err, st),
        ),
      );
    });

final memberTotalOutstandingProvider = Provider.autoDispose
    .family<AsyncValue<double>, String>((ref, memberId) {
      final asyncObligations = ref.watch(memberObligationsProvider(memberId));
      return asyncObligations.whenData(
        (list) => list.fold(0.0, (sum, o) => sum + o.outstandingBalance),
      );
    });

final memberActiveLeviesProvider = Provider.autoDispose
    .family<AsyncValue<int>, String>((ref, memberId) {
      final asyncObligations = ref.watch(
        memberActiveObligationsProvider(memberId),
      );
      return asyncObligations.whenData((list) => list.length);
    });

final memberRecentPaymentsProvider = Provider.autoDispose
    .family<AsyncValue<List<PaymentModel>>, String>((ref, memberId) {
      final asyncPayments = ref.watch(memberPaymentsStreamProvider(memberId));
      return asyncPayments.whenData((list) {
        final sorted = [...list]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return sorted.take(5).toList();
      });
    });

final memberRegistrationFeeStatusProvider = Provider.autoDispose
    .family<AsyncValue<bool>, String>((ref, memberId) {
      final asyncObligations = ref.watch(memberObligationsProvider(memberId));
      return asyncObligations.whenData(
        (list) => !list.any((o) => o.outstandingBalance > 0.0),
      );
    });

/// Automatically reconciles all active/open dues and levies for a member
/// whenever they open or refresh their dashboard.
final memberObligationReconciliationProvider =
    FutureProvider.autoDispose.family<int, String>((ref, memberId) async {
      final user = ref.watch(authProvider).valueOrNull;
      final orgId = user?.organizationId;
      final repo = ref.watch(obligationRepositoryProvider);
      final count = await repo.reconcileMemberObligations(
        memberId,
        userId: user?.uid,
        organizationId: (orgId != null && orgId.isNotEmpty) ? orgId : null,
      );
      if (count > 0) {
        ref.invalidate(allObligationsProvider);
      }
      return count;
    });
