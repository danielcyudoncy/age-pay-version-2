import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/auth/services/auth_service.dart';
import 'package:cls/features/dashboard/views/treasurer_dashboard.dart';
import 'package:cls/features/dashboard/views/treasurer_cash_handover_screen.dart';
import 'package:cls/features/dashboard/controllers/treasurer_dashboard_provider.dart';
import 'package:cls/features/financial_secretary/models/cash_handover_model.dart';
import 'package:cls/features/financial_secretary/controllers/cash_handover_provider.dart';
import 'package:cls/features/payments/repositories/payment_repository.dart';
import 'package:cls/features/obligations/repositories/obligation_repository.dart';
import 'package:cls/features/levies/repositories/levy_repository.dart';
import 'package:cls/features/expenses/repositories/expense_repository.dart';
import 'package:cls/features/members/repositories/member_repository.dart';
import 'package:cls/features/payments/models/payment_model.dart';
import 'package:cls/features/obligations/models/obligation_model.dart';
import 'package:cls/features/levies/models/levy_model.dart';
import 'package:cls/features/expenses/models/expense_model.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/obligations/controllers/obligation_provider.dart';
import 'package:cls/features/admin/controllers/admin_provider.dart';
import 'package:cls/features/admin/models/organization_model.dart';
import 'package:cls/features/dashboard/controllers/member_dashboard_provider.dart'
    show paymentRepositoryProvider;
import 'package:cls/features/levies/controllers/levy_provider.dart'
    hide obligationRepositoryProvider;
import 'package:cls/features/expenses/controllers/expense_provider.dart';

