import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/expenses/models/expense_model.dart';
import 'package:cls/features/fiscal_period/models/fiscal_period_model.dart';
import 'package:cls/features/national/models/national_remittance_model.dart';
import 'package:cls/features/financial_secretary/models/cash_handover_model.dart';

void main() {
  group('Phase 1: Domain & Data Models Tests', () {
    test('FiscalPeriodModel serialization, calculations, and copyWith', () {
      final now = DateTime(2026, 11, 6);
      final startDate = DateTime(2025, 7, 1);
      final endDate = DateTime(2026, 10, 31);

      final period = FiscalPeriodModel(
        id: 'fp-1',
        organizationId: 'org-onyirimba',
        branchId: 'lagos-branch',
        title: '2025/2026 Executive Tenure',
        startDate: startDate,
        endDate: endDate,
        openingBalance: 805000.0,
        openingCashAtBank: 750000.0,
        openingCashInHand: 55000.0,
        notes: 'Balance brought forward as at 1/7/25',
        isActive: true,
        createdBy: 'user-finsec-1',
        createdAt: now,
        updatedAt: now,
      );

      final map = period.toFirestore();
      expect(map['organizationId'], 'org-onyirimba');
      expect(map['branchId'], 'lagos-branch');
      expect(map['openingBalance'], 805000.0);
      expect(map['openingCashAtBank'], 750000.0);
      expect(map['openingCashInHand'], 55000.0);
      expect(map['isActive'], true);

      final updated = period.copyWith(openingBalance: 810000.0);
      expect(updated.openingBalance, 810000.0);
      expect(updated.title, '2025/2026 Executive Tenure');
    });

    test('ExpenseCategory supports all new community categories', () {
      expect(ExpenseCategory.assetsAndUtensils.displayName,
          'Utensils & Assets (Plates, Spoons)');
      expect(ExpenseCategory.meetingRefreshment.displayName,
          'Meeting Refreshment & Host Bailout');
      expect(ExpenseCategory.delegationAndTransport.displayName,
          'Delegation & Transportation');
      expect(ExpenseCategory.communications.displayName,
          'SMS, Calls & Broadcasts');
    });

    test('ExpenseModel supports gross amount, event deduction netting, and noteRef', () {
      final now = DateTime(2026, 11, 6);
      final expense = ExpenseModel(
        id: 'exp-edu-hosting',
        organizationId: 'org-onyirimba',
        branchId: 'lagos-branch',
        title: 'Additional EDU Hosting Expenses',
        description: 'Hosted EDU meeting; spent 248,500, contributed 219,000',
        amount: 29500.0, // net burden from branch purse
        grossAmount: 248500.0,
        contributionsDeduction: 219000.0,
        noteRef: 'Note 7',
        category: ExpenseCategory.meetingRefreshment,
        createdBy: 'fin-sec-1',
        expenseDate: DateTime(2025, 8, 15),
        status: ExpenseStatus.approved,
        createdAt: now,
        updatedAt: now,
      );

      expect(expense.amount, 29500.0);
      expect(expense.grossAmount, 248500.0);
      expect(expense.contributionsDeduction, 219000.0);
      expect(expense.noteRef, 'Note 7');
      expect(expense.grossAmount! - expense.contributionsDeduction!, expense.amount);

      final firestoreMap = expense.toFirestore();
      expect(firestoreMap['amount'], 29500.0);
      expect(firestoreMap['grossAmount'], 248500.0);
      expect(firestoreMap['contributionsDeduction'], 219000.0);
      expect(firestoreMap['noteRef'], 'Note 7');
      expect(firestoreMap['category'], ExpenseCategory.meetingRefreshment.name);
    });

    test('NationalRemittanceModel correctly tracks collected, remitted, and unremitted balance', () {
      final now = DateTime(2026, 11, 6);
      final remittance = NationalRemittanceModel(
        id: 'remit-burial-1',
        organizationId: 'org-onyirimba',
        branchId: 'lagos-branch',
        branchName: 'Lagos Branch',
        levyId: 'levy-national-burial',
        levyTitle: 'National Burial Levies',
        totalCollected: 103000.0,
        amountRemitted: 75000.0,
        unremittedBalance: 28000.0,
        remittedAt: DateTime(2026, 9, 20),
        remittedBy: 'Financial Secretary',
        recipientRef: 'National Treasurer Receipt #045',
        notes: 'Note 4: The money belongs to National but they have not requested for balance yet',
        createdBy: 'user-finsec-1',
        createdAt: now,
        updatedAt: now,
      );

      expect(remittance.totalCollected, 103000.0);
      expect(remittance.amountRemitted, 75000.0);
      expect(remittance.unremittedBalance, 28000.0);
      expect(remittance.totalCollected - remittance.amountRemitted, remittance.unremittedBalance);

      final map = remittance.toFirestore();
      expect(map['totalCollected'], 103000.0);
      expect(map['amountRemitted'], 75000.0);
      expect(map['unremittedBalance'], 28000.0);
    });

    test('CashHandoverModel handles status transitions and bank deposit metadata', () {
      final now = DateTime(2026, 11, 6);
      final handover = CashHandoverModel(
        id: 'ho-1',
        organizationId: 'org-onyirimba',
        branchId: 'lagos-branch',
        amount: 150000.0,
        handedOverBy: 'Emeka FinSec',
        handedOverById: 'uid-finsec-1',
        handedOverAt: now,
        status: CashHandoverStatus.pending,
        notes: 'Monthly dues collected during October 2026 meeting',
        createdBy: 'uid-finsec-1',
        createdAt: now,
        updatedAt: now,
      );

      expect(handover.status, CashHandoverStatus.pending);
      expect(handover.amount, 150000.0);

      // Treasurer accepts and deposits
      final accepted = handover.copyWith(
        status: CashHandoverStatus.accepted,
        receivedBy: 'Chief Okonkwo Treasurer',
        receivedById: 'uid-treasurer-1',
        acknowledgedAt: now.add(const Duration(hours: 2)),
        bankName: 'First Bank PLC',
        bankAccountNumber: '3012345678',
        depositSlipUrl: 'https://example.com/slips/oct2026.pdf',
      );

      expect(accepted.status, CashHandoverStatus.accepted);
      expect(accepted.receivedBy, 'Chief Okonkwo Treasurer');
      expect(accepted.bankName, 'First Bank PLC');
      expect(accepted.bankAccountNumber, '3012345678');
    });
  });
}
