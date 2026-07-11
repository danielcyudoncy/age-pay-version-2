import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cls/main.dart' as app;
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/data/models/member_model.dart';
import 'package:cls/data/models/payment_model.dart';
import 'package:cls/data/models/obligation_model.dart';
import 'package:cls/data/models/levy_model.dart';
import 'package:cls/data/models/expense_model.dart';
import 'package:cls/data/models/receipt_model.dart';
import 'package:cls/data/repositories/member_repository.dart';
import 'package:cls/data/repositories/payment_repository.dart';
import 'package:cls/data/repositories/obligation_repository.dart';
import 'package:cls/data/repositories/levy_repository.dart';
import 'package:cls/data/repositories/expense_repository.dart';
import 'package:cls/data/repositories/receipt_repository.dart';
import 'package:cls/data/services/auth_service.dart';
import 'package:cls/data/services/notification_service.dart';
import 'package:cls/features/dashboard/controllers/member_dashboard_provider.dart';
import 'package:cls/features/dashboard/controllers/treasurer_dashboard_provider.dart';
import 'package:cls/features/obligations/controllers/obligation_provider.dart';
import 'package:cls/features/levies/controllers/levy_provider.dart'
    as levy_provider
    show levyRepositoryProvider, obligationRepositoryProvider;
import 'package:cls/features/expenses/controllers/expense_provider.dart';
import 'package:cls/features/receipts/controllers/receipt_provider.dart';
import 'package:cls/features/notifications/controllers/notification_provider.dart';
import 'package:cls/features/levies/views/create_levy_screen.dart';
import 'package:cls/features/expenses/views/expense_list_screen.dart';
import 'package:cls/features/reports/views/reports_screen.dart';
import 'package:cls/features/receipts/views/receipt_list_screen.dart';
import 'package:cls/features/notifications/views/notifications_screen.dart';