class _MockAuthService implements AuthService {
  final UserModel? user;
  _MockAuthService(this.user);
  @override
  Future<UserModel?> getCurrentUser() async => user;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockPaymentRepo implements PaymentRepository {
  @override
  Stream<List<PaymentModel>> getAllPayments() => Stream.value([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockObligationRepo implements ObligationRepository {
  @override
  Stream<List<ObligationModel>> getAllObligations() => Stream.value([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockLevyRepo implements LevyRepository {
  @override
  Stream<List<LevyModel>> getActiveLevies() => Stream.value([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockExpenseRepo implements ExpenseRepository {
  @override
  Stream<List<ExpenseModel>> getExpenses() => Stream.value([]);
  @override
  Stream<List<ExpenseModel>> getPendingExpenses() => Stream.value([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockMemberRepo implements MemberRepository {
  @override
  Stream<List<MemberModel>> getMembers() => Stream.value([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testTreasurer = UserModel(
    uid: 'treasurer-1',
    organizationId: 'org-onyirimba',
    branchId: 'lagos-branch',
    email: 'treasurer@onyirimba.org',
    displayName: 'Chief Treasurer Okonkwo',
    phoneNumber: '08099887766',
    role: UserRole.treasurer,
    createdAt: DateTime(2025, 1, 1),
  );

  final mockDashboardData = TreasurerDashboardData(
    totalCollected: 388000.0,
    totalOutstanding: 45000.0,
    totalPending: 0.0,
    totalMembers: 45,
    memberArrears: [],
    levyCollection: [],
    expenseTotal: 394000.0,
    netPosition: -6000.0,
    recentPayments: [],
  );

  final mockPendingHandover = CashHandoverModel(
    id: 'handover-1',
    organizationId: 'org-onyirimba',
    branchId: 'lagos-branch',
    amount: 120000.0,
    handedOverBy: 'Fin Sec Kalu',
    handedOverById: 'finsec-1',
    handedOverAt: DateTime(2026, 10, 25, 16, 30),
    status: CashHandoverStatus.pending,
    notes: 'October 2026 General Meeting Cash Collections',
    createdBy: 'finsec-1',
    createdAt: DateTime(2026, 10, 25, 16, 30),
    updatedAt: DateTime(2026, 10, 25, 16, 30),
  );

  final mockAcceptedHandover = CashHandoverModel(
    id: 'handover-2',
    organizationId: 'org-onyirimba',
    branchId: 'lagos-branch',
    amount: 80000.0,
    handedOverBy: 'Fin Sec Kalu',
    handedOverById: 'finsec-1',
    handedOverAt: DateTime(2026, 10, 20, 16, 30),
    receivedBy: 'Treasurer Nnamdi',
    receivedById: 'treasurer-1',
    acknowledgedAt: DateTime(2026, 10, 20, 17, 00),
    status: CashHandoverStatus.accepted,
    bankName: 'Zenith Bank',
    bankAccountNumber: '1023456789',
    notes: 'Mid-Month Collections',
    createdBy: 'finsec-1',
    createdAt: DateTime(2026, 10, 20, 16, 30),
    updatedAt: DateTime(2026, 10, 20, 17, 00),
  );

  group('Phase 3: Treasurer Custody & Handover Acceptance', () {
    testWidgets('TreasurerDashboard displays Cash Handovers quick action and pending banner',
        (tester) async {
      final widget = ProviderScope(
        overrides: [
          authServiceProvider.overrideWith((ref) => _MockAuthService(testTreasurer)),
          authProvider.overrideWith((ref) {
            final notifier = AuthNotifier(ref.watch(authServiceProvider));
            notifier.state = AsyncValue.data(testTreasurer);
            return notifier;
          }),
          treasurerDashboardProvider.overrideWithValue(
            AsyncValue.data(mockDashboardData),
          ),
          paymentRepositoryProvider.overrideWithValue(_MockPaymentRepo()),
          obligationRepositoryProvider.overrideWithValue(_MockObligationRepo()),
          levyRepositoryProvider.overrideWithValue(_MockLevyRepo()),
          expenseRepositoryProvider.overrideWithValue(_MockExpenseRepo()),
          memberRepositoryProvider.overrideWithValue(_MockMemberRepo()),
          membersStreamProvider.overrideWith((ref) => Stream.value([])),
          allPaymentsStreamProvider.overrideWith((ref) => Stream.value([])),
          allObligationsProvider.overrideWith((ref) => Stream.value([])),
          activeLeviesProvider.overrideWith((ref) => Stream.value([])),
          expensesStreamProvider.overrideWith((ref) => Stream.value([])),
          pendingExpensesStreamProvider.overrideWith((ref) => Stream.value([])),
          pendingCashHandoversStreamProvider.overrideWith(
            (ref) => Stream.value([mockPendingHandover]),
          ),
          cashHandoversStreamProvider.overrideWith(
            (ref) => Stream.value([mockPendingHandover]),
          ),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(800, 1600)),
            child: TreasurerDashboard(),
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Pending Cash Handover banner appears on top
      expect(find.text('1 Cash Handover Pending'), findsOneWidget);
      expect(find.text('Accept & Deposit'), findsOneWidget);

      // Scroll down to view quick actions
      await tester.scrollUntilVisible(
        find.text('Cash Handovers'),
        500.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Cash Handovers'), findsOneWidget);
    });

    testWidgets('TreasurerCashHandoverScreen displays pending handover and accepts receipt',
        (tester) async {
      final widget = ProviderScope(
        overrides: [
          authServiceProvider.overrideWith((ref) => _MockAuthService(testTreasurer)),
          authProvider.overrideWith((ref) {
            final notifier = AuthNotifier(ref.watch(authServiceProvider));
            notifier.state = AsyncValue.data(testTreasurer);
            return notifier;
          }),
          cashHandoversStreamProvider.overrideWith(
            (ref) => Stream.value([mockPendingHandover]),
          ),
        ],
        child: const MaterialApp(
          home: TreasurerCashHandoverScreen(),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('Treasurer Custody Verification'), findsOneWidget);
      expect(find.text('Awaiting Your Receipt'), findsOneWidget);
      expect(find.text('Accept & Deposit'), findsOneWidget);
      expect(find.text('Dispute'), findsOneWidget);
    });

    testWidgets(
        'TreasurerCashHandoverScreen prefills organization bank details in accept dialog',
        (tester) async {
      final testOrg = OrganizationModel(
        id: 'org-1',
        name: 'Test Age Grade',
        slug: 'test-age-grade',
        bankName: 'Zenith Bank',
        accountNumber: '1023456789',
        accountName: 'Test Age Grade Central Treasury',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      final widget = ProviderScope(
        overrides: [
          authServiceProvider.overrideWith((ref) => _MockAuthService(testTreasurer)),
          authProvider.overrideWith((ref) {
            final notifier = AuthNotifier(ref.watch(authServiceProvider));
            notifier.state = AsyncValue.data(testTreasurer);
            return notifier;
          }),
          cashHandoversStreamProvider.overrideWith(
            (ref) => Stream.value([mockPendingHandover]),
          ),
          currentOrganizationProvider.overrideWith(
            (ref) => Stream.value(testOrg),
          ),
        ],
        child: const MaterialApp(
          home: TreasurerCashHandoverScreen(),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Tap Accept & Deposit
      await tester.tap(find.text('Accept & Deposit'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Cash Receipt & Deposit'), findsOneWidget);
      expect(find.text('Official Account: Test Age Grade Central Treasury'), findsOneWidget);
      expect(find.text('Zenith Bank'), findsOneWidget);
      expect(find.text('1023456789'), findsOneWidget);
    });

    testWidgets(
        'TreasurerCashHandoverScreen displays Cash Received in Custody summary card',
        (tester) async {
      final widget = ProviderScope(
        overrides: [
          authServiceProvider.overrideWith((ref) => _MockAuthService(testTreasurer)),
          authProvider.overrideWith((ref) {
            final notifier = AuthNotifier(ref.watch(authServiceProvider));
            notifier.state = AsyncValue.data(testTreasurer);
            return notifier;
          }),
          cashHandoversStreamProvider.overrideWith(
            (ref) => Stream.value([mockPendingHandover, mockAcceptedHandover]),
          ),
        ],
        child: const MaterialApp(
          home: TreasurerCashHandoverScreen(),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('Cash Received in Custody'), findsOneWidget);
      expect(find.text('₦80,000'), findsOneWidget); // Total accepted
      expect(find.text('1 Reconciled'), findsOneWidget);
      expect(find.text('Awaiting Receipt'), findsOneWidget);
      expect(find.text('₦120,000'), findsNWidgets(2)); // summary card + pending list item
      expect(find.text('1 Voucher'), findsOneWidget);
    });

    testWidgets(
        'TreasurerDashboard displays Cash Handover Custody card and Cash in Hand overview card when handovers exist',
        (tester) async {
      final dashboardWithHandovers = TreasurerDashboardData(
        totalCollected: 388000.0,
        totalOutstanding: 45000.0,
        totalPending: 0.0,
        totalMembers: 45,
        memberArrears: [],
        levyCollection: [],
        expenseTotal: 394000.0,
        netPosition: -6000.0,
        recentPayments: [],
        totalCashHandoverReceived: 80000.0,
        totalCashHandoverPending: 120000.0,
      );

      final widget = ProviderScope(
        overrides: [
          authServiceProvider.overrideWith((ref) => _MockAuthService(testTreasurer)),
          authProvider.overrideWith((ref) {
            final notifier = AuthNotifier(ref.watch(authServiceProvider));
            notifier.state = AsyncValue.data(testTreasurer);
            return notifier;
          }),
          treasurerDashboardProvider.overrideWithValue(
            AsyncValue.data(dashboardWithHandovers),
          ),
          cashHandoversStreamProvider.overrideWith(
            (ref) => Stream.value([mockPendingHandover, mockAcceptedHandover]),
          ),
          paymentRepositoryProvider.overrideWithValue(_MockPaymentRepo()),
          obligationRepositoryProvider.overrideWithValue(_MockObligationRepo()),
          levyRepositoryProvider.overrideWithValue(_MockLevyRepo()),
          expenseRepositoryProvider.overrideWithValue(_MockExpenseRepo()),
          memberRepositoryProvider.overrideWithValue(_MockMemberRepo()),
          membersStreamProvider.overrideWith((ref) => Stream.value([])),
          allPaymentsStreamProvider.overrideWith((ref) => Stream.value([])),
          allObligationsProvider.overrideWith((ref) => Stream.value([])),
          activeLeviesProvider.overrideWith((ref) => Stream.value([])),
          expensesStreamProvider.overrideWith((ref) => Stream.value([])),
          pendingExpensesStreamProvider.overrideWith((ref) => Stream.value([])),
          pendingCashHandoversStreamProvider.overrideWith(
            (ref) => Stream.value([mockPendingHandover]),
          ),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(800, 1600)),
            child: TreasurerDashboard(),
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('Cash in Hand'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Cash Handover from Fin Sec'),
        300.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Cash Handover from Fin Sec'), findsOneWidget);
      expect(find.text('Confirmed in Custody'), findsOneWidget);
    });
  });
}
