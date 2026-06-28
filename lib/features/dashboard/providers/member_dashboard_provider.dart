import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/data/models/payment_model.dart';
import 'package:cls/data/repositories/payment_repository.dart';
import 'package:cls/features/obligations/providers/obligation_provider.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository();
});

final memberPaymentsStreamProvider = StreamProvider.autoDispose
    .family<List<PaymentModel>, String>((ref, memberId) {
      return ref.watch(paymentRepositoryProvider).getMemberPayments(memberId);
    });

final memberTotalPaidProvider = Provider.autoDispose
    .family<AsyncValue<double>, String>((ref, memberId) {
      final asyncObligations = ref.watch(memberObligationsProvider(memberId));
      return asyncObligations.whenData(
        (list) => list.fold(0.0, (sum, o) => sum + o.paidAmount),
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
        (list) => list.any(
          (o) =>
              o.type == ObligationType.registrationFee &&
              o.status == ObligationStatus.paid,
        ),
      );
    });
