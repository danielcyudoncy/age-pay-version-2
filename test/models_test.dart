import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/obligations/models/obligation_model.dart';
import 'package:cls/features/payments/models/payment_model.dart';
import 'package:cls/features/expenses/models/expense_model.dart';
import 'package:cls/features/levies/models/levy_model.dart';
import 'package:cls/features/receipts/models/receipt_model.dart';

void main() {
  group('MemberModel', () {
    final now = DateTime(2024, 6, 1);

    test('copyWith creates correct copy', () {
      final member = MemberModel(
        id: '1',
        userId: 'user1',
        fullName: 'John Doe',
        email: 'john@test.com',
        phoneNumber: '+1234567890',
        dateOfBirth: now,
        joinedDate: now,
        createdAt: now,
        updatedAt: now,
      );

      final copy = member.copyWith(fullName: 'Jane Doe');

      expect(copy.id, '1');
      expect(copy.fullName, 'Jane Doe');
      expect(copy.email, 'john@test.com');
    });
  });

  group('ObligationModel', () {
    final now = DateTime(2024, 6, 1);

    test('copyWith updates fields correctly', () {
      final obligation = ObligationModel(
        id: '1',
        memberId: 'member1',
        levyId: 'levy1',
        type: ObligationType.monthlyDue,
        title: 'Monthly Due June',
        description: 'Monthly contribution',
        amount: 100.0,
        dueDate: now,
        createdAt: now,
      );

      final copy = obligation.copyWith(
        status: ObligationStatus.partial,
        paidAmount: 50.0,
      );

      expect(copy.status, ObligationStatus.partial);
      expect(copy.paidAmount, 50.0);
      expect(copy.amount, 100.0);
    });

    test('defaults to unpaid and zero paid amount', () {
      final obligation = ObligationModel(
        id: '1',
        memberId: 'member1',
        levyId: 'levy1',
        type: ObligationType.specialLevy,
        title: 'Levy',
        description: 'Special levy',
        amount: 500.0,
        dueDate: DateTime(2024, 6, 30),
        createdAt: DateTime(2024, 6, 1),
      );

      expect(obligation.status, ObligationStatus.unpaid);
      expect(obligation.paidAmount, 0.0);
      expect(obligation.outstandingBalance, 0.0);
    });
  });

  group('PaymentModel', () {
    final now = DateTime(2024, 6, 1);

    test('allocations are preserved in copy', () {
      final payment = PaymentModel(
        id: '1',
        memberId: 'member1',
        amount: 150.0,
        method: PaymentMethod.cash,
        allocations: [
          PaymentAllocationModel(obligationId: 'obl1', amount: 100.0),
          PaymentAllocationModel(obligationId: 'obl2', amount: 50.0),
        ],
        createdAt: now,
      );

      final copy = payment.copyWith(status: PaymentStatus.approved);

      expect(copy.allocations.length, 2);
      expect(copy.allocations[0].obligationId, 'obl1');
      expect(copy.allocations[1].amount, 50.0);
      expect(copy.status, PaymentStatus.approved);
    });
  });

  group('ExpenseModel', () {
    final now = DateTime(2024, 6, 1);

    test('category defaults correctly', () {
      final expense = ExpenseModel(
        id: '1',
        title: 'Office Supplies',
        description: 'Printer paper',
        amount: 50.0,
        category: ExpenseCategory.administration,
        createdBy: 'user1',
        expenseDate: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(expense.category, ExpenseCategory.administration);
      expect(expense.receiptUrl, isNull);
    });
  });

  group('LevyModel', () {
    final now = DateTime(2024, 6, 1);

    test('targetGroup can be null', () {
      final levy = LevyModel(
        id: '1',
        title: 'Building Project',
        description: 'Community hall fund',
        type: ObligationType.projectContribution,
        amountPerMember: 1000.0,
        dueDate: now,
        createdBy: 'user1',
        createdAt: now,
        updatedAt: now,
      );

      expect(levy.targetGroup, isNull);
      expect(levy.isActive, true);
    });
  });

  group('ReceiptModel', () {
    final now = DateTime(2024, 6, 1);

    test('allocated obligations are stored', () {
      final receipt = ReceiptModel(
        id: '1',
        receiptNumber: 'RCP-2024-001',
        paymentId: 'pay1',
        memberId: 'member1',
        memberName: 'John Doe',
        amount: 200.0,
        method: PaymentMethod.bankTransfer,
        paymentDate: now,
        allocatedObligations: [
          {'obligationId': 'obl1', 'title': 'Monthly Due', 'amount': 100.0},
          {'obligationId': 'obl2', 'title': 'Special Levy', 'amount': 100.0},
        ],
        createdAt: now,
      );

      expect(receipt.allocatedObligations.length, 2);
      expect(receipt.receiptNumber, 'RCP-2024-001');
      expect(receipt.pdfUrl, isNull);
    });
  });
}
