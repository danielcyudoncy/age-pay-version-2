import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/obligations/models/obligation_model.dart';
import 'package:cls/features/payments/models/payment_model.dart';
import 'package:cls/features/obligations/repositories/obligation_repository.dart';
import 'package:cls/features/payments/services/payment_service.dart';
import 'package:cls/features/payments/controllers/payment_provider.dart';
import 'package:cls/features/payments/views/make_payment_screen.dart';
import 'package:cls/features/payments/views/payment_history_screen.dart';
import 'package:cls/features/obligations/controllers/obligation_provider.dart';
import 'package:cls/features/receipts/controllers/receipt_provider.dart';
import 'package:cls/features/receipts/repositories/receipt_repository.dart';
import 'package:cls/features/receipts/models/receipt_model.dart';

class _MockPaymentService implements PaymentService {
  PaystackInitResult? _initResult;
  PaystackVerifyResult? _verifyResult;
  Exception? _initError;
  Exception? _verifyError;

  void setInitResult(PaystackInitResult result) => _initResult = result;
  void setVerifyResult(PaystackVerifyResult result) => _verifyResult = result;
  void setInitError(Exception e) => _initError = e;
  void setVerifyError(Exception e) => _verifyError = e;

  @override
  Future<PaystackInitResult> initializePaystackPayment({
    required String email,
    required double amountNaira,
    required String reference,
    Map<String, dynamic>? metadata,
  }) async {
    if (_initError != null) throw _initError!;
    return _initResult ??
        PaystackInitResult(
          authorizationUrl: 'https://paystack.com/pay/test',
          accessCode: 'acc_test',
          reference: reference,
        );
  }

  @override
  Future<PaystackVerifyResult> verifyPaystackTransaction({
    required String reference,
    required String memberId,
    required List<String> obligationIds,
    required double amountPaid,
  }) async {
    if (_verifyError != null) throw _verifyError!;
    return _verifyResult ??
        PaystackVerifyResult(
          paymentId: 'pay_test',
          receiptId: 'rcp_test',
          receiptNumber: 'RCP-001',
          verifiedAmount: amountPaid,
          status: 'approved',
        );
  }

  @override
  Future<CashPaymentResult> recordCashPayment({
    required String memberId,
    required List<String> obligationIds,
    required double amount,
    String? notes,
    required String recordedBy,
  }) async {
    return CashPaymentResult(
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
    return BankTransferResult(paymentId: 'pay_xfer');
  }

  @override
  Future<VerifyPaymentResult> verifyPayment({
    required String paymentId,
    required String action,
    required String verifiedBy,
    String? notes,
  }) async {
    return VerifyPaymentResult(
      success: true,
      paymentId: paymentId,
      receiptId: 'rcp_v',
    );
  }
}

class _MockReceiptRepository implements ReceiptRepository {
  @override
  Future<ReceiptModel?> getReceiptByPaymentId(String paymentId) async => null;

  @override
  Stream<List<ReceiptModel>> getMemberReceipts(String memberId) =>
      Stream.value([]);

  @override
  Stream<List<ReceiptModel>> getReceiptsByDateRange(
    DateTime start,
    DateTime end,
  ) => Stream.value([]);

  @override
  Future<ReceiptModel?> getReceiptById(String id) async => null;

