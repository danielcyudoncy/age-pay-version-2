// test/financial_secretary_dashboard_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/services/auth_service.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/financial_secretary/views/financial_secretary_dashboard.dart';
import 'package:cls/features/financial_secretary/controllers/financial_secretary_dashboard_provider.dart';
import 'package:cls/features/dashboard/controllers/treasurer_dashboard_provider.dart'
    show
        membersStreamProvider,
        allPaymentsStreamProvider,
        memberRepositoryProvider;
import 'package:cls/features/obligations/controllers/obligation_provider.dart';
import 'package:cls/features/levies/controllers/levy_provider.dart'
    show activeLeviesProvider, levyRepositoryProvider, levyCreationProvider, LevyCreationNotifier;
import 'package:cls/features/expenses/controllers/expense_provider.dart'
    show expenseRepositoryProvider, expensesStreamProvider, pendingExpensesStreamProvider;
import 'package:cls/features/secretary/controllers/secretary_dashboard_provider.dart'
    show announcementsStreamProvider;
import 'package:cls/features/payments/repositories/payment_repository.dart';
import 'package:cls/features/obligations/repositories/obligation_repository.dart';
import 'package:cls/features/levies/repositories/levy_repository.dart';
import 'package:cls/features/expenses/repositories/expense_repository.dart';
import 'package:cls/features/members/repositories/member_repository.dart';
import 'package:cls/features/levies/views/create_levy_screen.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/payments/models/payment_model.dart';
import 'package:cls/features/obligations/models/obligation_model.dart';
import 'package:cls/features/levies/models/levy_model.dart';
import 'package:cls/features/expenses/models/expense_model.dart';
import 'package:cls/features/dashboard/controllers/member_dashboard_provider.dart';

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
  Stream<List<PaymentModel>> getMemberPayments(String memberId) => Stream.value([]);
  @override
  Stream<List<PaymentModel>> getPendingPayments() => Stream.value([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockObligationRepo implements ObligationRepository {
  @override
  Stream<List<ObligationModel>> getAllObligations() => Stream.value([]);
  @override
  Stream<List<ObligationModel>> getMemberObligations(String memberId) => Stream.value([]);
  @override
  Stream<List<ObligationModel>> getMemberActiveObligations(String memberId) => Stream.value([]);
  @override
  Stream<List<ObligationModel>> getLevyObligations(String levyId) => Stream.value([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockLevyRepo implements LevyRepository {
  @override
  Stream<List<LevyModel>> getActiveLevies() => Stream.value([]);
  @override
  Stream<List<LevyModel>> getAllLevies() => Stream.value([]);
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
  final List<MemberModel> members;
  _MockMemberRepo({this.members = const []});

  @override
  Stream<List<MemberModel>> getMembers() => Stream.value(members);
  @override
  Future<MemberModel?> getMemberById(String id) async => null;
  @override
  Future<MemberModel?> getMemberByUserId(String userId) async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testUser = UserModel(
    uid: 'finsec1',
    organizationId: 'org1',
    email: 'finsec@test.com',
    displayName: 'Fin Sec John',
    phoneNumber: '08000000000',
    role: UserRole.financialSecretary,
    createdAt: DateTime(2025, 1, 1),
  );

  final List<MemberModel> testMembers = [
    MemberModel(
      id: 'm1',
      userId: 'u1',
      fullName: 'Alice Member',
      email: 'alice@test.com',
      phoneNumber: '0801',
      dateOfBirth: DateTime(1990),
      joinedDate: DateTime(2020),
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    ),
  ];

  const emptyData = FinancialSecretaryDashboardData(
    totalCollected: 0,
    totalOutstanding: 0,
    cashCollected: 0,
    bankCollected: 0,
    onlineCollected: 0,
    pendingVerificationsCount: 0,
    totalMembers: 1,
    memberArrears: [],
    levySummaries: [],
    recentPayments: [],
  );

  Widget buildDashboard({
    FinancialSecretaryDashboardData? data,
    List<ObligationModel>? obligations,
  }) {
    final mockAuth = _MockAuthService(testUser);
    final mockPayment = _MockPaymentRepo();
    final mockObligation = _MockObligationRepo();
    final mockLevy = _MockLevyRepo();
    final mockExpense = _MockExpenseRepo();
    final mockMember = _MockMemberRepo(members: testMembers);

    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWith((ref) => mockAuth),
        authProvider.overrideWith((ref) {
          final notifier = AuthNotifier(ref.watch(authServiceProvider));
          notifier.state = AsyncValue.data(testUser);
          return notifier;
        }),
        if (data != null || obligations == null)
          financialSecretaryDashboardProvider.overrideWithValue(
            AsyncValue.data(data ?? emptyData),
          ),
        paymentRepositoryProvider.overrideWith((ref) => mockPayment),
        obligationRepositoryProvider.overrideWith((ref) => mockObligation),
        levyRepositoryProvider.overrideWith((ref) => mockLevy),
        expenseRepositoryProvider.overrideWith((ref) => mockExpense),
        memberRepositoryProvider.overrideWith((ref) => mockMember),
        levyCreationProvider.overrideWith((ref) {
          return LevyCreationNotifier(
            levyRepository: ref.watch(levyRepositoryProvider),
            obligationRepository: ref.watch(obligationRepositoryProvider),
          );
        }),
        membersStreamProvider.overrideWith((ref) => Stream.value(testMembers)),
        allPaymentsStreamProvider.overrideWith((ref) => Stream.value([])),
        allObligationsProvider.overrideWith((ref) => Stream.value(obligations ?? [])),
        activeLeviesProvider.overrideWith((ref) => Stream.value([])),
        expensesStreamProvider.overrideWith((ref) => Stream.value([])),
        pendingExpensesStreamProvider.overrideWith((ref) => Stream.value([])),
        announcementsStreamProvider('org1').overrideWith((ref) => Stream.value([])),
        organizationObligationsCleanupProvider('org1').overrideWith((ref) => Future.value(0)),
        memberTotalPaidProvider('finsec1').overrideWithValue(const AsyncValue.data(0.0)),
        memberTotalOutstandingProvider('finsec1').overrideWithValue(const AsyncValue.data(0.0)),
        memberActiveLeviesProvider('finsec1').overrideWithValue(const AsyncValue.data(0)),
        memberRecentPaymentsProvider('finsec1').overrideWithValue(const AsyncValue.data([])),
        memberRegistrationFeeStatusProvider('finsec1').overrideWithValue(const AsyncValue.data(true)),
        memberActiveObligationsProvider('finsec1').overrideWithValue(const AsyncValue.data([])),
        memberObligationReconciliationProvider('finsec1').overrideWith((ref) => Future.value(0)),
      ],
      child: const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(800, 1200)),
          child: FinancialSecretaryDashboard(),
        ),
      ),
    );
  }

  group('FinancialSecretaryDashboard', () {
    testWidgets('shows New Levy/Due quick action on Overview tab', (tester) async {
      await tester.pumpWidget(buildDashboard());
      await tester.pumpAndSettle();

      expect(find.text('Financial Secretary'), findsAtLeastNWidgets(1));

      // Scroll down to view financial quick actions
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(find.text('New Levy/Due'), findsOneWidget);
    });

    testWidgets('tapping New Levy/Due navigates to CreateLevyScreen', (tester) async {
      await tester.pumpWidget(buildDashboard());
      await tester.pumpAndSettle();

      // Scroll down to view financial quick actions
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pumpAndSettle();

      final newLevyBtn = find.text('New Levy/Due');
      expect(newLevyBtn, findsOneWidget);

      await tester.tap(newLevyBtn);
      await tester.pumpAndSettle();

      expect(find.byType(CreateLevyScreen), findsOneWidget);
      expect(find.text('Create New Levy'), findsOneWidget);
    });

    testWidgets('Levies tab shows Create Levy / Due FAB and empty state button', (tester) async {
      await tester.pumpWidget(buildDashboard());
      await tester.pumpAndSettle();

      // Tap on Levies navigation tab (index 3)
      await tester.tap(find.text('Levies'));
      await tester.pumpAndSettle();

      expect(find.text('Levies Management'), findsOneWidget);
      expect(find.text('Create Levy / Due'), findsWidgets);
      expect(find.text('No Active Levies or Dues'), findsOneWidget);
    });

    testWidgets('Debtors tab deduplicates duplicate obligations for the same levy', (tester) async {
      final duplicateObligations = [
        ObligationModel(
          id: 'obl_dup_1',
          organizationId: 'org1',
          memberId: 'm1',
          levyId: 'levy_20k',
          type: ObligationType.specialLevy,
          title: 'Development Levy',
          description: 'Levy 20k',
          amount: 20000,
          paidAmount: 0,
          outstandingBalance: 20000,
          status: ObligationStatus.unpaid,
          dueDate: DateTime.now().add(const Duration(days: 10)),
          createdAt: DateTime.now(),
        ),
        ObligationModel(
          id: 'obl_dup_2',
          organizationId: 'org1',
          memberId: 'm1',
          levyId: 'levy_20k',
          type: ObligationType.specialLevy,
          title: 'Development Levy',
          description: 'Levy 20k',
          amount: 20000,
          paidAmount: 0,
          outstandingBalance: 20000,
          status: ObligationStatus.unpaid,
          dueDate: DateTime.now().add(const Duration(days: 10)),
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(buildDashboard(obligations: duplicateObligations));
      await tester.pumpAndSettle();

      // Navigate to Debtors tab (index 2)
      await tester.tap(find.text('Debtors'));
      await tester.pumpAndSettle();

      // Must show ₦20,000 for member m1 (not ₦40,000)
      expect(find.text('₦20,000'), findsWidgets);
      expect(find.text('₦40,000'), findsNothing);
      expect(find.text('1 unpaid dues/levies'), findsOneWidget);
    });
  });
}
