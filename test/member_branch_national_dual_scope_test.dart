import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/payments/models/payment_model.dart';
import 'package:cls/features/obligations/models/obligation_model.dart';
import 'package:cls/features/payments/repositories/payment_repository.dart';
import 'package:cls/features/obligations/repositories/obligation_repository.dart';
import 'package:cls/features/auth/services/auth_service.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/dashboard/views/member_dashboard.dart';
import 'package:cls/features/dashboard/controllers/member_dashboard_provider.dart';
import 'package:cls/features/obligations/controllers/obligation_provider.dart';

class _MockAuthService implements AuthService {
  final UserModel? user;
  _MockAuthService(this.user);

  @override
  Future<UserModel?> getCurrentUser() async => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockPaymentRepo implements PaymentRepository {
  final List<PaymentModel> payments;
  _MockPaymentRepo({this.payments = const []});

  @override
  Stream<List<PaymentModel>> getMemberPayments(String memberId) =>
      Stream.value(payments);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockObligationRepo implements ObligationRepository {
  final List<ObligationModel> obligations;
  _MockObligationRepo({this.obligations = const []});

  @override
  Stream<List<ObligationModel>> getAllObligations() =>
      Stream.value(obligations);

  @override
  Future<int> reconcileMemberObligations(
    String memberOrUserId, {
    String? userId,
    String? organizationId,
    MemberDuesStanding? duesStanding,
    double? openingBalance,
  }) async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final testUser = UserModel(
    uid: 'user_1',
    email: 'test@example.com',
    phoneNumber: '08012345678',
    displayName: 'Daniel Udoncy',
    role: UserRole.member,
    branchId: 'branch_lagos',
    branchName: 'Lagos Branch',
    organizationId: 'org_1',
    createdAt: DateTime.now(),
  );

  final branchObligation = ObligationModel(
    id: 'obl_branch_1',
    organizationId: 'org_1',
    memberId: 'user_1',
    levyId: 'levy_branch_1',
    type: ObligationType.monthlyDue,
    title: 'March Monthly Due',
    description: 'Local Branch Meeting Due',
    amount: 5000,
    paidAmount: 5000,
    outstandingBalance: 0,
    status: ObligationStatus.paid,
    scope: 'branch',
    branchId: 'branch_lagos',
    dueDate: DateTime.now().add(const Duration(days: 10)),
    createdAt: DateTime.now(),
  );

  final nationalObligation = ObligationModel(
    id: 'obl_national_1',
    organizationId: 'org_1',
    memberId: 'user_1',
    levyId: 'levy_national_1',
    type: ObligationType.specialLevy,
    title: 'National Convention Levy',
    description: 'Annual National Convention 2026',
    amount: 25000,
    paidAmount: 10000,
    outstandingBalance: 15000,
    status: ObligationStatus.partial,
    scope: 'national',
    branchId: 'national',
    dueDate: DateTime.now().add(const Duration(days: 30)),
    createdAt: DateTime.now(),
  );

  Widget createWidget({
    required List<ObligationModel> obligations,
    List<PaymentModel> payments = const [],
  }) {
    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(_MockAuthService(testUser)),
        paymentRepositoryProvider.overrideWithValue(
          _MockPaymentRepo(payments: payments),
        ),
        obligationRepositoryProvider.overrideWithValue(
          _MockObligationRepo(obligations: obligations),
        ),
      ],
      child: const MaterialApp(home: MemberDashboard()),
    );
  }