  @override
  Future<String> createReceipt(ReceiptModel receipt) async => '';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockObligationRepository implements ObligationRepository {
  List<ObligationModel> _obligations = [];

  void setObligations(List<ObligationModel> obligations) =>
      _obligations = obligations;

  @override
  Stream<List<ObligationModel>> getMemberActiveObligations(String memberId) {
    return Stream.value(
      _obligations
          .where(
            (o) =>
                o.memberId == memberId &&
                (o.status == ObligationStatus.unpaid ||
                    o.status == ObligationStatus.partial),
          )
          .toList(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDate = DateTime(2026, 6, 30);

  final testObligations = [
    ObligationModel(
      id: 'obl1',
      memberId: 'member1',
      levyId: 'levy1',
      type: ObligationType.monthlyDue,
      title: 'June Monthly Due',
      description: 'Monthly contribution',
      amount: 5000,
      paidAmount: 0,
      outstandingBalance: 5000,
      status: ObligationStatus.unpaid,
      dueDate: testDate,
      createdAt: DateTime.now(),
    ),
    ObligationModel(
      id: 'obl2',
      memberId: 'member1',
      levyId: 'levy2',
      type: ObligationType.specialLevy,
      title: 'Project Fund',
      description: 'Hall project',
      amount: 10000,
      paidAmount: 3000,
      outstandingBalance: 7000,
      status: ObligationStatus.partial,
      dueDate: testDate.add(const Duration(days: 15)),
      createdAt: DateTime.now(),
    ),
  ];

  final testPayments = [
    PaymentModel(
      id: 'pay1',
      memberId: 'member1',
      amount: 5000,
      method: PaymentMethod.online,
      status: PaymentStatus.approved,
      allocations: [PaymentAllocationModel(obligationId: 'obl1', amount: 5000)],
      paystackReference: 'PAY-001',
      createdAt: DateTime(2026, 6, 15),
    ),
    PaymentModel(
      id: 'pay2',
      memberId: 'member1',
      amount: 3000,
      method: PaymentMethod.cash,
      status: PaymentStatus.pending,
      allocations: [PaymentAllocationModel(obligationId: 'obl2', amount: 3000)],
      createdAt: DateTime(2026, 6, 10),
    ),
  ];

  group('PaymentFlowNotifier', () {
    test('initializes payment successfully', () async {
      final mockService = _MockPaymentService();
      mockService.setInitResult(
        PaystackInitResult(
          authorizationUrl: 'https://paystack.test/pay',
          accessCode: 'acc123',
          reference: 'ref123',
        ),
      );

      final notifier = PaymentFlowNotifier(paymentService: mockService);

      await notifier.initializePayment(
        email: 'test@example.com',
        amountNaira: 5000,
        memberId: 'member1',
        obligations: testObligations,
      );

      expect(notifier.state.isInitializing, false);
      expect(notifier.state.authorizationUrl, 'https://paystack.test/pay');
      expect(notifier.state.error, isNull);
    });

    test('handles initialization error', () async {
      final mockService = _MockPaymentService();
      mockService.setInitError(PaymentException('Paystack error'));

      final notifier = PaymentFlowNotifier(paymentService: mockService);

      await notifier.initializePayment(
        email: 'test@example.com',
        amountNaira: 5000,
        memberId: 'member1',
        obligations: testObligations,
      );

      expect(notifier.state.isInitializing, false);
      expect(notifier.state.error, isNotNull);
    });

    test('verifies payment successfully', () async {
      final mockService = _MockPaymentService();
      mockService.setVerifyResult(
        PaystackVerifyResult(
          paymentId: 'pay123',
          receiptId: 'rcp123',
          receiptNumber: 'RCP-001',
          verifiedAmount: 5000,
          status: 'approved',
        ),
      );

      final notifier = PaymentFlowNotifier(paymentService: mockService);

      await notifier.verifyPayment(
        reference: 'ref123',
        memberId: 'member1',
        obligationIds: ['obl1'],
        amountPaid: 5000,
      );

      expect(notifier.state.isVerifying, false);
      expect(notifier.state.isSuccess, true);
      expect(notifier.state.paymentId, 'pay123');
      expect(notifier.state.receiptNumber, 'RCP-001');
    });

    test('reset clears state', () {
      final mockService = _MockPaymentService();
      final notifier = PaymentFlowNotifier(paymentService: mockService);

      notifier.state = const PaymentFlowState(
        isSuccess: true,
        paymentId: 'pay123',
        error: 'old error',
      );

      notifier.reset();

      expect(notifier.state.isSuccess, false);
      expect(notifier.state.paymentId, isNull);
      expect(notifier.state.error, isNull);
    });
  });

  group('MakePaymentScreen', () {
    Widget buildScreen({
      List<ObligationModel>? obligations,
      _MockPaymentService? customService,
    }) {
      final mockService = customService ?? _MockPaymentService();
      final mockObligationRepo = _MockObligationRepository();
      if (obligations != null) mockObligationRepo.setObligations(obligations);

      return ProviderScope(
        overrides: [
          paymentServiceProvider.overrideWith((ref) => mockService),
          obligationRepositoryProvider.overrideWith(
            (ref) => mockObligationRepo,
          ),
        ],
        child: MaterialApp(
          home: MakePaymentScreen(
            memberId: 'member1',
            memberEmail: 'test@example.com',
            obligations: obligations,
          ),
        ),
      );
    }

    testWidgets('renders title and shows payment options', (tester) async {
      await tester.pumpWidget(buildScreen(obligations: []));
      await tester.pumpAndSettle();

      expect(find.text('Make Payment'), findsOneWidget);
      expect(find.text('Payment Options'), findsOneWidget);
      expect(find.text('Custom Amount'), findsOneWidget);
    });

    testWidgets('displays obligations to select', (tester) async {
      await tester.pumpWidget(buildScreen(obligations: testObligations));
      await tester.pumpAndSettle();

      expect(find.text('June Monthly Due'), findsOneWidget);
      expect(find.text('Project Fund'), findsOneWidget);
    });

    testWidgets('selects obligations and updates total', (tester) async {
      await tester.pumpWidget(buildScreen(obligations: testObligations));
      await tester.pumpAndSettle();

      final firstCheckbox = find.byType(CheckboxListTile).first;
      await tester.tap(firstCheckbox);
      await tester.pump();

      expect(find.textContaining('Total to Pay'), findsOneWidget);
    });

    testWidgets('pay button disabled when no obligations selected', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen(obligations: testObligations));
      await tester.pumpAndSettle();

      final payButton = find.widgetWithText(FilledButton, 'Pay with Paystack');
      expect(payButton, findsOneWidget);
      expect(tester.widget<FilledButton>(payButton).onPressed, isNull);
    });

    testWidgets('shows payment error', (tester) async {
      final mockService = _MockPaymentService();
      mockService.setInitError(PaymentException('Init failed'));

      final mockObligationRepo = _MockObligationRepository();
      mockObligationRepo.setObligations(testObligations);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentServiceProvider.overrideWith((ref) => mockService),
            obligationRepositoryProvider.overrideWith(
              (ref) => mockObligationRepo,
            ),
          ],
          child: MaterialApp(
            home: MakePaymentScreen(
              memberId: 'member1',
              memberEmail: 'test@example.com',
              obligations: testObligations,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final firstCheckbox = find.byType(CheckboxListTile).first;
      await tester.tap(firstCheckbox);
      await tester.pump();

      final payButton = find.widgetWithText(FilledButton, 'Pay with Paystack');
      await tester.tap(payButton);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error), findsOneWidget);
      expect(find.textContaining('Init failed'), findsOneWidget);
    });
  });

  group('PaymentHistoryScreen', () {
    testWidgets('renders title and empty state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentHistoryProvider(
              'member1',
            ).overrideWith((ref) => Stream.value([])),
            receiptRepositoryProvider.overrideWith(
              (ref) => _MockReceiptRepository(),
            ),
          ],
          child: MaterialApp(home: PaymentHistoryScreen(memberId: 'member1')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Payment History'), findsOneWidget);
      expect(find.text('No payments yet'), findsOneWidget);
    });

    testWidgets('displays payments with status', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentHistoryProvider(
              'member1',
            ).overrideWith((ref) => Stream.value(testPayments)),
            receiptRepositoryProvider.overrideWith(
              (ref) => _MockReceiptRepository(),
            ),
          ],
          child: MaterialApp(home: PaymentHistoryScreen(memberId: 'member1')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('₦5,000'), findsWidgets);
      expect(find.textContaining('₦3,000'), findsWidgets);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Online (Paystack)'), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
    });
  });
}
