import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/obligations/models/obligation_model.dart';
import 'package:cls/features/levies/models/levy_model.dart';

void main() {
  group('New Member General Dues Reconciliation & Organization Scoping', () {
    test('ObligationModel serializes and copies organizationId correctly', () {
      final now = DateTime(2026, 6, 1);
      final obligation = ObligationModel(
        id: 'obl_1',
        organizationId: 'org_123',
        memberId: 'mem_1',
        levyId: 'levy_1',
        type: ObligationType.monthlyDue,
        title: 'Monthly Due - June',
        description: 'Monthly dues',
        amount: 5000.0,
        paidAmount: 0.0,
        outstandingBalance: 5000.0,
        status: ObligationStatus.unpaid,
        dueDate: now.add(const Duration(days: 30)),
        createdAt: now,
      );

      final firestoreMap = obligation.toFirestore();
      expect(firestoreMap['organizationId'], equals('org_123'));
      expect(firestoreMap['type'], equals('monthlyDue'));
      expect(firestoreMap['amount'], equals(5000.0));

      final updated = obligation.copyWith(organizationId: 'org_456');
      expect(updated.organizationId, equals('org_456'));
      expect(updated.toFirestore()['organizationId'], equals('org_456'));
    });

    test('LevyModel serializes and copies organizationId correctly', () {
      final now = DateTime(2026, 6, 1);
      final levy = LevyModel(
        id: 'levy_1',
        organizationId: 'org_123',
        title: 'Annual General Dues',
        description: 'General dues for all members',
        type: ObligationType.monthlyDue,
        amountPerMember: 12000.0,
        targetGroup: 'all',
        dueDate: now.add(const Duration(days: 60)),
        createdBy: 'admin_1',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final map = levy.toFirestore();
      expect(map['organizationId'], equals('org_123'));
      expect(map['type'], equals('monthlyDue'));
      expect(map['targetGroup'], equals('all'));

      final updated = levy.copyWith(targetGroup: 'custom');
      expect(updated.targetGroup, equals('custom'));
      expect(updated.toFirestore()['targetGroup'], equals('custom'));
    });

    test('General Dues Filter Rule: ONLY monthlyDue with all/null targetGroup qualifies', () {
      final now = DateTime(2026, 6, 1);
      final levies = [
        LevyModel(
          id: 'l1',
          organizationId: 'org_A',
          title: 'Monthly General Dues',
          description: 'Standard dues for all members',
          type: ObligationType.monthlyDue,
          amountPerMember: 5000.0,
          targetGroup: 'all',
          dueDate: now,
          createdBy: 'admin',
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
        LevyModel(
          id: 'l2',
          organizationId: 'org_A',
          title: 'Regular Dues (Null group)',
          description: 'Standard dues with no targetGroup specified',
          type: ObligationType.monthlyDue,
          amountPerMember: 5000.0,
          targetGroup: null,
          dueDate: now,
          createdBy: 'admin',
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
        LevyModel(
          id: 'l3',
          organizationId: 'org_A',
          title: 'Special Hall Levy',
          description: 'Development levy',
          type: ObligationType.specialLevy,
          amountPerMember: 20000.0,
          targetGroup: 'all',
          dueDate: now,
          createdBy: 'admin',
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
        LevyModel(
          id: 'l4',
          organizationId: 'org_A',
          title: 'Executive Dues',
          description: 'Dues for executive members only',
          type: ObligationType.monthlyDue,
          amountPerMember: 10000.0,
          targetGroup: 'executives',
          dueDate: now,
          createdBy: 'admin',
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
        LevyModel(
          id: 'l5',
          organizationId: 'org_B',
          title: 'Other Organization Dues',
          description: 'Dues from another organization',
          type: ObligationType.monthlyDue,
          amountPerMember: 7000.0,
          targetGroup: 'all',
          dueDate: now,
          createdBy: 'admin_b',
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      const currentOrgId = 'org_A';

      // Apply the reconciliation qualification rules
      final qualifiedForNewMember = levies.where((levy) {
        // Multi-tenant check
        if (levy.organizationId.isNotEmpty && levy.organizationId != currentOrgId) {
          return false;
        }
        // General dues check
        final isGeneralDue = levy.type == ObligationType.monthlyDue;
        final targetGroupLower = levy.targetGroup?.trim().toLowerCase();
        final isSharedWithAll = targetGroupLower == null ||
            targetGroupLower.isEmpty ||
            targetGroupLower == 'all';
        return isGeneralDue && isSharedWithAll;
      }).toList();

      expect(qualifiedForNewMember.length, equals(2));
      expect(qualifiedForNewMember.map((l) => l.id), containsAll(['l1', 'l2']));
      expect(qualifiedForNewMember.map((l) => l.id), isNot(contains('l3'))); // Excludes specialLevy
      expect(qualifiedForNewMember.map((l) => l.id), isNot(contains('l4'))); // Excludes targeted executive levy
      expect(qualifiedForNewMember.map((l) => l.id), isNot(contains('l5'))); // Excludes other organization
    });
  });
}
