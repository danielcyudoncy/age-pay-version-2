// data/services/payment_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/payments/models/payment_model.dart';

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
    String? memberName,
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
    } catch (_) {
      // Direct Firestore fallback
      try {
        final now = DateTime.now();
        final allocations = obligationIds
            .map((id) => PaymentAllocationModel(
                  obligationId: id,
                  amount: amount /
                      (obligationIds.isNotEmpty ? obligationIds.length : 1),
                ))
            .toList();

        final docRef = FirebaseFirestore.instance.collection('payments').doc();
        final receiptId = 'RCP-${docRef.id.substring(0, 6).toUpperCase()}';
        final receiptNumber = 'REC-${now.millisecondsSinceEpoch}';

        final payment = PaymentModel(
          id: docRef.id,
          memberId: memberId,
          amount: amount,
          method: PaymentMethod.cash,
          status: PaymentStatus.approved,
          allocations: allocations,
          receiptUrl: null,
          notes: notes,
          verifiedBy: recordedBy,
          verifiedAt: now,
          createdAt: now,
        );

        final firestoreData = payment.toFirestore();
        firestoreData['receiptId'] = receiptId;
        firestoreData['receiptNumber'] = receiptNumber;

        await docRef.set(firestoreData);

        // Update obligations
        for (final obId in obligationIds) {
          final obRef =
              FirebaseFirestore.instance.collection('obligations').doc(obId);
          final obSnap = await obRef.get();
          if (obSnap.exists) {
            final obData = obSnap.data() ?? {};
            final currentPaid =
                (obData['paidAmount'] as num?)?.toDouble() ?? 0.0;
            final totalAmount = (obData['amount'] as num?)?.toDouble() ?? 0.0;
            final allocAmount = amount / obligationIds.length;
            final newPaid = currentPaid + allocAmount;
            final newObStatus = newPaid >= totalAmount
                ? 'paid'
                : (newPaid > 0 ? 'partial' : 'unpaid');
            await obRef.update({
              'paidAmount': newPaid,
              'status': newObStatus,
              'updatedAt': Timestamp.fromDate(now),
            });
          }
        }

        return CashPaymentResult(
          paymentId: docRef.id,
          receiptId: receiptId,
          receiptNumber: receiptNumber,
        );
      } catch (e) {
        throw PaymentException('Failed to record cash payment: $e');
      }
    }
  }

  @override
  Future<BankTransferResult> submitBankTransfer({
    required String memberId,
    String? memberName,
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
        'memberName': ?memberName,
        'obligationIds': obligationIds,
        'amount': amount,
        'transferReference': transferReference,
        'bankName': bankName,
        'receiptUrl': receiptUrl,
        'notes': notes,
      });

      final data = response.data as Map<String, dynamic>;
      return BankTransferResult(paymentId: data['paymentId'] ?? '');
    } catch (_) {
      // Fallback: write directly to Firestore so the user's payment is saved and can be verified by the treasurer
      try {
        final now = DateTime.now();
        final allocations = obligationIds
            .map((id) => PaymentAllocationModel(
                  obligationId: id,
                  amount: amount /
                      (obligationIds.isNotEmpty ? obligationIds.length : 1),
                ))
            .toList();

        // Resolve member name if not provided
        String? resolvedMemberName = memberName;
        if (resolvedMemberName == null || resolvedMemberName.isEmpty) {
          try {
            final memDoc = await FirebaseFirestore.instance
                .collection('members')
                .doc(memberId)
                .get();
            if (memDoc.exists) {
              resolvedMemberName = memDoc.data()?['fullName'] as String?;
            } else {
              final memByUid = await FirebaseFirestore.instance
                  .collection('members')
                  .where('userId', isEqualTo: memberId)
                  .limit(1)
                  .get();
              if (memByUid.docs.isNotEmpty) {
                resolvedMemberName =
                    memByUid.docs.first.data()['fullName'] as String?;
              } else {
                final userDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(memberId)
                    .get();
                if (userDoc.exists) {
                  resolvedMemberName =
                      userDoc.data()?['displayName'] as String?;
                }
              }
            }
          } catch (_) {
            // Ignore resolution error and proceed with write
          }
        }

        final docRef = FirebaseFirestore.instance.collection('payments').doc();
        final payment = PaymentModel(
          id: docRef.id,
          memberId: memberId,
          memberName: resolvedMemberName,
          amount: amount,
          method: PaymentMethod.bankTransfer,
          status: PaymentStatus.pending,
          allocations: allocations,
          receiptUrl: receiptUrl,
          transferProofUrl: receiptUrl,
          notes: notes,
          createdAt: now,
        );

        final firestoreData = payment.toFirestore();
        firestoreData['transferReference'] = transferReference;
        firestoreData['bankName'] = bankName;

        await docRef.set(firestoreData);

        return BankTransferResult(paymentId: docRef.id);
      } catch (firestoreError) {
        throw PaymentException(
            'Failed to submit bank transfer: $firestoreError');
      }
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
    } catch (_) {
      // Direct Firestore fallback
      try {
        final isApproved = action == 'approve';
        final now = DateTime.now();
        final paymentRef =
            FirebaseFirestore.instance.collection('payments').doc(paymentId);
        final paymentSnap = await paymentRef.get();
        final paymentData = paymentSnap.data() ?? {};

        final newStatus =
            isApproved ? PaymentStatus.approved : PaymentStatus.rejected;
        final receiptId =
            isApproved ? 'RCP-${paymentId.substring(0, 6).toUpperCase()}' : null;
        final receiptNumber =
            isApproved ? 'REC-${now.millisecondsSinceEpoch}' : null;

        final updates = <String, dynamic>{
          'status': newStatus.name,
          'verifiedBy': verifiedBy,
          'verifiedAt': Timestamp.fromDate(now),
        };
        if (receiptId != null) updates['receiptId'] = receiptId;
        if (receiptNumber != null) updates['receiptNumber'] = receiptNumber;
        if (notes != null && notes.isNotEmpty) updates['notes'] = notes;

        await paymentRef.update(updates);

        // If approved, update obligation statuses
        if (isApproved) {
          final allocations = (paymentData['allocations'] as List?) ?? [];
          for (final alloc in allocations) {
            final obId = alloc['obligationId'] as String?;
            final allocAmount = (alloc['amount'] as num?)?.toDouble() ?? 0.0;
            if (obId != null && obId.isNotEmpty) {
              final obRef = FirebaseFirestore.instance
                  .collection('obligations')
                  .doc(obId);
              final obSnap = await obRef.get();
              if (obSnap.exists) {
                final obData = obSnap.data() ?? {};
                final currentPaid =
                    (obData['paidAmount'] as num?)?.toDouble() ?? 0.0;
                final totalAmount =
                    (obData['amount'] as num?)?.toDouble() ?? 0.0;
                final newPaid = currentPaid + allocAmount;
                final newObStatus = newPaid >= totalAmount
                    ? 'paid'
                    : (newPaid > 0 ? 'partial' : 'unpaid');
                await obRef.update({
                  'paidAmount': newPaid,
                  'status': newObStatus,
                  'updatedAt': Timestamp.fromDate(now),
                });
              }
            }
          }
        }

        return VerifyPaymentResult(
          success: true,
          paymentId: paymentId,
          receiptId: receiptId,
        );
      } catch (e) {
        throw PaymentException('Payment verification failed: $e');
      }
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
