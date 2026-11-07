import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/services/auth_service.dart';
import 'package:cls/features/expenses/models/expense_model.dart';
import 'package:cls/features/fiscal_period/models/fiscal_period_model.dart';
import 'package:cls/features/national/models/national_remittance_model.dart';
import 'package:cls/features/payments/models/payment_model.dart';
import 'package:cls/features/reports/controllers/reports_provider.dart';
import 'package:cls/features/reports/services/pdf_service.dart';
import 'package:cls/features/reports/views/reports_screen.dart';
import 'package:cls/features/reports/widgets/agm_financial_report_widget.dart';

class _MockAuthService implements AuthService {
  final UserModel? user;
  _MockAuthService(this.user);

  @override
  Future<UserModel?> getCurrentUser() async => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime(2026, 10, 31);
  final tenureStart = DateTime(2025, 7, 1);
  final tenureEnd = DateTime(2026, 10, 31);

  final testPeriod = FiscalPeriodModel(
    id: 'fp_1',
    organizationId: 'org_1',
    branchId: 'branch_lagos',
    title: '2025/2026 Executive Tenure',
    startDate: tenureStart,
    endDate: tenureEnd,
    openingBalance: 805000.0,
    isActive: true,
    createdBy: 'finsec_1',
    createdAt: tenureStart,
    updatedAt: tenureStart,
  );

  final testRemittances = [
    NationalRemittanceModel(
      id: 'rem_1',
      organizationId: 'org_1',
      branchId: 'branch_lagos',
      levyId: 'levy_izarafo',
      levyTitle: 'Izarafo / National Dues',
      totalCollected: 54000.0,
      amountRemitted: 0.0,
      unremittedBalance: 54000.0,
      createdBy: 'finsec_1',
      createdAt: tenureStart,
      updatedAt: tenureStart,
    ),
    NationalRemittanceModel(
      id: 'rem_2',
      organizationId: 'org_1',
      branchId: 'branch_lagos',
      levyId: 'levy_burial',
      levyTitle: 'National Burial Levies',
      totalCollected: 103000.0,
      amountRemitted: 75000.0,
      unremittedBalance: 28000.0,
      createdBy: 'finsec_1',
      createdAt: tenureStart,
      updatedAt: tenureStart,
    ),
  ];

  final testPayments = [
    PaymentModel(
      id: 'p_1',
      memberId: 'm_1',
      amount: 296000.0,
      method: PaymentMethod.cash,
      allocations: const [],
      notes: 'Monthly dues collection',
      createdAt: DateTime(2026, 3, 1),
    ),
    PaymentModel(
      id: 'p_2',
      memberId: 'm_2',
      amount: 10000.0,
      method: PaymentMethod.bankTransfer,
      allocations: const [],
      notes: 'New member registration fee',
      createdAt: DateTime(2026, 4, 1),
    ),
  ];

  final testExpenses = [
    ExpenseModel(
      id: 'e_1',
      title: 'Hosting of EDU',
      description: 'Lagos Branch hosting of EDU general meeting',
      amount: 29500.0,
      grossAmount: 248500.0,
      contributionsDeduction: 219000.0,
      noteRef: 'Note 7',
      category: ExpenseCategory.events,
      createdBy: 'finsec_1',
      expenseDate: DateTime(2026, 5, 10),
      createdAt: DateTime(2026, 5, 10),
      updatedAt: DateTime(2026, 5, 10),
    ),
    ExpenseModel(
      id: 'e_2',
      title: 'Assets and Utensils',
      description: 'Coolers, spoons, and 50 meeting chairs',
      amount: 54000.0,
      noteRef: 'Note 5',
      category: ExpenseCategory.assetsAndUtensils,
      createdBy: 'finsec_1',
      expenseDate: DateTime(2025, 8, 15),
      createdAt: DateTime(2025, 8, 15),
      updatedAt: DateTime(2025, 8, 15),
    ),
  ];

  final finSecUser = UserModel(
    uid: 'finsec_1',
    organizationId: 'org_1',
    branchId: 'branch_lagos',
    email: 'finsec@agegrade.org',
    displayName: 'Chief Financial Secretary',
    phoneNumber: '+2348030000001',
    role: UserRole.financialSecretary,
    createdAt: now,
  );

  final mockAuthService = _MockAuthService(finSecUser);

  group('Phase 4: AGM Financial Report PDF Generation', () {
    final pdfService = PdfService();

    test('generates valid multi-page AGM financial report PDF bytes', () async {
      final bytes = await pdfService.generateAgmFinancialReport(
        fiscalPeriod: testPeriod,
        startDate: tenureStart,
        endDate: tenureEnd,
        payments: testPayments,
        expenses: testExpenses,
        remittances: testRemittances,
        organizationName: 'Onyirimba Age Grade',
        branchName: 'Elu Ohafia, Lagos Branch',
      );

      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
  });

  group('Phase 4: Reports Screen AGM Card', () {
    testWidgets('renders AGM Annual Financial Report option in reports list', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
          child: const MaterialApp(home: ReportsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AGM Annual Financial Report'), findsOneWidget);
      expect(
        find.textContaining('Official Receipts & Disbursements statement'),
        findsOneWidget,
      );
    });
  });

  group('Phase 4: AgmFinancialReportWidget Interactive View', () {
    testWidgets('renders Page 1 Statement with Bal b/f, Gross, and Closing Bal', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final request = ReportRequest(
        type: ReportType.agmFinancialReport,
        fiscalPeriod: testPeriod,
        startDate: tenureStart,
        endDate: tenureEnd,
        payments: testPayments,
        expenses: testExpenses,
        remittances: testRemittances,
        organizationName: 'Onyirimba Age Grade',
        branchName: 'Elu Ohafia, Lagos Branch',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgmFinancialReportWidget(request: request),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Header info
      expect(find.text('ONYIRIMBA AGE GRADE'), findsOneWidget);
      expect(find.text('ELU OHAFIA, LAGOS BRANCH'), findsOneWidget);
      expect(find.textContaining('Financial Report as at'), findsOneWidget);

      // Check Opening Balance b/f
      expect(find.textContaining('Bal b/f'), findsWidgets);
      expect(find.text('₦805,000'), findsWidgets);

      // Check Total Gross Value Available
      expect(find.text('Total Gross Value'), findsOneWidget);

      // Check Closing Balance
      expect(find.text('Bal at hand / Bank'), findsWidgets);

      // Check Signatures
      expect(find.text('Prepared by: Financial Secretary'), findsOneWidget);
      expect(find.text('Certified by: Treasurer'), findsOneWidget);

      // Switch to Notes Tab
      await tester.tap(find.text('Pages 2–4: Notes to Account'));
      await tester.pumpAndSettle();

      expect(find.text('NOTES TO THE ACCOUNT'), findsOneWidget);
      expect(find.text('Note 1'), findsOneWidget);
      expect(find.text('Note 2'), findsOneWidget);
      expect(find.text('Note 3'), findsOneWidget);
      expect(find.text('Note 4'), findsOneWidget);

      // Verify dynamic expense notes and reconciliation
      await tester.drag(find.byType(ListView).last, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('Note 7'), findsOneWidget);
      expect(find.text('Summary of Bank & Cash at Hand'), findsOneWidget);
    });
  });
}