  testWidgets('MemberDashboard renders Branch and National Body toggle buttons',
      (tester) async {
    await tester.pumpWidget(createWidget(
      obligations: [branchObligation, nationalObligation],
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Checks that the toggle is visible with branch name and National Body
    expect(find.text('Lagos Branch'), findsWidgets);
    expect(find.text('National Body'), findsOneWidget);
    expect(find.text('Central'), findsOneWidget);

    // Default scope is branch: context banner reflects local branch
    expect(
      find.textContaining('Lagos Branch Tier'),
      findsOneWidget,
    );
  });

  testWidgets(
      'Tapping National Body switches context banner and scopes obligations to National',
      (tester) async {
    await tester.pumpWidget(createWidget(
      obligations: [branchObligation, nationalObligation],
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Tap National Body toggle
    final nationalButton = find.text('National Body');
    await tester.tap(nationalButton);
    await tester.pumpAndSettle();

    // Context banner now reflects National Body
    expect(find.textContaining('National Body Tier'), findsOneWidget);

    // Tap back to Lagos Branch
    final branchButton = find.text('Lagos Branch').first;
    await tester.tap(branchButton);
    await tester.pumpAndSettle();

    // Context banner reverts to Lagos Branch
    expect(find.textContaining('Lagos Branch Tier'), findsOneWidget);
  });

  testWidgets(
      'Total outstanding reflects branch-scoped levy (20,000) and switches to national (15,000)',
      (tester) async {
    final branchLevy20k = ObligationModel(
      id: 'obl_branch_levy_1',
      organizationId: 'org_1',
      memberId: 'user_1',
      levyId: 'levy_branch_new',
      type: ObligationType.specialLevy,
      title: 'Branch Development Levy',
      description: 'New 20k branch levy',
      amount: 20000,
      paidAmount: 0,
      outstandingBalance: 20000,
      status: ObligationStatus.unpaid,
      scope: 'branch',
      branchId: 'branch_lagos',
      dueDate: DateTime.now().add(const Duration(days: 10)),
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(createWidget(
      obligations: [branchLevy20k, nationalObligation],
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // In branch scope, displays ₦20,000 outstanding (not ₦40,000 or ₦35,000)
    expect(find.text('₦20,000'), findsOneWidget);

    // Switch to national scope
    final nationalButton = find.text('National Body');
    await tester.tap(nationalButton);
    await tester.pumpAndSettle();

    // In national scope, displays ₦15,000 outstanding
    expect(find.text('₦15,000'), findsOneWidget);
  });

  testWidgets(
      'Member with unpaid 20k levy and no payments shows Total Payments ₦0 and Outstanding ₦20,000',
      (tester) async {
    final newLevy = ObligationModel(
      id: 'levy_dev_user_1',
      organizationId: 'org_1',
      memberId: 'user_1',
      levyId: 'levy_dev',
      type: ObligationType.specialLevy,
      title: 'Branch Development Due',
      description: 'Annual development levy',
      amount: 20000,
      paidAmount: 0,
      outstandingBalance: 20000,
      status: ObligationStatus.unpaid,
      scope: 'branch',
      branchId: 'branch_lagos',
      dueDate: DateTime.now().add(const Duration(days: 15)),
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(createWidget(
      obligations: [newLevy],
      payments: const [],
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Total Payments card displays ₦0
    expect(find.text('₦0'), findsOneWidget);

    // Outstanding Payments card displays ₦20,000
    expect(find.text('₦20,000'), findsOneWidget);

    // Active Levies card displays 1
    expect(find.text('1'), findsWidgets);
  });

  testWidgets(
      'Member with duplicate obligations for the same levy shows ₦20,000 (not ₦40,000)',
      (tester) async {
    final levyDup1 = ObligationModel(
      id: 'levy_dev_user_1',
      organizationId: 'org_1',
      memberId: 'user_1',
      levyId: 'levy_dev_20k',
      type: ObligationType.specialLevy,
      title: 'Branch Development Due',
      description: 'Annual development levy',
      amount: 20000,
      paidAmount: 0,
      outstandingBalance: 20000,
      status: ObligationStatus.unpaid,
      scope: 'branch',
      branchId: 'branch_lagos',
      dueDate: DateTime.now().add(const Duration(days: 15)),
      createdAt: DateTime.now(),
    );

    final levyDup2 = ObligationModel(
      id: 'levy_dev_user_1_legacy',
      organizationId: 'org_1',
      memberId: 'user_1',
      levyId: 'levy_dev_20k',
      type: ObligationType.specialLevy,
      title: 'Branch Development Due',
      description: 'Annual development levy',
      amount: 20000,
      paidAmount: 0,
      outstandingBalance: 20000,
      status: ObligationStatus.unpaid,
      scope: 'branch',
      branchId: 'branch_lagos',
      dueDate: DateTime.now().add(const Duration(days: 15)),
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(createWidget(
      obligations: [levyDup1, levyDup2],
      payments: const [],
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Outstanding Payments card displays ₦20,000 (deduplicated), NOT ₦40,000
    expect(find.text('₦20,000'), findsOneWidget);
    expect(find.text('₦40,000'), findsNothing);

    // Active Levies card displays 1 (deduplicated), NOT 2
    expect(find.text('1'), findsWidgets);
  });
}
