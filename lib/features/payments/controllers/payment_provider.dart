// features/payments/controllers/payment_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/data/models/obligation_model.dart';
import 'package:cls/data/services/payment_service.dart';

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return CloudFunctionPaymentService();
});

/// State for the online payment flow
class PaymentFlowState {
  final bool isInitializing;
  final bool isVerifying;
  final bool isSuccess;
  final String? authorizationUrl;
  final String? reference;
  final String? paymentId;
  final String? receiptNumber;
  final String? error;

  const PaymentFlowState({
    this.isInitializing = false,
    this.isVerifying = false,
    this.isSuccess = false,
    this.authorizationUrl,
    this.reference,
    this.paymentId,
    this.receiptNumber,
    this.error,
  });

  PaymentFlowState copyWith({
    bool? isInitializing,
    bool? isVerifying,
    bool? isSuccess,
    String? authorizationUrl,
    String? reference,
    String? paymentId,
    String? receiptNumber,
    String? error,
  }) {
    return PaymentFlowState(
      isInitializing: isInitializing ?? this.isInitializing,
      isVerifying: isVerifying ?? this.isVerifying,
      isSuccess: isSuccess ?? this.isSuccess,
      authorizationUrl: authorizationUrl ?? this.authorizationUrl,
      reference: reference ?? this.reference,
      paymentId: paymentId ?? this.paymentId,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      error: error ?? this.error,
    );
  }

  PaymentFlowState clearError() => copyWith(error: null);
}

class PaymentFlowNotifier extends StateNotifier<PaymentFlowState> {
  final PaymentService _paymentService;

  PaymentFlowNotifier({required PaymentService paymentService})
    : _paymentService = paymentService,
      super(const PaymentFlowState());

  /// Initialize a Paystack payment and return the authorization URL
  Future<void> initializePayment({
    required String email,
    required double amountNaira,
    required String memberId,
    required List<ObligationModel> obligations,
  }) async {
    state = state.copyWith(isInitializing: true, error: null, isSuccess: false);

    try {
      final reference =
          'PAY-$memberId-${DateTime.now().millisecondsSinceEpoch}';
      final metadata = {
        'memberId': memberId,
        'obligationIds': obligations.map((o) => o.id).toList(),
        'cancel_action': 'https://example.com/cancel',
      };

      final result = await _paymentService.initializePaystackPayment(
        email: email,
        amountNaira: amountNaira,
        reference: reference,
        metadata: metadata,
      );

      state = state.copyWith(
        isInitializing: false,
        authorizationUrl: result.authorizationUrl,
        reference: result.reference,
      );
    } catch (e) {
      state = state.copyWith(isInitializing: false, error: e.toString());
    }
  }

  /// Verify a completed Paystack transaction
  Future<void> verifyPayment({
    required String reference,
    required String memberId,
    required List<String> obligationIds,
    required double amountPaid,
  }) async {
    state = state.copyWith(isVerifying: true, error: null);

    try {
      final result = await _paymentService.verifyPaystackTransaction(
        reference: reference,
        memberId: memberId,
        obligationIds: obligationIds,
        amountPaid: amountPaid,
      );

      state = state.copyWith(
        isVerifying: false,
        isSuccess: true,
        paymentId: result.paymentId,
        receiptNumber: result.receiptNumber,
      );
    } catch (e) {
      state = state.copyWith(isVerifying: false, error: e.toString());
    }
  }

  void reset() {
    state = const PaymentFlowState();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void markUrlOpened() {
    // Once the webview is opened, we enter verification-ready state
    state = state.copyWith(isInitializing: false);
  }
}

final paymentFlowProvider =
    StateNotifierProvider.autoDispose<PaymentFlowNotifier, PaymentFlowState>((
      ref,
    ) {
      return PaymentFlowNotifier(
        paymentService: ref.watch(paymentServiceProvider),
      );
    });
