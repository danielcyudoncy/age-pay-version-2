import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/admin/controllers/admin_provider.dart';
import 'package:cls/features/admin/models/organization_model.dart';
import 'package:cls/features/admin/repositories/admin_user_repository.dart';
import 'package:cls/features/admin/views/admin_users_screen.dart';
import 'package:cls/features/auth/models/user_model.dart';

class FakeAdminUserRepository implements AdminUserRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream<List<UserModel>> getUsersStream() => const Stream.empty();

  @override
  Future<void> updateUserRole(
    String uid, {
    required UserRole role,
    UserRole? nationalRole,
    bool clearNationalRole = false,
  }) async {}

  @override
  Future<void> updateUserStatus(
    String uid, {
    required bool isActive,
    AccountStatus? status,
  }) async {}

  @override
  Future<void> reassignUserBranch(
    String uid, {
    required String organizationId,
    required String branchId,
    required String branchName,
  }) async {}

  @override
  Future<void> toggleSuperAdmin(String uid, bool isSuperAdmin) async {}
}

void main() {
  final user1 = UserModel(
    uid: 'u-1',
    organizationId: 'org-1',
    email: 'president@naat.org',
    displayName: 'Dr. John Doe',
    phoneNumber: '+234 801 111 2222',
    role: UserRole.president,
    branchId: 'b-1',
    branchName: 'Abuja Branch',
    status: AccountStatus.approved,
    isActive: true,
    createdAt: DateTime(2025, 1, 1),
  );

  final user2 = UserModel(
    uid: 'u-2',
    organizationId: 'org-1',
    email: 'member@naat.org',
    displayName: 'Jane Smith',
    phoneNumber: '+234 802 333 4444',
    role: UserRole.member,
    branchId: 'b-1',
    branchName: 'Abuja Branch',
    status: AccountStatus.pendingApproval,
    isActive: false,
    createdAt: DateTime(2025, 2, 1),
  );

  final user3 = UserModel(
    uid: 'u-3',
    organizationId: 'org-1',
    email: 'superadmin@naat.org',
    displayName: 'System Admin',
    phoneNumber: '+234 803 555 6666',
    role: UserRole.superAdmin,
    nationalRole: UserRole.president,
    branchId: 'b-1',
    branchName: 'National Secretariat',
    status: AccountStatus.approved,
    isActive: true,
    createdAt: DateTime(2025, 1, 1),
  );

  testWidgets('AdminUsersScreen renders users, search, filter chips, and actions', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminUserRepositoryProvider.overrideWithValue(FakeAdminUserRepository()),
          allUsersStreamProvider.overrideWith(
            (ref) => Stream.value([user1, user2, user3]),
          ),
          organizationsStreamProvider.overrideWith(
            (ref) => Stream.value([
              OrganizationModel(
                id: 'org-1',
                name: 'NAAT National',
                slug: 'naat',
                createdAt: DateTime(2025, 1, 1),
                updatedAt: DateTime(2025, 1, 1),
              ),
            ]),
          ),
        ],
        child: const MaterialApp(
          home: AdminUsersScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify app bar title
    expect(find.text('Users & Access Governance'), findsOneWidget);

    // 2. Verify all 3 users are displayed
    expect(find.text('Dr. John Doe'), findsOneWidget);
    expect(find.text('Jane Smith'), findsOneWidget);
    expect(find.text('System Admin'), findsOneWidget);

    // 3. Verify roles and status badges
    expect(find.text('President'), findsOneWidget);
    expect(find.text('Member'), findsOneWidget);
    expect(find.text('Super Admin'), findsOneWidget);
    expect(find.text('National President'), findsOneWidget);

    // 1 chip + 2 cards = 3
    expect(find.text('Approved'), findsNWidgets(3));
    // 1 chip + 1 card = 2
    expect(find.text('Pending Approval'), findsOneWidget);

    // 4. Test Search
    await tester.enterText(find.byType(TextField), 'Jane');
    await tester.pumpAndSettle();

    expect(find.text('Jane Smith'), findsOneWidget);
    expect(find.text('Dr. John Doe'), findsNothing);
    expect(find.text('System Admin'), findsNothing);

    // Clear search
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();

    expect(find.text('Dr. John Doe'), findsOneWidget);
    expect(find.text('Jane Smith'), findsOneWidget);

    // 5. Test Filter by Status: Pending
    await tester.tap(find.text('Pending'));
    await tester.pumpAndSettle();

    expect(find.text('Jane Smith'), findsOneWidget);
    expect(find.text('Dr. John Doe'), findsNothing);

    // Return to All
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    // 6. Test PopupMenu options on first user
    final popupButtons = find.byType(PopupMenuButton<String>);
    expect(popupButtons, findsNWidgets(3));

    await tester.tap(popupButtons.first);
    await tester.pumpAndSettle();

    expect(find.text('Edit Role & Permissions'), findsOneWidget);
    expect(find.text('Reassign Branch / Org'), findsOneWidget);
    expect(find.text('Suspend / Deactivate'), findsOneWidget);
    expect(find.text('Make Super Admin'), findsOneWidget);
  });
}
