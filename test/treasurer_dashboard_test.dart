// test/treasurer_dashboard_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/expenses/models/expense_model.dart';
import 'package:cls/features/levies/models/levy_model.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/obligations/models/obligation_model.dart';
import 'package:cls/features/payments/models/payment_model.dart';
import 'package:cls/features/expenses/repositories/expense_repository.dart';
import 'package:cls/features/levies/repositories/levy_repository.dart';
import 'package:cls/features/members/repositories/member_repository.dart';
import 'package:cls/features/obligations/repositories/obligation_repository.dart';
import 'package:cls/features/payments/repositories/payment_repository.dart';
import 'package:cls/features/auth/services/auth_service.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/dashboard/controllers/treasurer_dashboard_provider.dart';
import 'package:cls/features/dashboard/views/treasurer_dashboard.dart';
import 'package:cls/features/expenses/controllers/expense_provider.dart';
import 'package:cls/features/levies/controllers/levy_provider.dart'
    hide obligationRepositoryProvider;
import 'package:cls/features/obligations/controllers/obligation_provider.dart';
import 'package:cls/features/dashboard/controllers/member_dashboard_provider.dart';

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

class _MockPaymentRepo implements PaymentRepository {
  final List<PaymentModel> payments;
  final bool shouldThrow;

  _MockPaymentRepo({this.payments = const [], this.shouldThrow = false});

  @override
  Stream<List<PaymentModel>> getAllPayments() {
    if (shouldThrow) return Stream.error(Exception('Payment error'));
    return Stream.value(payments);
  }

  @override
  Stream<List<PaymentModel>> getMemberPayments(String memberId) =>
      Stream.value(payments.where((p) => p.memberId == memberId).toList());

  @override
  Stream<List<PaymentModel>> getPendingPayments() => Stream.value(
    payments.where((p) => p.status == PaymentStatus.pending).toList(),
  );

  @override
  Future<String> createPayment(PaymentModel p) async => 'p1';

  @override
  Future<PaymentModel?> getPaymentById(String id) async => null;

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
  final List<ObligationModel> obligations;
  final bool shouldThrow;

  _MockObligationRepo({this.obligations = const [], this.shouldThrow = false});

  @override
  Stream<List<ObligationModel>> getAllObligations() {
    if (shouldThrow) return Stream.error(Exception('Obligation error'));
    return Stream.value(obligations);
  }

  @override
  Stream<List<ObligationModel>> getMemberObligations(String memberId) =>
      Stream.value(obligations.where((o) => o.memberId == memberId).toList());

  @override
  Stream<List<ObligationModel>> getMemberActiveObligations(String memberId) =>
      Stream.value(
        obligations
            .where(
              (o) =>
                  o.memberId == memberId &&
                  (o.status == ObligationStatus.unpaid ||
                      o.status == ObligationStatus.partial),
            )
            .toList(),
      );

  @override
  Stream<List<ObligationModel>> getLevyObligations(String levyId) =>
      Stream.value(obligations.where((o) => o.levyId == levyId).toList());

  @override
  Future<ObligationModel?> getObligationById(String id) async => null;

  @override
  Future<String> createObligation(ObligationModel obligation) async => '';

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
  final List<LevyModel> levies;
  final bool shouldThrow;

  _MockLevyRepo({this.levies = const [], this.shouldThrow = false});

  @override
  Stream<List<LevyModel>> getActiveLevies() {
    if (shouldThrow) return Stream.error(Exception('Levy error'));
    return Stream.value(levies.where((l) => l.isActive).toList());
  }

  @override
  Stream<List<LevyModel>> getAllLevies() => Stream.value(levies);

  @override
  Future<LevyModel?> getLevyById(String id) async => null;

  @override
  Future<String> createLevy(LevyModel levy) async => '';

  @override
  Future<void> updateLevy(LevyModel levy) async {}

