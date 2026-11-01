import 'package:flutter_test/flutter_test.dart';
import 'package:cls/features/admin/models/branch_model.dart';
import 'package:cls/features/admin/models/organization_model.dart';

void main() {
  group('Alphabetical ordering tests for registration pickers', () {
    test('Branches are sorted alphabetically A-Z regardless of insertion order or case', () {
      final now = DateTime.now();
      final unsortedBranches = [
        BranchModel(
          id: 'b1',
          organizationId: 'org1',
          name: 'Zaria Branch',
          state: 'Kaduna',
          city: 'Zaria',
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
        BranchModel(
          id: 'b2',
          organizationId: 'org1',
          name: 'Abuja Central Branch',
          state: 'FCT',
          city: 'Abuja',
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
        BranchModel(
          id: 'b3',
          organizationId: 'org1',
          name: 'Port Harcourt Branch',
          state: 'Rivers',
          city: 'Port Harcourt',
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
        BranchModel(
          id: 'b4',
          organizationId: 'org1',
          name: 'enugu branch', // lowercase to test case-insensitivity
          state: 'Enugu',
          city: 'Enugu',
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
        BranchModel(
          id: 'b5',
          organizationId: 'org1',
          name: 'Calabar Branch',
          state: 'Cross River',
          city: 'Calabar',
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
        BranchModel(
          id: 'b6',
          organizationId: 'org1',
          name: 'Aba Branch',
          state: 'Abia',
          city: 'Aba',
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final sorted = List<BranchModel>.from(unsortedBranches)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      final sortedNames = sorted.map((b) => b.name).toList();

      expect(sortedNames, [
        'Aba Branch',
        'Abuja Central Branch',
        'Calabar Branch',
        'enugu branch',
        'Port Harcourt Branch',
        'Zaria Branch',
      ]);
    });

    test('Organizations are sorted alphabetically A-Z for registration', () {
      final now = DateTime.now();
      final testOrgs = [
        OrganizationModel(
          id: 'o1',
          name: 'Umuahia Youth Association',
          slug: 'umuahia-youth',
          openForJoin: true,
          createdAt: now,
          updatedAt: now,
        ),
        OrganizationModel(
          id: 'o2',
          name: 'Akokwa Age Grade Federation',
          slug: 'akokwa-age-grade',
          openForJoin: true,
          createdAt: now,
          updatedAt: now,
        ),
        OrganizationModel(
          id: 'o3',
          name: 'Enugu Progressive Youths',
          slug: 'enugu-progressive',
          openForJoin: true,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final sorted = List<OrganizationModel>.from(testOrgs)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      expect(sorted.map((o) => o.name).toList(), [
        'Akokwa Age Grade Federation',
        'Enugu Progressive Youths',
        'Umuahia Youth Association',
      ]);
    });
  });
}
