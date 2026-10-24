import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/admin/models/branch_model.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/levies/models/levy_model.dart';
import 'package:cls/features/obligations/models/obligation_model.dart';
import 'package:cls/features/national/models/branch_compliance_report.dart';

void main() {
  group('BranchComplianceReport', () {
    test('calculates complianceRate and complianceTier correctly', () {
      const reportA = BranchComplianceReport(
        branchId: 'b1',
        branchName: 'Lagos Branch',
        memberCount: 50,
        totalExpected: 100000.0,
        totalRemitted: 95000.0,
        outstandingBalance: 5000.0,
        complianceRate: 95.0,
      );

      expect(reportA.complianceRate, 95.0);
      expect(reportA.complianceTier, 'Top Performing');

      const reportB = BranchComplianceReport(
        branchId: 'b2',
        branchName: 'Abuja Branch',
        memberCount: 40,
        totalExpected: 100000.0,
        totalRemitted: 75000.0,
        outstandingBalance: 25000.0,
        complianceRate: 75.0,
      );

      expect(reportB.complianceRate, 75.0);
      expect(reportB.complianceTier, 'Compliant');

      const reportC = BranchComplianceReport(
        branchId: 'b3',
        branchName: 'Port Harcourt Branch',
        memberCount: 30,
        totalExpected: 100000.0,
        totalRemitted: 55000.0,
        outstandingBalance: 45000.0,
        complianceRate: 55.0,
      );

      expect(reportC.complianceRate, 55.0);
      expect(reportC.complianceTier, 'In Arrears');

      const reportD = BranchComplianceReport(
        branchId: 'b4',
        branchName: 'Kano Branch',
        memberCount: 20,
        totalExpected: 100000.0,
        totalRemitted: 30000.0,
        outstandingBalance: 70000.0,
        complianceRate: 30.0,
      );

      expect(reportD.complianceRate, 30.0);
      expect(reportD.complianceTier, 'Critical Delay');
    });
  });

  group('UserModel Dual-Role & National Governance', () {
    final now = DateTime(2024, 6, 1);

    test('correctly detects national executive role and serializes nationalRole', () {
      final user = UserModel(
        uid: 'u1',
        organizationId: 'org1',
        email: 'president@lagos.org',
        displayName: 'Chief Emeka',
        phoneNumber: '+2348000000001',
        role: UserRole.president,
        branchId: 'branch_lagos',
        branchName: 'Lagos Branch',
        nationalRole: UserRole.financialSecretary,
        createdAt: now,
      );

      expect(user.role, UserRole.president);
      expect(user.nationalRole, UserRole.financialSecretary);
      expect(user.isNationalExecutive, isTrue);

      final map = user.toFirestore();
      expect(map['nationalRole'], 'financialSecretary');

      final copy = user.copyWith(nationalRole: UserRole.treasurer);
      expect(copy.nationalRole, UserRole.treasurer);
      expect(copy.isNationalExecutive, isTrue);
    });

    test('isNationalExecutive is false for ordinary branch member', () {
      final user = UserModel(
        uid: 'u2',
        organizationId: 'org1',
        email: 'member@lagos.org',
        displayName: 'John Member',
        phoneNumber: '+2348000000002',
        role: UserRole.member,
        createdAt: now,
      );

      expect(user.isNationalExecutive, isFalse);
      expect(user.nationalRole, isNull);
    });
  });

  group('BranchModel National & Bank Account Specifications', () {
    final now = DateTime(2024, 6, 1);

    test('serializes isNational and branch receiving bank details', () {
      final branch = BranchModel(
        id: 'br_national',
        organizationId: 'org1',
        name: 'National Executive Council (HQ)',
        isNational: true,
        bankName: 'Access Bank',
        accountNumber: '0123456789',
        accountName: 'National Association Central Treasury',
        presidentId: 'pres_1',
        presidentName: 'National President',
        financialSecretaryId: 'fin_1',
        financialSecretaryName: 'National Fin Sec',
        createdAt: now,
        updatedAt: now,
      );

      expect(branch.isNational, isTrue);
      expect(branch.bankName, 'Access Bank');
      expect(branch.accountNumber, '0123456789');

      final map = branch.toFirestore();
      expect(map['isNational'], isTrue);
      expect(map['bankName'], 'Access Bank');
      expect(map['accountNumber'], '0123456789');
      expect(map['financialSecretaryName'], 'National Fin Sec');

      final copy = branch.copyWith(bankName: 'Zenith Bank');
      expect(copy.bankName, 'Zenith Bank');
      expect(copy.isNational, isTrue);
    });
  });

  group('Levy and Obligation National Scope', () {
    final now = DateTime(2024, 6, 1);

    test('LevyModel preserves scope and branchId', () {
      final levy = LevyModel(
        id: 'levy_nat_1',
        organizationId: 'org1',
        title: '2026 National Convention Levy',
        description: 'Mandatory remittance for all branches',
        type: ObligationType.specialLevy,
        amountPerMember: 5000.0,
        dueDate: now.add(const Duration(days: 30)),
        createdBy: 'admin_1',
        scope: 'national',
        branchId: null,
        createdAt: now,
        updatedAt: now,
      );

      expect(levy.scope, 'national');
      expect(levy.branchId, isNull);

      final map = levy.toFirestore();
      expect(map['scope'], 'national');
      expect(map['branchId'], isNull);

      final copy = levy.copyWith(scope: 'branch', branchId: 'br_1');
      expect(copy.scope, 'branch');
      expect(copy.branchId, 'br_1');
    });

    test('ObligationModel preserves scope and branchId', () {
      final obligation = ObligationModel(
        id: 'ob_1',
        memberId: 'm1',
        levyId: 'levy_nat_1',
        type: ObligationType.specialLevy,
        title: '2026 National Convention Levy',
        description: 'Mandatory remittance',
        amount: 5000.0,
        dueDate: now.add(const Duration(days: 30)),
        createdAt: now,
        scope: 'national',
        branchId: 'branch_lagos',
      );

      expect(obligation.scope, 'national');
      expect(obligation.branchId, 'branch_lagos');

      final map = obligation.toFirestore();
      expect(map['scope'], 'national');
      expect(map['branchId'], 'branch_lagos');

      final copy = obligation.copyWith(scope: 'branch');
      expect(copy.scope, 'branch');
    });
  });
}
