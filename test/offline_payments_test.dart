import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/obligations/models/obligation_model.dart';
import 'package:cls/features/payments/models/payment_model.dart';
import 'package:cls/features/payments/services/payment_service.dart';
import 'package:cls/features/payments/controllers/offline_payment_provider.dart';
import 'package:cls/features/payments/controllers/payment_provider.dart';
import 'package:cls/features/payments/views/cash_payment_screen.dart';
import 'package:cls/features/payments/views/payment_verification_screen.dart';
import 'package:cls/features/payments/views/bank_transfer_screen.dart';

class _MockPaymentService implements PaymentService {
  CashPaymentResult? _cashResult;
  BankTransferResult? _transferResult;
  VerifyPaymentResult? _verifyResult;
  Exception? _cashError;
  Exception? _transferError;
  Exception? _verifyError;

  void setCashResult(CashPaymentResult r) => _cashResult = r;
  void setTransferResult(BankTransferResult r) => _transferResult = r;
  void setVerifyResult(VerifyPaymentResult r) => _verifyResult = r;
  void setCashError(Exception e) => _cashError = e;
  void setTransferError(Exception e) => _transferError = e;
  void setVerifyError(Exception e) => _verifyError = e;

  @override
  Future<PaystackInitResult> initializePaystackPayment({
    required String email,
    required double amountNaira,
    required String reference,
    Map<String, dynamic>? metadata,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<PaystackVerifyResult> verifyPaystackTransaction({
    required String reference,
    required String memberId,
    required List<String> obligationIds,
    required double amountPaid,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<CashPaymentResult> recordCashPayment({
    required String memberId,
    required List<String> obligationIds,
    required double amount,
    String? notes,
    required String recordedBy,
  }) async {
    if (_cashError != null) throw _cashError!;
    return _cashResult ??
        CashPaymentResult(
          paymentId: 'pay_cash',
          receiptId: 'rcp_cash',
          receiptNumber: 'RCP-CASH-001',
        );
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
    if (_transferError != null) throw _transferError!;
    return _transferResult ?? BankTransferResult(paymentId: 'pay_transfer');
  }

  @override
  Future<VerifyPaymentResult> verifyPayment({
    required String paymentId,
    required String action,
    required String verifiedBy,
    String? notes,
  }) async {
    if (_verifyError != null) throw _verifyError!;
    return _verifyResult ??
        VerifyPaymentResult(
          success: true,
          paymentId: paymentId,
          receiptId: 'rcp_verify',
        );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testMember = MemberModel(
    id: 'member1',
    userId: 'user1',
    fullName: 'John Doe',
    email: 'john@example.com',
    phoneNumber: '08012345678',
    dateOfBirth: DateTime(1990, 1, 1),
    joinedDate: DateTime(2020, 1, 1),
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final testObligation = ObligationModel(
    id: 'obl1',
    memberId: 'user1',
    levyId: 'levy1',
    type: ObligationType.monthlyDue,
    title: 'June Due',
    description: 'Monthly contribution',
    amount: 5000,
    paidAmount: 0,
    outstandingBalance: 5000,
    status: ObligationStatus.unpaid,
    dueDate: DateTime(2026, 6, 30),
    createdAt: DateTime.now(),
  );

  final testPayment = PaymentModel(
    id: 'pay1',
    memberId: 'user1',
    amount: 5000,
    method: PaymentMethod.bankTransfer,
    status: PaymentStatus.pending,
    allocations: [PaymentAllocationModel(obligationId: 'obl1', amount: 5000)],
    transferProofUrl: 'https://example.com/receipt.jpg',
    paystackReference: 'TXN-001',
    createdAt: DateTime(2026, 6, 15),
  );

  group('OfflinePaymentNotifier', () {
    test('records cash payment successfully', () async {
      final mockService = _MockPaymentService();
      mockService.setCashResult(
        CashPaymentResult(
          paymentId: 'pay_test',
          receiptId: 'rcp_test',
          receiptNumber: 'RCP-001',
        ),
      );

      final notifier = OfflinePaymentNotifier(paymentService: mockService);

      await notifier.recordCashPayment(
        memberId: testMember.userId,
        obligationIds: [testObligation.id],
        amount: 5000,
        recordedBy: 'treasurer1',
      );

      expect(notifier.state.isSuccess, true);
      expect(notifier.state.paymentId, 'pay_test');
      expect(notifier.state.receiptNumber, 'RCP-001');
      expect(notifier.state.error, isNull);
    });

    test('handles cash payment error', () async {
      final mockService = _MockPaymentService();
      mockService.setCashError(PaymentException('Cash error'));

      final notifier = OfflinePaymentNotifier(paymentService: mockService);

      await notifier.recordCashPayment(
        memberId: testMember.userId,
        obligationIds: [testObligation.id],
        amount: 5000,
        recordedBy: 'treasurer1',
      );

      expect(notifier.state.isSuccess, false);
      expect(notifier.state.error, isNotNull);
    });

    test('submits bank transfer successfully', () async {
      final mockService = _MockPaymentService();
      mockService.setTransferResult(BankTransferResult(paymentId: 'pay_xfer'));

      final notifier = OfflinePaymentNotifier(paymentService: mockService);

      await notifier.submitBankTransfer(
        memberId: testMember.userId,
        obligationIds: [testObligation.id],
        amount: 5000,
        transferReference: 'TXN-REF-001',
        bankName: 'First Bank',
        receiptUrl: 'https://example.com/receipt.jpg',
      );

      expect(notifier.state.isSuccess, true);
      expect(notifier.state.paymentId, 'pay_xfer');
    });

    test('verifies payment successfully', () async {
      final mockService = _MockPaymentService();
      mockService.setVerifyResult(
        VerifyPaymentResult(
          success: true,
          paymentId: 'pay1',
          receiptId: 'rcp_v',
        ),
      );

      final notifier = OfflinePaymentNotifier(paymentService: mockService);

      await notifier.verifyPayment(
        paymentId: 'pay1',
        action: 'approve',
        verifiedBy: 'treasurer1',
      );

      expect(notifier.state.isSuccess, true);
      expect(notifier.state.paymentId, 'pay1');
    });

    test('reset clears state', () {
      final mockService = _MockPaymentService();
      final notifier = OfflinePaymentNotifier(paymentService: mockService);

      notifier.state = const OfflinePaymentState(
        isSuccess: true,
        paymentId: 'pay1',
        error: 'test error',
      );

      notifier.reset();

      expect(notifier.state.isSuccess, false);
      expect(notifier.state.paymentId, isNull);
      expect(notifier.state.error, isNull);
    });
  });

  group('CashPaymentScreen', () {
    Widget buildScreen() {
      final mockService = _MockPaymentService();
      return ProviderScope(
        overrides: [
          paymentServiceProvider.overrideWith((ref) => mockService),
          selectedObligationsProvider.overrideWith(
            (ref) => SelectedObligationsNotifier(),
          ),
        ],
        child: MaterialApp(home: CashPaymentScreen(recordedBy: 'treasurer1')),
      );
    }

    testWidgets('renders search field initially', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Record Cash Payment'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('shows empty state when no member selected', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(Center, 'Type at least 1 character to search'),
        findsOneWidget,
      );
    });
  });

  group('BankTransferScreen', () {
    Widget buildScreen() {
      final mockService = _MockPaymentService();
      return ProviderScope(
        overrides: [
          paymentServiceProvider.overrideWith((ref) => mockService),
          selectedObligationsProvider.overrideWith(
            (ref) => SelectedObligationsNotifier(),
          ),
        ],
        child: MaterialApp(home: BankTransferScreen(memberId: 'user1')),
      );
    }

    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Submit Bank Transfer'), findsOneWidget);
    });
  });

  group('PaymentVerificationScreen', () {
    Widget buildScreen({List<PaymentModel>? payments}) {
      final mockService = _MockPaymentService();
      return ProviderScope(
        overrides: [
          paymentServiceProvider.overrideWith((ref) => mockService),
          pendingPaymentsProvider.overrideWith(
            (ref) => Stream.value(payments ?? []),
          ),
        ],
        child: MaterialApp(
          home: PaymentVerificationScreen(verifiedBy: 'treasurer1'),
        ),
      );
    }

    testWidgets('renders title and empty state', (tester) async {
      await tester.pumpWidget(buildScreen(payments: []));
      await tester.pumpAndSettle();

      expect(find.text('Payment Verification'), findsOneWidget);
      expect(find.text('No pending payments'), findsOneWidget);
    });

    testWidgets('displays pending payments', (tester) async {
      await tester.pumpWidget(buildScreen(payments: [testPayment]));
      await tester.pumpAndSettle();

      expect(find.text('Bank Transfer'), findsOneWidget);
    });

    testWidgets('shows approve and reject buttons for bank transfer', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen(payments: [testPayment]));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(OutlinedButton, 'Approve'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Reject'), findsOneWidget);
    });

    testWidgets('shows payment details on tap', (tester) async {
      await tester.pumpWidget(buildScreen(payments: [testPayment]));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Card).first, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Payment Details'), findsOneWidget);
      expect(find.text('Allocated Obligations'), findsOneWidget);
    });
  });
}
