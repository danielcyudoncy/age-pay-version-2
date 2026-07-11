// features/payments/controllers/offline_payment_provider.dart
import 'package:cls/features/payments/controllers/payment_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/features/payments/models/payment_model.dart';
import 'package:cls/features/obligations/models/obligation_model.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/dashboard/controllers/member_dashboard_provider.dart'
    show paymentRepositoryProvider;
import 'package:cls/features/dashboard/controllers/treasurer_dashboard_provider.dart'
    show memberRepositoryProvider;

import 'package:cls/features/payments/services/payment_service.dart';

// Pending payments stream provider
final pendingPaymentsProvider = StreamProvider.autoDispose<List<PaymentModel>>((
  ref,
) {
  final repo = ref.watch(paymentRepositoryProvider);
  return repo.getPendingPayments();
});

// Search members provider
final memberSearchProvider = FutureProvider.autoDispose
    .family<List<MemberModel>, String>((ref, query) async {
      if (query.trim().isEmpty) return [];
      final repo = ref.watch(memberRepositoryProvider);
      return repo.searchMembers(query);
    });

/// Union type for offline payment operations
enum OfflinePaymentType { idle, cash, bankTransfer, verification }

/// State for offline payment flows
class OfflinePaymentState {
  final OfflinePaymentType type;
  final bool isLoading;
  final bool isSuccess;
  final String? paymentId;
  final String? receiptId;
  final String? receiptNumber;
  final String? error;

  const OfflinePaymentState({
    this.type = OfflinePaymentType.idle,
    this.isLoading = false,
    this.isSuccess = false,
    this.paymentId,
    this.receiptId,
    this.receiptNumber,
    this.error,
  });

  OfflinePaymentState copyWith({
    OfflinePaymentType? type,
    bool? isLoading,
    bool? isSuccess,
    String? paymentId,
    String? receiptId,
    String? receiptNumber,
    String? error,
  }) {
    return OfflinePaymentState(
      type: type ?? this.type,
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      paymentId: paymentId ?? this.paymentId,
      receiptId: receiptId ?? this.receiptId,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      error: error,
    );
  }

  OfflinePaymentState clearSuccess() => copyWith(
    isSuccess: false,
    paymentId: null,
    receiptId: null,
    receiptNumber: null,
  );

  OfflinePaymentState clearError() => copyWith(error: null);
}

class OfflinePaymentNotifier extends StateNotifier<OfflinePaymentState> {
  final PaymentService _paymentService;

  OfflinePaymentNotifier({required PaymentService paymentService})
    : _paymentService = paymentService,
      super(const OfflinePaymentState());

  /// Record a cash payment (treasurer only)
  Future<void> recordCashPayment({
    required String memberId,
    required List<String> obligationIds,
    required double amount,
    String? notes,
    required String recordedBy,
  }) async {
    state = state.copyWith(
      type: OfflinePaymentType.cash,
      isLoading: true,
      error: null,
      isSuccess: false,
    );

    try {
      final result = await _paymentService.recordCashPayment(
        memberId: memberId,
        obligationIds: obligationIds,
        amount: amount,
        notes: notes,
        recordedBy: recordedBy,
      );

      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        paymentId: result.paymentId,
        receiptId: result.receiptId,
        receiptNumber: result.receiptNumber,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isSuccess: false,
        error: e.toString(),
      );
    }
  }

  /// Submit a bank transfer (member)
  Future<void> submitBankTransfer({
    required String memberId,
    required List<String> obligationIds,
    required double amount,
    required String transferReference,
    required String bankName,
    required String receiptUrl,
    String? notes,
  }) async {
    state = state.copyWith(
      type: OfflinePaymentType.bankTransfer,
      isLoading: true,
      error: null,
      isSuccess: false,
    );

    try {
      final result = await _paymentService.submitBankTransfer(
        memberId: memberId,
        obligationIds: obligationIds,
        amount: amount,
        transferReference: transferReference,
        bankName: bankName,
        receiptUrl: receiptUrl,
        notes: notes,
      );

      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        paymentId: result.paymentId,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isSuccess: false,
        error: e.toString(),
      );
    }
  }

  /// Verify (approve or reject) a pending payment (treasurer only)
  Future<void> verifyPayment({
    required String paymentId,
    required String action,
    required String verifiedBy,
    String? notes,
  }) async {
    state = state.copyWith(
      type: OfflinePaymentType.verification,
      isLoading: true,
      error: null,
      isSuccess: false,
    );

    try {
      final result = await _paymentService.verifyPayment(
        paymentId: paymentId,
        action: action,
        verifiedBy: verifiedBy,
        notes: notes,
      );

      state = state.copyWith(
        isLoading: false,
        isSuccess: result.success,
        paymentId: result.paymentId,
        receiptId: result.receiptId,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isSuccess: false,
        error: e.toString(),
      );
    }
  }

  void reset() {
    state = const OfflinePaymentState();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for the offline payment notifier
final offlinePaymentProvider =
    StateNotifierProvider.autoDispose<
      OfflinePaymentNotifier,
      OfflinePaymentState
    >((ref) {
      final paymentService = ref.watch(paymentServiceProvider);
      return OfflinePaymentNotifier(paymentService: paymentService);
    });

class SelectedObligationsNotifier extends StateNotifier<List<ObligationModel>> {
  SelectedObligationsNotifier() : super([]);

  void toggle(ObligationModel obligation) {
    if (state.any((o) => o.id == obligation.id)) {
      state = state.where((o) => o.id != obligation.id).toList();
    } else {
      state = [...state, obligation];
    }
  }

  void setAll(List<ObligationModel> obligations) {
    state = obligations;
  }

  void clear() {
    state = [];
  }
}

/// Provider for selected obligations during payment creation
final selectedObligationsProvider =
    StateNotifierProvider.autoDispose<
      SelectedObligationsNotifier,
      List<ObligationModel>
    >((ref) {
      return SelectedObligationsNotifier();
    });
