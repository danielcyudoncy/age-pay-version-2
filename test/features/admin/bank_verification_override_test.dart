import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/admin/models/organization_model.dart';
import 'package:cls/features/admin/widgets/edit_organization_bank_dialog.dart';
import 'package:cls/features/admin/widgets/receiving_account_details_dialog.dart';
import 'package:cls/features/admin/controllers/admin_provider.dart';

class _SimpleAuthNotifier extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  _SimpleAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final testOrg = OrganizationModel(
    id: 'org-test-1',
    name: 'Iremba Eluhafe Corporate Association',
    slug: 'iremba-eluhafe',
    bankName: 'First Bank of Nigeria',
    accountNumber: '1234567890',
    accountName: 'Dotun Ben Lagos',
    isBankVerified: true,
    bankVerificationOverridden: true,
    bankVerificationOverrideReason:
        'Former corporate registered name prior to rebrand',
    bankVerificationOverriddenBy: 'superadmin@agepay.com',
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
  );

  final superAdminUser = UserModel(
    uid: 'admin-1',
    displayName: 'Super Admin',
    email: 'superadmin@agepay.com',
    phoneNumber: '+234800000000',
    role: UserRole.superAdmin,
    organizationId: 'org-test-1',
    createdAt: DateTime(2025, 1, 1),
  );

  group('OrganizationModel Bank Verification Override Serialization', () {
    test('toFirestore and fromFirestore preserve override metadata', () {
      final map = testOrg.toFirestore();
      expect(map['bankVerificationOverridden'], isTrue);
      expect(map['bankVerificationOverrideReason'],
          'Former corporate registered name prior to rebrand');
      expect(map['bankVerificationOverriddenBy'], 'superadmin@agepay.com');

      final copied = testOrg.copyWith(
        bankVerificationOverrideReason: 'Updated justification',
      );
      expect(copied.bankVerificationOverrideReason, 'Updated justification');
      expect(copied.bankVerificationOverridden, isTrue);
    });
  });

  group('EditOrganizationBankDialog Super Admin Override UI', () {
    testWidgets('shows Super Admin override switch on name mismatch',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _SimpleAuthNotifier(superAdminUser)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => EditOrganizationBankDialog.show(
                    context,
                    organization: testOrg.copyWith(
                      bankVerificationOverridden: false,
                      bankVerificationOverrideReason: null,
                    ),
                  ),
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Check dialog elements
      expect(find.text('Receiving Bank Account'), findsOneWidget);
      expect(find.text('Super Admin Authority Override'), findsOneWidget);
      expect(
        find.text(
            'Authorize alternate/former entity name for receiving funds'),
        findsOneWidget,
      );

      // Verify switch is present
      expect(find.byType(Switch), findsOneWidget);
    });
  });

  group('ReceivingAccountDetailsDialog Override Display', () {
    testWidgets('renders Admin Override badge and justification reason',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _SimpleAuthNotifier(superAdminUser)),
            currentOrganizationProvider
                .overrideWith((ref) => Stream.value(testOrg)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      ReceivingAccountDetailsDialog.show(context),
                  child: const Text('Open Details'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Details'));
      await tester.pumpAndSettle();

      // Check badge and reason
      expect(find.text('Admin Override'), findsOneWidget);
      expect(find.text('Super Admin Override Approved'), findsOneWidget);
      expect(
        find.text('Former corporate registered name prior to rebrand'),
        findsOneWidget,
      );
    });
  });
}
