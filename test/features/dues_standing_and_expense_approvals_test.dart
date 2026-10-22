import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/expenses/models/expense_model.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/auth/models/user_model.dart';

void main() {
  group('Issue 1: Member Dues Standing & Opening Balance', () {
    test('MemberDuesStanding enum values are defined correctly', () {
      expect(MemberDuesStanding.values, contains(MemberDuesStanding.cleared));
      expect(MemberDuesStanding.values, contains(MemberDuesStanding.openingBalance));
      expect(MemberDuesStanding.values, contains(MemberDuesStanding.newMember));
    });

    test('UserModel serializes and copies duesStanding and openingBalance', () {
      final user = UserModel(
        uid: 'user1',
        email: 'user1@example.com',
        displayName: 'Existing Member',
        phoneNumber: '08012345678',
        role: UserRole.member,
        organizationId: 'org1',
        duesStanding: MemberDuesStanding.cleared,
        openingBalance: 0.0,
        createdAt: DateTime(2026, 1, 1),
      );

      final map = user.toFirestore();
      expect(map['duesStanding'], equals('cleared'));
      expect(map['openingBalance'], equals(0.0));

      final updated = user.copyWith(
        duesStanding: MemberDuesStanding.openingBalance,
        openingBalance: 25000.0,
      );
      expect(updated.duesStanding, equals(MemberDuesStanding.openingBalance));
      expect(updated.openingBalance, equals(25000.0));
      expect(updated.toFirestore()['openingBalance'], equals(25000.0));
    });

    test('MemberModel serializes and copies duesStanding and openingBalance', () {
      final member = MemberModel(
        id: 'mem1',
        userId: 'user1',
        fullName: 'Member Name',
        email: 'mem@example.com',
        phoneNumber: '08011112222',
        dateOfBirth: DateTime(1990, 1, 1),
        joinedDate: DateTime(2026, 1, 1),
        duesStanding: MemberDuesStanding.openingBalance,
        openingBalance: 15000.0,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final map = member.toFirestore();
      expect(map['duesStanding'], equals('openingBalance'));
      expect(map['openingBalance'], equals(15000.0));

      final cleared = member.copyWith(
        duesStanding: MemberDuesStanding.cleared,
        openingBalance: 0.0,
      );
      expect(cleared.duesStanding, equals(MemberDuesStanding.cleared));
      expect(cleared.openingBalance, equals(0.0));
    });
  });

  group('Issue 2: 3-Executive Multi-Approval Workflow for Expenses', () {
    test('ExpenseModel defaults to pendingApproval and tracks individual role sign-offs', () {
      final expense = ExpenseModel(
        id: 'exp100',
        title: 'Hall Renovation',
        description: 'Repainting hall',
        amount: 150000.0,
        category: ExpenseCategory.projects,
        createdBy: 'treasurer1',
        status: ExpenseStatus.pendingApproval,
        approvals: {
          'president': false,
          'financialSecretary': false,
          'secretary': false,
        },
        expenseDate: DateTime(2026, 6, 1),
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      );

      expect(expense.status, equals(ExpenseStatus.pendingApproval));
      expect(expense.isPresidentApproved, isFalse);
      expect(expense.isFinancialSecretaryApproved, isFalse);
      expect(expense.isSecretaryApproved, isFalse);
      expect(expense.approvedCount, equals(0));
      expect(expense.isFullyApproved, isFalse);
    });

    test('ExpenseModel updates approval count and detects full 3-executive approval', () {
      var expense = ExpenseModel(
        id: 'exp100',
        title: 'Hall Renovation',
        description: 'Repainting hall',
        amount: 150000.0,
        category: ExpenseCategory.projects,
        createdBy: 'treasurer1',
        status: ExpenseStatus.pendingApproval,
        approvals: {},
        expenseDate: DateTime(2026, 6, 1),
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      );

      // 1. President signs off
      expense = expense.copyWith(
        approvals: {...expense.approvals, 'president': true},
      );
      expect(expense.isPresidentApproved, isTrue);
      expect(expense.approvedCount, equals(1));
      expect(expense.isFullyApproved, isFalse);

      // 2. Financial Secretary signs off
      expense = expense.copyWith(
        approvals: {...expense.approvals, 'financialSecretary': true},
      );
      expect(expense.isFinancialSecretaryApproved, isTrue);
      expect(expense.approvedCount, equals(2));
      expect(expense.isFullyApproved, isFalse);

      // 3. Secretary signs off
      expense = expense.copyWith(
        approvals: {...expense.approvals, 'secretary': true},
        status: ExpenseStatus.approved,
      );
      expect(expense.isSecretaryApproved, isTrue);
      expect(expense.approvedCount, equals(3));
      expect(expense.isFullyApproved, isTrue);
      expect(expense.status, equals(ExpenseStatus.approved));
    });

    test('Expense deduction rule: only ExpenseStatus.approved is summed for net position', () {
      final expenses = [
        ExpenseModel(
          id: 'exp1',
          title: 'Approved Generator Fuel',
          description: '',
          amount: 25000.0,
          category: ExpenseCategory.administration,
          createdBy: 'treasurer1',
          status: ExpenseStatus.approved,
          expenseDate: DateTime(2026, 6, 1),
          createdAt: DateTime(2026, 6, 1),
          updatedAt: DateTime(2026, 6, 1),
        ),
        ExpenseModel(
          id: 'exp2',
          title: 'Pending Youth Welfare',
          description: '',
          amount: 80000.0,
          category: ExpenseCategory.welfare,
          createdBy: 'treasurer1',
          status: ExpenseStatus.pendingApproval,
          expenseDate: DateTime(2026, 6, 5),
          createdAt: DateTime(2026, 6, 5),
          updatedAt: DateTime(2026, 6, 5),
        ),
        ExpenseModel(
          id: 'exp3',
          title: 'Rejected Party Snacks',
          description: '',
          amount: 15000.0,
          category: ExpenseCategory.events,
          createdBy: 'treasurer1',
          status: ExpenseStatus.rejected,
          rejectionReason: 'Not budgeted',
          expenseDate: DateTime(2026, 6, 8),
          createdAt: DateTime(2026, 6, 8),
          updatedAt: DateTime(2026, 6, 8),
        ),
      ];

      // Approved expenses only
      final approvedTotal = expenses
          .where((e) => e.status == ExpenseStatus.approved)
          .fold<double>(0.0, (sum, e) => sum + e.amount);
      expect(approvedTotal, equals(25000.0));

      // Pending total is tracked separately without debiting general funds
      final pendingTotal = expenses
          .where((e) => e.status == ExpenseStatus.pendingApproval)
          .fold<double>(0.0, (sum, e) => sum + e.amount);
      expect(pendingTotal, equals(80000.0));

      // Net position verification
      const totalCollected = 500000.0;
      final netPosition = totalCollected - approvedTotal;
      expect(netPosition, equals(475000.0));
      // Verify pending expenses did NOT reduce the net position
      expect(netPosition, isNot(equals(totalCollected - approvedTotal - pendingTotal)));
    });
  });
}