  @override
  Future<void> deactivateLevy(String id) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockExpenseRepo implements ExpenseRepository {
  final List<ExpenseModel> expenses;
  final bool shouldThrow;

  _MockExpenseRepo({this.expenses = const [], this.shouldThrow = false});

  @override
  Stream<List<ExpenseModel>> getExpenses() {
    if (shouldThrow) return Stream.error(Exception('Expense error'));
    return Stream.value(expenses);
  }

  @override
  Stream<List<ExpenseModel>> getExpensesByDateRange(
    DateTime start,
    DateTime end,
  ) => Stream.value(expenses);

  @override
  Future<ExpenseModel?> getExpenseById(String id) async => null;

  @override
  Future<String> createExpense(ExpenseModel expense) async => '';

  @override
  Future<void> updateExpense(ExpenseModel expense) async {}

  @override
  Future<void> deleteExpense(String id) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockMemberRepo implements MemberRepository {
  final List<MemberModel> members;
  final bool shouldThrow;

  _MockMemberRepo({this.members = const [], this.shouldThrow = false});

  @override
  Stream<List<MemberModel>> getMembers() {
    if (shouldThrow) return Stream.error(Exception('Member error'));
    return Stream.value(members);
  }

  @override
  Future<MemberModel?> getMemberById(String id) async => null;

  @override
  Future<MemberModel?> getMemberByUserId(String userId) async => null;

  @override
  Future<String> createMember(MemberModel member) async => '';

  @override
  Future<void> updateMember(MemberModel member) async {}

  @override
  Future<void> deleteMember(String id) async {}

  @override
  Future<List<MemberModel>> searchMembers(String query) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testUser = UserModel(
    uid: 't1',
    email: 'treasurer@test.com',
    displayName: 'Test Treasurer',
    phoneNumber: '08000000000',
    role: UserRole.treasurer,
    createdAt: DateTime.now(),
  );

  final testDate = DateTime(2026, 6, 15);

  final testMembers = [
    MemberModel(
      id: 'mem1',
      userId: 'm1',
      fullName: 'John Doe',
      email: 'john@test.com',
      phoneNumber: '0801',
      dateOfBirth: DateTime(1990),
      joinedDate: DateTime(2020),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    MemberModel(
      id: 'mem2',
      userId: 'm2',
      fullName: 'Jane Smith',
      email: 'jane@test.com',
      phoneNumber: '0802',
      dateOfBirth: DateTime(1995),
      joinedDate: DateTime(2021),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  final testPayments = [
    PaymentModel(
      id: 'p1',
      memberId: 'm1',
      amount: 5000,
      method: PaymentMethod.cash,
      status: PaymentStatus.approved,
      allocations: [],
      createdAt: testDate.add(const Duration(hours: 2)),
    ),
    PaymentModel(
      id: 'p2',
      memberId: 'm2',
      amount: 10000,
      method: PaymentMethod.online,
      status: PaymentStatus.pending,
      allocations: [],
      createdAt: testDate.add(const Duration(hours: 1)),
    ),
    PaymentModel(
      id: 'p3',
      memberId: 'm1',
      amount: 3000,
      method: PaymentMethod.bankTransfer,
      status: PaymentStatus.approved,
      allocations: [],
      createdAt: testDate,
    ),
  ];

  final testObligations = [
    ObligationModel(
      id: 'o1',
      memberId: 'm1',
      levyId: 'l1',
      type: ObligationType.monthlyDue,
      title: 'June Monthly Due',
      description: '',
      amount: 5000,
      paidAmount: 5000,
      outstandingBalance: 0,
      status: ObligationStatus.paid,
      dueDate: testDate,
      createdAt: DateTime.now(),
    ),
    ObligationModel(
      id: 'o2',
      memberId: 'm1',
      levyId: 'l2',
      type: ObligationType.specialLevy,
      title: 'Project Fund',
      description: '',
      amount: 10000,
      paidAmount: 5000,
      outstandingBalance: 5000,
      status: ObligationStatus.partial,
      dueDate: testDate,
      createdAt: DateTime.now(),
    ),
    ObligationModel(
      id: 'o3',
      memberId: 'm2',
      levyId: 'l1',
      type: ObligationType.monthlyDue,
      title: 'June Monthly Due',
      description: '',
      amount: 5000,
      paidAmount: 0,
      outstandingBalance: 5000,
      status: ObligationStatus.unpaid,
      dueDate: testDate,
      createdAt: DateTime.now(),
    ),
  ];

  final testLevies = [
    LevyModel(
      id: 'l1',
      title: 'June Monthly Due',
      description: '',
      type: ObligationType.monthlyDue,
      amountPerMember: 5000,
      dueDate: testDate,
      createdBy: 'admin',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    LevyModel(
      id: 'l2',
      title: 'Project Fund',
      description: '',
      type: ObligationType.specialLevy,
      amountPerMember: 10000,
      dueDate: testDate,
      createdBy: 'admin',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  final testExpenses = [
    ExpenseModel(
      id: 'e1',
      title: 'Stationery',
      description: '',
      amount: 2000,
      category: ExpenseCategory.administration,
      createdBy: 't1',
      expenseDate: testDate,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  Widget buildDashboard({
    List<PaymentModel> payments = const [],
    List<ObligationModel> obligations = const [],
    List<LevyModel> levies = const [],
    List<ExpenseModel> expenses = const [],
    List<MemberModel> members = const [],
    bool paymentThrow = false,
    bool obligationThrow = false,
    bool levyThrow = false,
    bool expenseThrow = false,
    bool memberThrow = false,
    bool authThrow = false,
    AsyncValue<UserModel?>? authState,
  }) {
    final mockPaymentRepo = _MockPaymentRepo(
      payments: payments,
      shouldThrow: paymentThrow,
    );
    final mockObligationRepo = _MockObligationRepo(
      obligations: obligations,
      shouldThrow: obligationThrow,
    );
    final mockLevyRepo = _MockLevyRepo(levies: levies, shouldThrow: levyThrow);
    final mockExpenseRepo = _MockExpenseRepo(
      expenses: expenses,
      shouldThrow: expenseThrow,
    );
    final mockMemberRepo = _MockMemberRepo(
      members: members,
      shouldThrow: memberThrow,
    );
    final mockAuthService = _MockAuthService(authThrow ? null : testUser);

    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWith((ref) => mockAuthService),
        authProvider.overrideWith((ref) {
          final notifier = AuthNotifier(ref.watch(authServiceProvider));
          if (authState != null) {
            notifier.state = authState;
          } else if (authThrow) {
            notifier.state = AsyncValue.error(
              Exception('Auth error'),
              StackTrace.current,
            );
          } else {
            notifier.state = AsyncValue.data(testUser);
          }
          return notifier;
        }),
        paymentRepositoryProvider.overrideWith((ref) => mockPaymentRepo),
        obligationRepositoryProvider.overrideWith((ref) => mockObligationRepo),
        levyRepositoryProvider.overrideWith((ref) => mockLevyRepo),
        expenseRepositoryProvider.overrideWith((ref) => mockExpenseRepo),
        memberRepositoryProvider.overrideWith((ref) => mockMemberRepo),
        levyCreationProvider.overrideWith((ref) {
          return LevyCreationNotifier(
            levyRepository: ref.watch(levyRepositoryProvider),
            obligationRepository: ref.watch(obligationRepositoryProvider),
          );
        }),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(800, 1200)),
          child: const TreasurerDashboard(),
        ),
      ),
    );
  }

  group('TreasurerDashboard', () {
    testWidgets('renders title and overview cards with correct totals', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildDashboard(
          payments: testPayments,
          obligations: testObligations,
          levies: testLevies,
          expenses: testExpenses,
          members: testMembers,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Treasurer Dashboard'), findsOneWidget);
      expect(find.text('Total Collected'), findsOneWidget);
      expect(find.text('Total Outstanding'), findsOneWidget);
      expect(find.text('Pending Payments'), findsOneWidget);
      expect(find.text('Net Position'), findsOneWidget);

      final allTexts = tester.allWidgets
          .whereType<Text>()
          .map((w) => w.data ?? '')
          .toList();
      expect(allTexts, contains('₦8,000')); // Total Collected from obligations
      expect(allTexts, contains('₦10,000')); // Total Outstanding
      expect(allTexts, contains('₦10,000')); // Pending Payments (p2 = 10000)
    });

    testWidgets(
      'shows member arrears list when members have outstanding balances',
      (tester) async {
        await tester.pumpWidget(
          buildDashboard(
            payments: testPayments,
            obligations: testObligations,
            levies: testLevies,
            expenses: testExpenses,
            members: testMembers,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Members in Arrears'), findsOneWidget);
        expect(find.text('John Doe'), findsOneWidget);
        expect(find.text('Jane Smith'), findsOneWidget);
        expect(find.textContaining('1 unpaid obligation'), findsWidgets);
      },
    );

    testWidgets('shows levy collection progress with progress bars', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildDashboard(
          payments: testPayments,
          obligations: testObligations,
          levies: testLevies,
          expenses: testExpenses,
          members: testMembers,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Levy Collection'), findsOneWidget);
      expect(find.text('June Monthly Due'), findsOneWidget);
      expect(find.text('Project Fund'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsWidgets);
      expect(find.textContaining('%'), findsWidgets);
    });

    testWidgets('shows recent payments list with status badges', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildDashboard(
          payments: testPayments,
          obligations: testObligations,
          levies: testLevies,
          expenses: testExpenses,
          members: testMembers,
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to bring Recent Activity into the viewport so SliverList builds it
      await tester.drag(find.byType(ListView), const Offset(0, -1200));
      await tester.pumpAndSettle();

      final allTexts = tester.allWidgets
          .whereType<Text>()
          .map((w) => w.data ?? '')
          .toList();
      expect(allTexts, contains('Recent Activity'));
      expect(allTexts.any((t) => t.contains('Cash')), isTrue);
      expect(allTexts.any((t) => t.contains('Pending')), isTrue);
      expect(allTexts.any((t) => t.contains('Approved')), isTrue);
    });

    testWidgets('shows quick action buttons', (tester) async {
      await tester.pumpWidget(
        buildDashboard(
          payments: testPayments,
          obligations: testObligations,
          levies: testLevies,
          expenses: testExpenses,
          members: testMembers,
        ),
      );
      await tester.pumpAndSettle();

      // scroll down to bring quick actions into viewport
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();

      final allTexts = tester.allWidgets
          .whereType<Text>()
          .map((w) => w.data ?? '')
          .toList();
      expect(allTexts, contains('Record Cash Payment'));
      expect(allTexts, contains('Verify Payments'));
      expect(allTexts, contains('Create Levy'));
      expect(allTexts, contains('Add Expense'));
    });

    testWidgets('Create Levy button is tappable', (tester) async {
      await tester.pumpWidget(
        buildDashboard(
          payments: testPayments,
          obligations: testObligations,
          levies: testLevies,
          expenses: testExpenses,
          members: testMembers,
        ),
      );
      await tester.pumpAndSettle();

      // scroll down to bring quick actions into viewport
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();

      // Verify all quick action buttons are present
      final allTexts = tester.allWidgets
          .whereType<Text>()
          .map((w) => w.data ?? '')
          .toList();
      expect(allTexts, contains('Create Levy'));
    });

    testWidgets('shows empty states when no data', (tester) async {
      await tester.pumpWidget(buildDashboard());
      await tester.pumpAndSettle();

      final allTexts = tester.allWidgets
          .whereType<Text>()
          .map((w) => w.data ?? '')
          .toList();
      debugPrint('EMPTY_ALL_TEXTS: ${allTexts.join('|')}');

      expect(find.text('No members in arrears'), findsOneWidget);
      expect(find.text('No active levies'), findsOneWidget);
      expect(allTexts, contains('No recent activity'));
    });

    testWidgets('shows loading state initially', (tester) async {
      await tester.pumpWidget(
        buildDashboard(authState: const AsyncValue.loading()),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error state with retry button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWith((ref) => _MockAuthService(null)),
            authProvider.overrideWith((ref) {
              final notifier = AuthNotifier(ref.watch(authServiceProvider));
              notifier.state = AsyncValue.error(
                Exception('Auth error'),
                StackTrace.current,
              );
              return notifier;
            }),
            paymentRepositoryProvider.overrideWith((ref) => _MockPaymentRepo()),
            obligationRepositoryProvider.overrideWith(
              (ref) => _MockObligationRepo(),
            ),
            levyRepositoryProvider.overrideWith((ref) => _MockLevyRepo()),
            expenseRepositoryProvider.overrideWith((ref) => _MockExpenseRepo()),
            memberRepositoryProvider.overrideWith((ref) => _MockMemberRepo()),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(size: Size(800, 1200)),
              child: const TreasurerDashboard(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Auth error'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
    });
  });
}
