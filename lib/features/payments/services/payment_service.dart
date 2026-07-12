// data/services/payment_service.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cls/core/constants/enums.dart';

/// Result from payment initialization
class PaymentInitResult {
  final String authorizationUrl;
  final String accessCode;
  final String reference;

  PaymentInitResult({
    required this.authorizationUrl,
    required this.accessCode,
    required this.reference,
  });
}

/// Result from payment verification
class PaymentVerifyResult {
  final String paymentId;
  final String receiptId;
  final String receiptNumber;
  final double verifiedAmount;
  final String status;

  PaymentVerifyResult({
    required this.paymentId,
    required this.receiptId,
    required this.receiptNumber,
    required this.verifiedAmount,
    required this.status,
  });
}

abstract class PaymentService {
  /// Initialize an online payment via Cloud Function.
  /// Returns the authorization URL to open in a webview/browser.
  Future<PaymentInitResult> initializePayment({
    required PaymentProvider provider,
    required String email,
    required double amountNaira,
    required String reference,
    Map<String, dynamic>? metadata,
  });

  /// Verify an online payment via Cloud Function.
  /// Records payment, updates obligations, generates receipt.
  Future<PaymentVerifyResult> verifyPayment({
    required PaymentProvider provider,
    required String reference,
    required String memberId,
    required List<String> obligationIds,
    required double amountPaid,
  });

  /// Record a cash payment via Cloud Function.
  /// Creates an APPROVED payment, updates obligations, generates receipt.
  Future<CashPaymentResult> recordCashPayment({
    required String memberId,
    required List<String> obligationIds,
    required double amount,
    String? notes,
    required String recordedBy,
  });

  /// Submit a bank transfer payment via Cloud Function.
  /// Creates a PENDING payment awaiting treasurer verification.
  Future<BankTransferResult> submitBankTransfer({
    required String memberId,
    required List<String> obligationIds,
    required double amount,
    required String transferReference,
    required String bankName,
    required String receiptUrl,
    String? notes,
  });

  /// Verify (approve or reject) a pending payment via Cloud Function.
  Future<VerifyPaymentResult> verifyPendingPayment({
    required String paymentId,
    required String action,
    required String verifiedBy,
    String? notes,
  });
}

class CloudFunctionPaymentService implements PaymentService {
  final FirebaseFunctions _functions;

  CloudFunctionPaymentService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  @override
  Future<PaymentInitResult> initializePayment({
    required PaymentProvider provider,
    required String email,
    required double amountNaira,
    required String reference,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final callableName = _getInitializeCallableName(provider);
      final callable = _functions.httpsCallable(callableName);
      final response = await callable.call({
        'email': email,
        'amountNaira': amountNaira,
        'reference': reference,
        'metadata': metadata,
      });

      final data = response.data as Map<String, dynamic>;
      return PaymentInitResult(
        authorizationUrl: data['authorizationUrl'] ?? '',
        accessCode: data['accessCode'] ?? '',
        reference: data['reference'] ?? reference,
      );
    } on FirebaseFunctionsException catch (e) {
      throw PaymentException(e.message ?? 'Payment initialization failed');
    } catch (e) {
      throw PaymentException(e.toString());
    }
  }

  @override
  Future<PaymentVerifyResult> verifyPayment({
    required PaymentProvider provider,
    required String reference,
    required String memberId,
    required List<String> obligationIds,
    required double amountPaid,
  }) async {
    try {
      final callableName = _getVerifyCallableName(provider);
      final callable = _functions.httpsCallable(callableName);
      final response = await callable.call({
        'reference': reference,
        'memberId': memberId,
        'obligationIds': obligationIds,
        'amountPaid': amountPaid,
      });

      final data = response.data as Map<String, dynamic>;
      return PaymentVerifyResult(
        paymentId: data['paymentId'] ?? '',
        receiptId: data['receiptId'] ?? '',
        receiptNumber: data['receiptNumber'] ?? '',
        verifiedAmount: (data['verifiedAmount'] as num?)?.toDouble() ?? 0.0,
        status: data['status'] ?? 'pending',
      );
    } on FirebaseFunctionsException catch (e) {
      throw PaymentException(e.message ?? 'Payment verification failed');
    } catch (e) {
      throw PaymentException(e.toString());
    }
  }

