// test/reports_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/expenses/models/expense_model.dart';
import 'package:cls/features/levies/models/levy_model.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/obligations/models/obligation_model.dart';
import 'package:cls/features/payments/models/payment_model.dart';
import 'package:cls/features/auth/services/auth_service.dart';
import 'package:cls/features/reports/services/pdf_service.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/reports/views/reports_screen.dart';

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

void main() {
  final now = DateTime(2024, 6, 1);

  final testMember = MemberModel(
    id: 'm1',
    userId: 'u1',
    fullName: 'John Doe',
    email: 'john@test.com',
    phoneNumber: '+2348012345678',
    dateOfBirth: now,
    joinedDate: now,
    createdAt: now,
    updatedAt: now,
  );

  final testLevy = LevyModel(
    id: 'l1',
    title: 'Test Levy',
    description: 'Test levy description',
    type: ObligationType.monthlyDue,
    amountPerMember: 1000.0,
    dueDate: now,
    createdBy: 'admin',
    createdAt: now,
    updatedAt: now,
  );

  final testObligation = ObligationModel(
    id: 'o1',
    memberId: 'm1',
    levyId: 'l1',
    type: ObligationType.monthlyDue,
    title: 'Monthly Due June',
    description: 'Monthly contribution',
    amount: 100.0,
    dueDate: now,
    createdAt: now,
  );

  final testPayment = PaymentModel(
    id: 'p1',
    memberId: 'm1',
    amount: 150.0,
    method: PaymentMethod.cash,
    allocations: const [],
    createdAt: now,
  );

  final testExpense = ExpenseModel(
    id: 'e1',
    title: 'Office Supplies',
    description: 'Printer paper',
    amount: 50.0,
    category: ExpenseCategory.administration,
    createdBy: 'user1',
    expenseDate: now,
    createdAt: now,
    updatedAt: now,
  );

  final presidentUser = UserModel(
    uid: 'president1',
    email: 'president@test.com',
    displayName: 'President User',
    phoneNumber: '+2348000000001',
    role: UserRole.president,
    createdAt: now,
  );

  final mockAuthService = _MockAuthService(presidentUser);

  group('PdfService', () {
    final pdfService = PdfService();

    test('generates member statement bytes', () async {
      final bytes = await pdfService.generateMemberStatement(
        member: testMember,
        obligations: [testObligation],
        payments: [testPayment],
        reportDate: now,
      );
      expect(bytes.length, greaterThan(100));
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });

    test('generates levy report bytes', () async {
      final bytes = await pdfService.generateLevyReport(
        levy: testLevy,
        obligations: [testObligation],
        payments: [testPayment],
        totalMembers: 10,
      );
      expect(bytes.length, greaterThan(100));
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });

    test('generates yearly summary bytes', () async {
      final bytes = await pdfService.generateYearlySummary(
        year: 2024,
        payments: [testPayment],
        expenses: [testExpense],
        obligations: [testObligation],
      );
      expect(bytes.length, greaterThan(100));
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });

    test('generates expense breakdown bytes', () async {
      final bytes = await pdfService.generateExpenseBreakdown(
        expenses: [testExpense],
        startDate: now,
        endDate: now,
      );
      expect(bytes.length, greaterThan(100));
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });

    test('generates financial summary bytes', () async {
      final bytes = await pdfService.generateFinancialSummary(
        payments: [testPayment],
        expenses: [testExpense],
        members: [testMember],
        obligations: [testObligation],
        startDate: now,
        endDate: now,
      );
      expect(bytes.length, greaterThan(100));
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
  });

  group('ReportsScreen', () {
    testWidgets('renders report type list', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
          child: MaterialApp(home: const ReportsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Member Statement'), findsOneWidget);
      expect(find.text('Levy Report'), findsOneWidget);
      expect(find.text('Yearly Summary'), findsOneWidget);
      expect(find.text('Expense Breakdown'), findsOneWidget);
      expect(find.text('Financial Summary'), findsOneWidget);
    });
  });
}
