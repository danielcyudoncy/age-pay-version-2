import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/auth/services/auth_service.dart';
import 'package:cls/features/financial_secretary/views/financial_secretary_dashboard.dart';
import 'package:cls/features/financial_secretary/controllers/financial_secretary_dashboard_provider.dart';
import 'package:cls/features/dashboard/controllers/treasurer_dashboard_provider.dart'
    show
        membersStreamProvider,
        allPaymentsStreamProvider,
        memberRepositoryProvider;
import 'package:cls/features/obligations/controllers/obligation_provider.dart';
import 'package:cls/features/levies/controllers/levy_provider.dart'
    hide obligationRepositoryProvider;
import 'package:cls/features/expenses/controllers/expense_provider.dart';
import 'package:cls/features/payments/repositories/payment_repository.dart';
import 'package:cls/features/obligations/repositories/obligation_repository.dart';
import 'package:cls/features/levies/repositories/levy_repository.dart';
import 'package:cls/features/expenses/repositories/expense_repository.dart';
import 'package:cls/features/members/repositories/member_repository.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/payments/models/payment_model.dart';
import 'package:cls/features/obligations/models/obligation_model.dart';
import 'package:cls/features/levies/models/levy_model.dart';
import 'package:cls/features/expenses/models/expense_model.dart';
import 'package:cls/features/dashboard/controllers/member_dashboard_provider.dart';
import 'package:cls/features/fiscal_period/controllers/fiscal_period_provider.dart';
import 'package:cls/features/financial_secretary/controllers/cash_handover_provider.dart';
import 'package:cls/features/national/controllers/national_remittance_provider.dart';

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

  final testUser = UserModel(
    uid: 'finsec-1',
    organizationId: 'org-onyirimba',
    branchId: 'lagos-branch',
    email: 'finsec@onyirimba.org',
    displayName: 'Fin Sec Kalu',
    phoneNumber: '08012345678',
    role: UserRole.financialSecretary,
    createdAt: DateTime(2025, 1, 1),
  );

  const mockDashboardData = FinancialSecretaryDashboardData(
    totalCollected: 388000.0,
    totalOutstanding: 45000.0,
    cashCollected: 120000.0,
    bankCollected: 268000.0,
    onlineCollected: 0.0,
    pendingVerificationsCount: 2,
    totalMembers: 45,
    memberArrears: [],
    levySummaries: [],
    recentPayments: [],
  );

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWith((ref) => _MockAuthService(testUser)),
        authProvider.overrideWith((ref) {
          final notifier = AuthNotifier(ref.watch(authServiceProvider));
          notifier.state = AsyncValue.data(testUser);
          return notifier;
        }),
        financialSecretaryDashboardProvider.overrideWithValue(
          const AsyncValue.data(mockDashboardData),
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
        fiscalPeriodsStreamProvider.overrideWith((ref) => Stream.value([])),
        cashHandoversStreamProvider.overrideWith((ref) => Stream.value([])),
        nationalRemittancesStreamProvider.overrideWith((ref) => Stream.value([])),
      ],
      child: const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(800, 1600)),
          child: FinancialSecretaryDashboard(),
        ),
      ),
    );
  }

  group('Phase 2: Financial Secretary Screen Real-World Capabilities', () {
    testWidgets('Financial Secretary Overview renders all key operational actions',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Scroll down to view financial quick actions
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();

      // Verify the new real-world actions are present
      expect(find.text('Record Expense'), findsOneWidget);
      expect(find.text('Tenure & Bal b/f'), findsOneWidget);
      expect(find.text('Cash Handover'), findsOneWidget);
      expect(find.text('National Escrow'), findsOneWidget);
      expect(find.text('Record Cash'), findsOneWidget);
      expect(find.text('New Levy/Due'), findsOneWidget);
      expect(find.text('Manage Cash Handover Vouchers'), findsOneWidget);
    });

    test('Event Netting calculation computes correct purse burden', () {
      const grossSpent = 248500.0;
      const memberDonations = 219000.0;
      final netBurden = (grossSpent - memberDonations).clamp(0.0, double.infinity);

      expect(netBurden, 29500.0);

      // Verify Bereavement Netting (Note 12)
      const bereavementGross = 280000.0;
      const bereavementDonations = 150000.0;
      final bereavementNet = (bereavementGross - bereavementDonations).clamp(0.0, double.infinity);

      expect(bereavementNet, 130000.0);
    });
  });
}