  String _getInitializeCallableName(PaymentProvider provider) {
    switch (provider) {
      case PaymentProvider.paystack:
        return 'initializePaystackPayment';
      case PaymentProvider.flutterwave:
        return 'initializeFlutterwavePayment';
    }
  }

  String _getVerifyCallableName(PaymentProvider provider) {
    switch (provider) {
      case PaymentProvider.paystack:
        return 'verifyPaystackTransaction';
      case PaymentProvider.flutterwave:
        return 'verifyFlutterwaveTransaction';
    }
  }

  @override
  Future<CashPaymentResult> recordCashPayment({
    required String memberId,
    required List<String> obligationIds,
    required double amount,
    String? notes,
    required String recordedBy,
  }) async {
    try {
      final callable = _functions.httpsCallable('recordCashPayment');
      final response = await callable.call({
        'memberId': memberId,
        'obligationIds': obligationIds,
        'amount': amount,
        'notes': notes,
        'recordedBy': recordedBy,
      });

      final data = response.data as Map<String, dynamic>;
      return CashPaymentResult(
        paymentId: data['paymentId'] ?? '',
        receiptId: data['receiptId'] ?? '',
        receiptNumber: data['receiptNumber'] ?? '',
      );
    } on FirebaseFunctionsException catch (e) {
      throw PaymentException(e.message ?? 'Failed to record cash payment');
    } catch (e) {
      throw PaymentException(e.toString());
    }
  }

  @override
  Future<BankTransferResult> submitBankTransfer({
    required String memberId,
    required List<String> obligationIds,
    required double amount,
    required String transferReference,
    required String bankName,
    required String receiptUrl,
    String? notes,
  }) async {
    try {
      final callable = _functions.httpsCallable('submitBankTransfer');
      final response = await callable.call({
        'memberId': memberId,
        'obligationIds': obligationIds,
        'amount': amount,
        'transferReference': transferReference,
        'bankName': bankName,
        'receiptUrl': receiptUrl,
        'notes': notes,
      });

      final data = response.data as Map<String, dynamic>;
      return BankTransferResult(paymentId: data['paymentId'] ?? '');
    } on FirebaseFunctionsException catch (e) {
      throw PaymentException(e.message ?? 'Failed to submit bank transfer');
    } catch (e) {
      throw PaymentException(e.toString());
    }
  }

  @override
  Future<VerifyPaymentResult> verifyPendingPayment({
    required String paymentId,
    required String action,
    required String verifiedBy,
    String? notes,
  }) async {
    try {
      final callable = _functions.httpsCallable('verifyPayment');
      final response = await callable.call({
        'paymentId': paymentId,
        'action': action,
        'verifiedBy': verifiedBy,
        'notes': notes,
      });

      final data = response.data as Map<String, dynamic>;
      return VerifyPaymentResult(
        success: data['success'] ?? false,
        paymentId: data['paymentId'] ?? paymentId,
        receiptId: data['receiptId'],
      );
    } on FirebaseFunctionsException catch (e) {
      throw PaymentException(e.message ?? 'Payment verification failed');
    } catch (e) {
      throw PaymentException(e.toString());
    }
  }
}

class PaymentException implements Exception {
  final String message;
  PaymentException(this.message);

  @override
  String toString() => message;
}

/// Result from recording a cash payment
class CashPaymentResult {
  final String paymentId;
  final String receiptId;
  final String receiptNumber;

  CashPaymentResult({
    required this.paymentId,
    required this.receiptId,
    required this.receiptNumber,
  });
}

/// Result from submitting a bank transfer
class BankTransferResult {
  final String paymentId;

  BankTransferResult({required this.paymentId});
}

/// Result from verifying a payment
class VerifyPaymentResult {
  final bool success;
  final String paymentId;
  final String? receiptId;

  VerifyPaymentResult({
    required this.success,
    required this.paymentId,
    this.receiptId,
  });
}
