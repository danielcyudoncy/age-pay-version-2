import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/models/user_model.dart';

void main() {
  group('Public Relations Officer (PRO) Role Tests', () {
    test('UserRole.publicRelationsOfficer has correct properties', () {
      const role = UserRole.publicRelationsOfficer;

      expect(role.displayName, 'Public Relations Officer');
      expect(role.isExecutive, isTrue);
      expect(role.name, 'publicRelationsOfficer');
    });

    test('UserModel constructed with PRO role serializes correctly', () {
      final user = UserModel(
        uid: 'pro-user-1',
        organizationId: 'org-123',
        email: 'pro@agepay.org',
        displayName: 'Test PRO Officer',
        phoneNumber: '+234800000000',
        role: UserRole.publicRelationsOfficer,
        createdAt: DateTime(2026, 1, 1),
      );

      final map = user.toFirestore();
      expect(map['role'], 'publicRelationsOfficer');
      expect(user.role.isExecutive, isTrue);
      expect(user.role.displayName, 'Public Relations Officer');
    });

    test('Role string normalization correctly identifies PRO aliases', () {
      UserRole parseRole(String rawRole) {
        final val = rawRole.trim().toLowerCase();
        return UserRole.values.firstWhere(
          (e) =>
              e.name.toLowerCase() == val ||
              ((val == 'pro' || val == 'public_relations_officer') &&
                  e == UserRole.publicRelationsOfficer),
          orElse: () => UserRole.member,
        );
      }

      expect(parseRole('publicRelationsOfficer'), UserRole.publicRelationsOfficer);
      expect(parseRole('publicrelationsofficer'), UserRole.publicRelationsOfficer);
      expect(parseRole('pro'), UserRole.publicRelationsOfficer);
      expect(parseRole('PRO'), UserRole.publicRelationsOfficer);
      expect(parseRole('public_relations_officer'), UserRole.publicRelationsOfficer);
      expect(parseRole('unknown_role'), UserRole.member);
    });
  });
}
