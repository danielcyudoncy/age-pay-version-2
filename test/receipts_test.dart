import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/payments/models/payment_model.dart';
import 'package:cls/features/receipts/models/receipt_model.dart';
import 'package:cls/features/receipts/repositories/receipt_repository.dart';
import 'package:cls/features/auth/services/auth_service.dart';
import 'package:cls/features/receipts/services/receipt_service.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/payments/views/payment_history_screen.dart';
import 'package:cls/features/receipts/controllers/receipt_provider.dart';
import 'package:cls/features/receipts/views/receipt_detail_screen.dart';
import 'package:cls/features/receipts/views/receipt_list_screen.dart';
import 'package:cls/features/payments/views/payment_history_screen.dart'
    as payment_history;

class _MockAuthService implements AuthService {
  final UserModel? user;
  _MockAuthService(this.user);

  @override
  Future<UserModel?> getCurrentUser() async {
    if (user == null) throw Exception('Auth error');
    return user;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockReceiptRepo implements ReceiptRepository {
  final List<ReceiptModel> receipts;

  _MockReceiptRepo({this.receipts = const []});

  @override
  Stream<List<ReceiptModel>> getMemberReceipts(String memberId) {
    return Stream.value(receipts);
  }

  @override
  Future<ReceiptModel?> getReceiptById(String id) async {
    try {
      return receipts.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ReceiptModel?> getReceiptByPaymentId(String paymentId) async {
    try {
      return receipts.firstWhere((r) => r.paymentId == paymentId);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<List<ReceiptModel>> getReceiptsByDateRange(
    DateTime start,
    DateTime end,
  ) => Stream.value([]);

  @override
  Future<String> createReceipt(ReceiptModel receipt) async => '';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDate = DateTime(2026, 6, 15);

  final testUser = UserModel(
    uid: 'm1',
    email: 'test@test.com',
    displayName: 'Test Member',
    phoneNumber: '08012345678',
    role: UserRole.member,
    createdAt: testDate,
  );

  final testReceipt = ReceiptModel(
    id: 'r1',
    receiptNumber: 'RCP-2024-001',
    paymentId: 'p1',
    memberId: 'm1',
    memberName: 'Test Member',
    amount: 5000,
    method: PaymentMethod.online,
    paymentDate: testDate,
    allocatedObligations: const [
      {'title': 'June Monthly Due', 'amount': 3000},
      {'title': 'Project Fund', 'amount': 2000},
    ],
    createdAt: testDate,
  );

  final testReceipts = [
    testReceipt,
    ReceiptModel(
      id: 'r2',
      receiptNumber: 'RCP-2024-002',
      paymentId: 'p2',
      memberId: 'm1',
      memberName: 'Test Member',
      amount: 3000,
      method: PaymentMethod.cash,
      paymentDate: testDate.add(const Duration(days: 1)),
      allocatedObligations: const [],
      createdAt: testDate.add(const Duration(days: 1)),
    ),
  ];

  group('ReceiptService', () {
    test('generates receipt PDF bytes', () async {
      final service = ReceiptService();
      final bytes = await service.generateReceiptPdf(
        receipt: testReceipt,
        associationName: 'Age Grade Association',
      );
      expect(bytes.length, greaterThan(100));
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
  });

  group('ReceiptListScreen', () {
    Widget buildScreen({List<ReceiptModel> receipts = const []}) {
      final mockAuth = _MockAuthService(testUser);
      final mockRepo = _MockReceiptRepo(receipts: receipts);

      return ProviderScope(
        overrides: [
          authServiceProvider.overrideWith((ref) => mockAuth),
          authProvider.overrideWith((ref) {
            final notifier = AuthNotifier(mockAuth);
            notifier.state = AsyncValue.data(testUser);
            return notifier;
          }),
          receiptRepositoryProvider.overrideWith((ref) => mockRepo),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 1200)),
            child: ReceiptListScreen(memberId: 'm1'),
          ),
        ),
      );
    }

    testWidgets('renders receipt cards', (tester) async {
      await tester.pumpWidget(buildScreen(receipts: testReceipts));
      await tester.pumpAndSettle();

      expect(find.text('My Receipts'), findsOneWidget);
      expect(find.text('RCP-2024-001'), findsOneWidget);
      expect(find.textContaining('₦5,000'), findsOneWidget);
      expect(find.text('RCP-2024-002'), findsOneWidget);
      expect(find.textContaining('₦3,000'), findsOneWidget);
    });

    testWidgets('shows empty state', (tester) async {
      await tester.pumpWidget(buildScreen(receipts: []));
      await tester.pumpAndSettle();

      expect(find.text('My Receipts'), findsOneWidget);
      expect(find.text('No receipts yet'), findsOneWidget);
    });
  });

  group('ReceiptDetailScreen', () {
    Widget buildScreen(ReceiptModel receipt) {
      return ProviderScope(
        overrides: [
          receiptRepositoryProvider.overrideWith((ref) => _MockReceiptRepo()),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 1200)),
            child: ReceiptDetailScreen(receipt: receipt),
          ),
        ),
      );
    }

    testWidgets('shows receipt details', (tester) async {
      await tester.pumpWidget(buildScreen(testReceipt));
      await tester.pumpAndSettle();

      expect(find.text('Receipt Details'), findsOneWidget);
      expect(find.text('RCP-2024-001'), findsOneWidget);
      expect(find.text('Test Member'), findsOneWidget);
      expect(find.textContaining('₦5,000'), findsWidgets);
    });

    testWidgets('shows download button', (tester) async {
      await tester.pumpWidget(buildScreen(testReceipt));
      await tester.pumpAndSettle();

      expect(find.text('Download Receipt PDF'), findsOneWidget);
      expect(find.byIcon(Icons.download), findsOneWidget);
    });
  });

  group('PaymentHistoryScreen transfer proof', () {
    final approvedPayment = PaymentModel(
      id: 'pay1',
      memberId: 'm1',
      amount: 5000,
      method: PaymentMethod.online,
      status: PaymentStatus.approved,
      allocations: const [
        PaymentAllocationModel(obligationId: 'o1', amount: 5000),
      ],
      createdAt: testDate,
    );

    final pendingBankTransfer = PaymentModel(
      id: 'pay2',
      memberId: 'm1',
      amount: 3000,
      method: PaymentMethod.bankTransfer,
      status: PaymentStatus.pending,
      allocations: const [
        PaymentAllocationModel(obligationId: 'o2', amount: 3000),
      ],
      transferProofUrl: 'https://example.com/receipt.jpg',
      createdAt: testDate.add(const Duration(days: 1)),
    );

    Widget buildScreen({
      required List<PaymentModel> payments,
      List<ReceiptModel> receipts = const [],
    }) {
      final mockRepo = _MockReceiptRepo(receipts: receipts);

      return ProviderScope(
        overrides: [
          payment_history
              .paymentHistoryProvider('m1')
              .overrideWith((ref) => Stream.value(payments)),
          receiptRepositoryProvider.overrideWith((ref) => mockRepo),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 1200)),
            child: PaymentHistoryScreen(memberId: 'm1'),
          ),
        ),
      );
    }

    testWidgets(
      'shows transfer proof button for bank transfer payments with proof',
      (tester) async {
        await tester.pumpWidget(
          buildScreen(payments: [approvedPayment, pendingBankTransfer]),
        );
        await tester.pumpAndSettle();

        expect(find.text('Approved'), findsOneWidget);
        expect(find.text('Pending'), findsOneWidget);
        expect(find.byIcon(Icons.receipt), findsOneWidget);
      },
    );
  });
}
