// test/member_dashboard_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/data/models/payment_model.dart';
import 'package:cls/data/models/obligation_model.dart';
import 'package:cls/data/repositories/payment_repository.dart';
import 'package:cls/data/repositories/obligation_repository.dart';
import 'package:cls/data/services/auth_service.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/dashboard/views/member_dashboard.dart';
import 'package:cls/features/dashboard/controllers/member_dashboard_provider.dart';
import 'package:cls/features/obligations/controllers/obligation_provider.dart';

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
  Stream<List<PaymentModel>> getMemberPayments(String memberId) {
    if (shouldThrow) return Stream.error(Exception('Payment error'));
    return Stream.value(payments);
  }

  @override
  Stream<List<PaymentModel>> getAllPayments() => Stream.value(payments);

  @override
  Stream<List<PaymentModel>> getPendingPayments() => Stream.value([]);

  Stream<List<PaymentModel>> getPaymentsByDateRange(DateTime s, DateTime e) =>
      Stream.value([]);

  Stream<Map<String, dynamic>> getPaymentSummary() => Stream.value({});

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
  Stream<List<ObligationModel>> getMemberObligations(String memberId) {
    if (shouldThrow) return Stream.error(Exception('Obligation error'));
    return Stream.value(
      obligations.where((o) => o.memberId == memberId).toList(),
    );
  }

  @override
  Stream<List<ObligationModel>> getMemberActiveObligations(String memberId) {
    if (shouldThrow) return Stream.error(Exception('Obligation error'));
    return Stream.value(
      obligations
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
  Stream<List<ObligationModel>> getLevyObligations(String levyId) =>
      Stream.value([]);

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testUser = UserModel(
    uid: 'm1',
    email: 'test@test.com',
    displayName: 'Test Member',
    phoneNumber: '08012345678',
    role: UserRole.member,
    createdAt: DateTime.now(),
  );

  final testDate = DateTime(2026, 6, 15);

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
      memberId: 'm1',
      amount: 10000,
      method: PaymentMethod.online,
      status: PaymentStatus.pending,
      allocations: [],
      createdAt: testDate.add(const Duration(hours: 1)),
    ),
    PaymentModel(
      id: 'p3',
      memberId: 'm2',
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
      description: 'Monthly contribution',
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
      description: 'Community hall',
      amount: 10000,
      paidAmount: 5000,
      outstandingBalance: 5000,
      status: ObligationStatus.partial,
      dueDate: testDate.add(const Duration(days: 15)),
      createdAt: DateTime.now(),
    ),
    ObligationModel(
      id: 'o3',
      memberId: 'm1',
      levyId: 'l3',
      type: ObligationType.emergencyContribution,
      title: 'Emergency Relief',
      description: 'Flood relief',
      amount: 3000,
      paidAmount: 0,
      outstandingBalance: 3000,
      status: ObligationStatus.unpaid,
      dueDate: testDate.add(const Duration(days: -5)),
      createdAt: DateTime.now(),
    ),
    ObligationModel(
      id: 'o4',
      memberId: 'm2',
      levyId: 'l1',
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
      id: 'o5',
      memberId: 'm1',
      levyId: 'l4',
      type: ObligationType.registrationFee,
      title: 'Registration Fee',
      description: 'Annual membership registration',
      amount: 2000,
      paidAmount: 2000,
      outstandingBalance: 0,
      status: ObligationStatus.paid,
      dueDate: testDate,
      createdAt: DateTime.now(),
    ),
  ];

  Widget buildDashboard({
    List<PaymentModel> payments = const [],
    List<ObligationModel> obligations = const [],
    bool paymentThrow = false,
    bool obligationThrow = false,
    bool authThrow = false,
  }) {
    final mockPaymentRepo = _MockPaymentRepo(
      payments: payments,
      shouldThrow: paymentThrow,
    );
    final mockObligationRepo = _MockObligationRepo(
      obligations: obligations,
      shouldThrow: obligationThrow,
    );
    final mockAuthService = _MockAuthService(authThrow ? null : testUser);

    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWith((ref) => mockAuthService),
        authProvider.overrideWith((ref) {
          final notifier = AuthNotifier(ref.watch(authServiceProvider));
          if (authThrow) {
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
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(800, 1200)),
          child: const MemberDashboard(),
        ),
      ),
    );
  }

  group('MemberDashboard', () {
    testWidgets('renders dashboard title and greeting', (tester) async {
      await tester.pumpWidget(
        buildDashboard(
          payments: testPayments.where((p) => p.memberId == 'm1').toList(),
          obligations: testObligations
              .where((o) => o.memberId == 'm1')
              .toList(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.textContaining('Test Member'), findsOneWidget);
    });

    testWidgets('shows total paid card with correct amount', (tester) async {
      final memberPayments = testPayments
          .where((p) => p.memberId == 'm1')
          .toList();
      await tester.pumpWidget(
        buildDashboard(
          payments: memberPayments,
          obligations: testObligations
              .where((o) => o.memberId == 'm1')
              .toList(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total Paid'), findsOneWidget);
      // o1=5000, o2=5000, o3=0, o5=2000 => total 12000
      expect(find.textContaining('₦12,000'), findsOneWidget);
    });

    testWidgets('shows total outstanding card with correct amount', (
      tester,
    ) async {
      final memberObligations = testObligations
          .where((o) => o.memberId == 'm1')
          .toList();
      await tester.pumpWidget(
        buildDashboard(
          payments: testPayments.where((p) => p.memberId == 'm1').toList(),
          obligations: memberObligations,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total Outstanding'), findsOneWidget);
      // o2 outstanding=5000, o3 outstanding=3000 => total 8000
      expect(find.textContaining('₦8,000'), findsOneWidget);
    });

    testWidgets('shows active levies count', (tester) async {
      await tester.pumpWidget(
        buildDashboard(
          payments: testPayments.where((p) => p.memberId == 'm1').toList(),
          obligations: testObligations
              .where((o) => o.memberId == 'm1')
              .toList(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Active Levies'), findsOneWidget);
      // o2 partial and o3 unpaid => 2 active
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets(
      'shows registration status as registered when obligations exist',
      (tester) async {
        await tester.pumpWidget(
          buildDashboard(
            obligations: testObligations
                .where((o) => o.memberId == 'm1')
                .toList(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Registration Status'), findsOneWidget);
        expect(find.textContaining('Registered'), findsOneWidget);
      },
    );

    testWidgets(
      'shows registration status as incomplete when no registration fee paid',
      (tester) async {
        final otherObligations = testObligations
            .where(
              (o) =>
                  o.memberId == 'm1' &&
                  o.type != ObligationType.registrationFee,
            )
            .toList();
        await tester.pumpWidget(buildDashboard(obligations: otherObligations));
        await tester.pumpAndSettle();

        expect(find.text('Registration Status'), findsOneWidget);
        expect(find.text('Incomplete'), findsOneWidget);
      },
    );

    testWidgets('shows recent payments list with amounts and dates', (
      tester,
    ) async {
      final memberPayments = testPayments
          .where((p) => p.memberId == 'm1')
          .toList();
      await tester.pumpWidget(
        buildDashboard(
          payments: memberPayments,
          obligations: testObligations
              .where((o) => o.memberId == 'm1')
              .toList(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recent Payments'), findsOneWidget);
      expect(find.textContaining('₦5,000'), findsWidgets);
      expect(find.textContaining('₦10,000'), findsWidgets);
      expect(find.textContaining('Cash'), findsOneWidget);
      expect(find.textContaining('Online'), findsOneWidget);
    });

    testWidgets('shows quick action buttons', (tester) async {
      await tester.pumpWidget(
        buildDashboard(
          payments: testPayments.where((p) => p.memberId == 'm1').toList(),
          obligations: testObligations
              .where((o) => o.memberId == 'm1')
              .toList(),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to bring quick actions into viewport/cache
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();

      final allTexts = tester.allWidgets
          .whereType<Text>()
          .map((w) => w.data ?? '')
          .toList();
      expect(allTexts, contains('Make Payment'));
      expect(allTexts, contains('View History'));
      expect(allTexts, contains('View Obligations'));
    });

    testWidgets('shows empty state when no obligations and payments', (
      tester,
    ) async {
      await tester.pumpWidget(buildDashboard());
      await tester.pumpAndSettle();

      expect(find.text('No payments yet'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('All caught up!'), findsNothing);
      // Text is offstage in ListView; active levies empty state is rendered below viewport
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
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(size: Size(800, 1200)),
              child: const MemberDashboard(),
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
