import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/auth/services/auth_service.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/members/repositories/member_repository.dart';
import 'package:cls/features/secretary/controllers/member_management_provider.dart';
import 'package:cls/features/secretary/views/members_management_screen.dart';

class _MockAuthService implements AuthService {
  final UserModel? user;
  _MockAuthService(this.user);

  @override
  Future<UserModel?> getCurrentUser() async => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockMemberRepository implements MemberRepository {
  final List<MemberModel> members;
  _MockMemberRepository(this.members);

  @override
  Stream<List<MemberModel>> getAllMembers() => Stream.value(members);

  @override
  Stream<List<MemberModel>> getMembers() =>
      Stream.value(members.where((m) => m.isActive).toList());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('MembersManagementScreen & Executive Card Tests', () {
    final secretaryUser = UserModel(
      uid: 'sec_1',
      organizationId: 'org_test',
      email: 'sec@test.com',
      displayName: 'Secretary User',
      phoneNumber: '+2348000000000',
      role: UserRole.secretary,
      branchId: 'branch_lagos',
      branchName: 'Lagos Branch',
      status: AccountStatus.approved,
      createdAt: DateTime.now(),
    );

    final testMembers = [
      MemberModel(
        id: 'm1',
        userId: 'u1',
        fullName: 'Amara Okonkwo',
        email: 'amara@example.com',
        phoneNumber: '+2348011112222',
        branchId: 'branch_lagos',
        branchName: 'Lagos Branch',
        dateOfBirth: DateTime(1992, 4, 10),
        joinedDate: DateTime(2023, 1, 15),
        isActive: true,
        createdAt: DateTime(2023, 1, 15),
        updatedAt: DateTime.now(),
      ),
      MemberModel(
        id: 'm2',
        userId: 'u2',
        fullName: 'Chidi Nnamdi',
        email: 'chidi@example.com',
        phoneNumber: '+2348033334444',
        branchId: 'branch_lagos',
        branchName: 'Lagos Branch',
        dateOfBirth: DateTime(1988, 7, 20),
        joinedDate: DateTime(2022, 6, 1),
        isActive: false, // Suspended
        createdAt: DateTime(2022, 6, 1),
        updatedAt: DateTime.now(),
      ),
      MemberModel(
        id: 'm3',
        userId: 'u3',
        fullName: 'Emeka Obi',
        email: 'emeka@example.com',
        phoneNumber: '+2348055556666',
        branchId: 'branch_aba', // Different branch
        branchName: 'Aba Branch',
        dateOfBirth: DateTime(1995, 11, 5),
        joinedDate: DateTime(2024, 2, 1),
        isActive: true,
        createdAt: DateTime(2024, 2, 1),
        updatedAt: DateTime.now(),
      ),
    ];

    Widget createScreen({UserModel? user, List<MemberModel>? members}) {
      final activeUser = user ?? secretaryUser;
      final activeMembers = members ?? testMembers;

      return ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) {
            final notifier = AuthNotifier(_MockAuthService(activeUser));
            notifier.state = AsyncValue.data(activeUser);
            return notifier;
          }),
          memberManagementRepositoryProvider.overrideWith(
            (ref) => _MockMemberRepository(activeMembers),
          ),
        ],
        child: const MaterialApp(
          home: MembersManagementScreen(),
        ),
      );
    }

    testWidgets('renders branch scoped roster and initials avatars',
        (tester) async {
      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      // Branch header in app bar
      expect(find.text('Branch Members'), findsOneWidget);
      expect(find.text('Lagos Branch Roster'), findsOneWidget);

      // Scoped members in Lagos branch should appear
      expect(find.text('Amara Okonkwo'), findsOneWidget);
      expect(find.text('Chidi Nnamdi'), findsOneWidget);
      // Member from Aba branch should not appear for Lagos branch secretary
      expect(find.text('Emeka Obi'), findsNothing);

      // Initials on avatar
      expect(find.text('AO'), findsOneWidget);
      expect(find.text('CN'), findsOneWidget);

      // Contact details
      expect(find.text('+2348011112222'), findsOneWidget);
      expect(find.text('amara@example.com'), findsOneWidget);

      // Status pills
      expect(find.text('Active'), findsWidgets);
      expect(find.text('Suspended'), findsWidgets);
    });

    testWidgets('filters members by status tabs: All, Active, Suspended',
        (tester) async {
      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      // Initially All (2)
      expect(find.text('All (2)'), findsOneWidget);
      expect(find.text('Active (1)'), findsOneWidget);
      expect(find.text('Suspended (1)'), findsOneWidget);
      expect(find.text('Amara Okonkwo'), findsOneWidget);
      expect(find.text('Chidi Nnamdi'), findsOneWidget);

      // Tap Active chip
      await tester.tap(find.text('Active (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Amara Okonkwo'), findsOneWidget);
      expect(find.text('Chidi Nnamdi'), findsNothing);

      // Tap Suspended chip
      await tester.tap(find.text('Suspended (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Amara Okonkwo'), findsNothing);
      expect(find.text('Chidi Nnamdi'), findsOneWidget);
    });

    testWidgets('searches and filters members by name and contact',
        (tester) async {
      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      // Search 'Amara'
      await tester.enterText(find.byType(TextField), 'Amara');
      await tester.pumpAndSettle();

      expect(find.text('Amara Okonkwo'), findsOneWidget);
      expect(find.text('Chidi Nnamdi'), findsNothing);

      // Search by phone
      await tester.enterText(find.byType(TextField), '803333');
      await tester.pumpAndSettle();

      expect(find.text('Amara Okonkwo'), findsNothing);
      expect(find.text('Chidi Nnamdi'), findsOneWidget);
    });

    testWidgets('shows confirmation dialog before toggling member suspension',
        (tester) async {
      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      // Tap More options on Amara's card
      final moreButtons = find.byTooltip('More actions');
      expect(moreButtons, findsWidgets);

      await tester.tap(moreButtons.first);
      await tester.pumpAndSettle();

      // Popup menu should have View Profile and Suspend Member
      expect(find.text('View Profile'), findsOneWidget);
      expect(find.text('Suspend Member'), findsOneWidget);

      // Tap Suspend Member
      await tester.tap(find.text('Suspend Member'));
      await tester.pumpAndSettle();

      // Confirmation dialog should be displayed
      expect(find.text('Suspend Member?'), findsOneWidget);
      expect(
        find.textContaining('Are you sure you want to suspend Amara Okonkwo?'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Suspend'), findsOneWidget);

      // Tap Cancel closes dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Suspend Member?'), findsNothing);
    });
  });
}