void main() {
  final now = DateTime.now();

  final testMember = MemberModel(
    id: 'member-1',
    userId: 'user-1',
    fullName: 'Test Member',
    email: 'member@test.com',
    phoneNumber: '08012345678',
    dateOfBirth: DateTime(1990, 1, 1),
    joinedDate: DateTime(2020, 1, 1),
    createdAt: now,
    updatedAt: now,
  );

  final memberUser = UserModel(
    uid: 'user-1',
    email: 'member@test.com',
    displayName: 'Test Member',
    phoneNumber: '08012345678',
    role: UserRole.member,
    createdAt: now,
  );

  final treasurerUser = UserModel(
    uid: 'user-2',
    email: 'treas@test.com',
    displayName: 'Test Treasurer',
    phoneNumber: '08012345678',
    role: UserRole.treasurer,
    createdAt: now,
  );

  final presidentUser = UserModel(
    uid: 'user-3',
    email: 'pres@test.com',
    displayName: 'Test President',
    phoneNumber: '08012345678',
    role: UserRole.president,
    createdAt: now,
  );

  final testPayment = PaymentModel(
    id: 'pay-1',
    memberId: 'user-1',
    amount: 5000,
    method: PaymentMethod.cash,
    status: PaymentStatus.approved,
    allocations: const [],
    createdAt: now,
  );

  final testObligation = ObligationModel(
    id: 'obl-1',
    memberId: 'user-1',
    levyId: 'levy-1',
    type: ObligationType.monthlyDue,
    title: 'Monthly Due',
    description: 'Test obligation',
    amount: 10000,
    paidAmount: 5000,
    outstandingBalance: 5000,
    status: ObligationStatus.partial,
    dueDate: now.add(const Duration(days: 30)),
    createdAt: now,
  );

  final testLevy = LevyModel(
    id: 'levy-1',
    title: 'Monthly Due',
    description: 'Test levy',
    type: ObligationType.monthlyDue,
    amountPerMember: 10000,
    dueDate: now.add(const Duration(days: 30)),
    createdBy: 'user-2',
    createdAt: now,
    updatedAt: now,
  );

  final testExpense = ExpenseModel(
    id: 'exp-1',
    title: 'Office Rent',
    description: 'Test expense',
    amount: 2000,
    category: ExpenseCategory.administration,
    createdBy: 'user-2',
    expenseDate: now,
    createdAt: now,
    updatedAt: now,
  );

  final testReceipt = ReceiptModel(
    id: 'rec-1',
    receiptNumber: 'REC-001',
    paymentId: 'pay-1',
    memberId: 'user-1',
    memberName: 'Test Member',
    amount: 5000,
    method: PaymentMethod.cash,
    paymentDate: now,
    allocatedObligations: const [],
    createdAt: now,
  );

  List<Override> buildOverrides(UserModel? user) => [
    authServiceProvider.overrideWithValue(_MockAuth(user)),
    memberRepositoryProvider.overrideWithValue(_MockMemberRepo(testMember)),
    paymentRepositoryProvider.overrideWithValue(_MockPaymentRepo(testPayment)),
    obligationRepositoryProvider.overrideWithValue(
      _MockObligationRepo(testObligation),
    ),
    levy_provider.obligationRepositoryProvider.overrideWithValue(
      _MockObligationRepo(testObligation),
    ),
    levy_provider.levyRepositoryProvider.overrideWithValue(
      _MockLevyRepo(testLevy),
    ),
    expenseRepositoryProvider.overrideWithValue(_MockExpenseRepo(testExpense)),
    receiptRepositoryProvider.overrideWithValue(_MockReceiptRepo(testReceipt)),
    notificationServiceProvider.overrideWithValue(_MockNotificationService()),
  ];

  testWidgets('member end-to-end flow', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1080, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(memberUser),
        child: const app.MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Total Paid'), findsOneWidget);
    expect(find.text('Total Outstanding'), findsOneWidget);

    // Scroll the list to reveal quick actions
    await tester.fling(
      find.byType(ListView).first,
      const Offset(0, -300),
      1000,
    );
    await tester.pumpAndSettle();

    final quickAction = find.text('View Obligations').first;
    await tester.ensureVisible(quickAction);
    await tester.pumpAndSettle();
    await tester.tap(quickAction);
    await tester.pumpAndSettle();

    expect(find.text('My Obligations'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.fling(
      find.byType(ListView).first,
      const Offset(0, -300),
      1000,
    );
    await tester.pumpAndSettle();

    final historyAction = find.text('View History').first;
    await tester.ensureVisible(historyAction);
    await tester.pumpAndSettle();
    await tester.tap(historyAction);
    await tester.pumpAndSettle();

    expect(find.text('Payment History'), findsOneWidget);
  });

  testWidgets('treasurer end-to-end flow', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(treasurerUser),
        child: const app.MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Treasurer Dashboard'), findsOneWidget);
    expect(find.text('Total Collected'), findsOneWidget);
    expect(find.text('Total Outstanding'), findsOneWidget);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute(
        builder: (_) => CreateLevyScreen(
          creatorId: treasurerUser.uid,
          memberIds: const ['member-1'],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create New Levy'), findsOneWidget);

    navigator.push(
      MaterialPageRoute(
        builder: (_) => ExpenseListScreen(currentUserId: treasurerUser.uid),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Add Expense'), findsOneWidget);
  });

  testWidgets('president end-to-end flow', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(presidentUser),
        child: const app.MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('President Dashboard'), findsOneWidget);

    await tester.fling(
      find.byType(ListView).first,
      const Offset(0, -800),
      1000,
    );
    await tester.pumpAndSettle();

    final allTexts = tester.allWidgets
        .whereType<Text>()
        .map((w) => w.data ?? '')
        .toList();
    expect(
      allTexts.any(
        (t) =>
            t.contains('Collections by Method') ||
            t.contains('Monthly Collections'),
      ),
      isTrue,
    );

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute(builder: (_) => const ReportsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Member Statement'), findsOneWidget);
  });

  testWidgets('reports and receipts flow', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(memberUser),
        child: const app.MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute(builder: (_) => const ReportsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Reports'), findsOneWidget);

    navigator.push(
      MaterialPageRoute(
        builder: (_) => const ReceiptListScreen(memberId: 'member-1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Receipts'), findsOneWidget);
  });

  testWidgets('notifications screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(memberUser),
        child: const app.MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(currentUser: memberUser),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('No notifications yet'), findsOneWidget);
  });
}

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockAuth implements AuthService {
  final UserModel? _user;
  _MockAuth(this._user);

  @override
  Future<UserModel?> getCurrentUser() async => _user;

  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockMemberRepo implements MemberRepository {
  final MemberModel _member;
  _MockMemberRepo(this._member);

  @override
  Stream<List<MemberModel>> getMembers() => Stream.value([_member]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockPaymentRepo implements PaymentRepository {
  final PaymentModel _payment;
  _MockPaymentRepo(this._payment);

  @override
  Stream<List<PaymentModel>> getMemberPayments(String memberId) =>
      Stream.value([_payment]);

  @override
  Stream<List<PaymentModel>> getPendingPayments() => Stream.value([]);

  @override
  Stream<List<PaymentModel>> getAllPayments() => Stream.value([_payment]);

  @override
  Future<PaymentModel?> getPaymentById(String id) async => _payment;

  @override
  Future<String> createPayment(PaymentModel payment) async => 'pay-1';

  @override
  Future<void> updatePaymentStatus(
    String id, {
    required PaymentStatus status,
    String? verifiedBy,
    DateTime? verifiedAt,
    String? receiptUrl,
  }) async {}

  @override
  Future<void> updatePaymentAllocations(
    String id,
    List<PaymentAllocationModel> allocations,
  ) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockObligationRepo implements ObligationRepository {
  final ObligationModel _obligation;
  _MockObligationRepo(this._obligation);

  @override
  Stream<List<ObligationModel>> getAllObligations() =>
      Stream.value([_obligation]);

  @override
  Stream<List<ObligationModel>> getMemberObligations(String memberId) =>
      Stream.value([_obligation]);

  @override
  Stream<List<ObligationModel>> getMemberActiveObligations(String memberId) =>
      Stream.value([_obligation]);

  @override
  Stream<List<ObligationModel>> getLevyObligations(String levyId) =>
      Stream.value([_obligation]);

  @override
  Future<ObligationModel?> getObligationById(String id) async => _obligation;

  @override
  Future<String> createObligation(ObligationModel obligation) async => 'obl-1';

  @override
  Future<void> updateObligationStatus(
    String id, {
    double? paidAmount,
    double? outstandingBalance,
    ObligationStatus? status,
    DateTime? settledAt,
  }) async {}

  @override
  Future<void> batchCreateObligations(
    List<ObligationModel> obligations,
  ) async {}

  @override
  Future<void> batchCreateFromMaps(List<Map<String, dynamic>> maps) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockLevyRepo implements LevyRepository {
  final LevyModel _levy;
  _MockLevyRepo(this._levy);

  @override
  Stream<List<LevyModel>> getActiveLevies() => Stream.value([_levy]);

  @override
  Stream<List<LevyModel>> getAllLevies() => Stream.value([_levy]);

  @override
  Future<LevyModel?> getLevyById(String id) async => _levy;

  @override
  Future<String> createLevy(LevyModel levy) async => 'levy-1';

  @override
  Future<void> updateLevy(LevyModel levy) async {}

  @override
  Future<void> deactivateLevy(String id) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockExpenseRepo implements ExpenseRepository {
  final ExpenseModel _expense;
  _MockExpenseRepo(this._expense);

  @override
  Stream<List<ExpenseModel>> getExpenses() => Stream.value([_expense]);

  @override
  Stream<List<ExpenseModel>> getExpensesByDateRange(
    DateTime start,
    DateTime end,
  ) => Stream.value([_expense]);

  @override
  Future<ExpenseModel?> getExpenseById(String id) async => _expense;

  @override
  Future<String> createExpense(ExpenseModel expense) async => 'exp-1';

  @override
  Future<void> updateExpense(ExpenseModel expense) async {}

  @override
  Future<void> deleteExpense(String id) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockReceiptRepo implements ReceiptRepository {
  final ReceiptModel _receipt;
  _MockReceiptRepo(this._receipt);

  @override
  Stream<List<ReceiptModel>> getMemberReceipts(String memberId) =>
      Stream.value([_receipt]);

  @override
  Stream<List<ReceiptModel>> getReceiptsByDateRange(
    DateTime start,
    DateTime end,
  ) => Stream.value([_receipt]);

  @override
  Future<ReceiptModel?> getReceiptById(String id) async => _receipt;

  @override
  Future<ReceiptModel?> getReceiptByPaymentId(String paymentId) async =>
      _receipt;

  @override
  Future<String> createReceipt(ReceiptModel receipt) async => 'rec-1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockNotificationService implements NotificationService {
  @override
  Stream<RemoteMessage> get onForegroundMessage =>
      const Stream<RemoteMessage>.empty();

  @override
  Stream<RemoteMessage> get onMessageOpenedApp =>
      const Stream<RemoteMessage>.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
