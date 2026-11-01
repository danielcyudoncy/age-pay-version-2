import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/features/members/views/treasurer_members_list_screen.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/dashboard/controllers/treasurer_dashboard_provider.dart';
import 'package:cls/features/obligations/controllers/obligation_provider.dart';
import 'package:cls/features/obligations/models/obligation_model.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/services/auth_service.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';

class _MockAuthService implements AuthService {
  final UserModel? user;
  _MockAuthService(this.user);

  @override
  Future<UserModel?> getCurrentUser() async => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testUser = UserModel(
    uid: 'u_treasurer',
    organizationId: 'org_1',
    email: 'treasurer@test.com',
    displayName: 'Treasurer John',
    phoneNumber: '08000000000',
    role: UserRole.financialSecretary,
    createdAt: DateTime(2025, 1, 1),
  );

  group('TreasurerMembersListScreen Widget Tests', () {
    final testMembers = [
      MemberModel(
        id: 'mem_1',
        userId: 'user_1',
        fullName: 'Chukwudi Emmanuel Nwosu',
        email: 'chukwudi@example.com',
        phoneNumber: '+2348011223344',
        branchName: 'Lagos Branch',
        dateOfBirth: DateTime(1990, 1, 1),
        joinedDate: DateTime(2024, 5, 12),
        createdAt: DateTime(2024, 5, 12),
        updatedAt: DateTime(2024, 5, 12),
      ),
      MemberModel(
        id: 'mem_2',
        userId: 'user_2',
        fullName: 'Amara Okonkwo',
        email: 'amara@example.com',
        phoneNumber: '+2348099887766',
        branchName: 'Abuja Branch',
        dateOfBirth: DateTime(1995, 3, 15),
        joinedDate: DateTime(2024, 1, 10),
        createdAt: DateTime(2024, 1, 10),
        updatedAt: DateTime(2024, 1, 10),
      ),
    ];

    testWidgets('renders structured ledger cards with name, contact, branch, and ledger affordance',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(_MockAuthService(testUser)),
            membersStreamProvider.overrideWith(
              (ref) => Stream.value(testMembers),
            ),
            memberActiveObligationsProvider('user_1').overrideWithValue(
              AsyncValue.data([
                ObligationModel(
                  id: 'ob_1',
                  memberId: 'user_1',
                  levyId: 'levy_1',
                  type: ObligationType.monthlyDue,
                  title: 'Annual Due',
                  description: 'Annual membership contribution',
                  amount: 25000,
                  paidAmount: 0,
                  outstandingBalance: 25000,
                  status: ObligationStatus.unpaid,
                  dueDate: DateTime(2026, 12, 31),
                  createdAt: DateTime(2026, 1, 1),
                ),
              ]),
            ),
            memberActiveObligationsProvider('user_2').overrideWithValue(
              const AsyncValue.data([]),
            ),
          ],
          child: const MaterialApp(
            home: TreasurerMembersListScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Header check
      expect(find.text('All Registered Members'), findsOneWidget);

      // Verify full names render cleanly
      expect(find.text('Chukwudi Emmanuel Nwosu'), findsOneWidget);
      expect(find.text('Amara Okonkwo'), findsOneWidget);

      // Verify contact & branch
      expect(find.text('+2348011223344'), findsOneWidget);
      expect(find.text('Lagos Branch'), findsOneWidget);
      expect(find.text('+2348099887766'), findsOneWidget);
      expect(find.text('Abuja Branch'), findsOneWidget);

      // Verify dues badges
      expect(find.text('Owes ₦25,000'), findsOneWidget);
      expect(find.text('Dues Cleared'), findsOneWidget);

      // Verify Ledger action label is present on each card
      expect(find.text('Ledger'), findsNWidgets(2));
    });

    testWidgets('search filters members by name, email, or phone', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(_MockAuthService(testUser)),
            membersStreamProvider.overrideWith(
              (ref) => Stream.value(testMembers),
            ),
            memberActiveObligationsProvider('user_1').overrideWithValue(
              const AsyncValue.data([]),
            ),
            memberActiveObligationsProvider('user_2').overrideWithValue(
              const AsyncValue.data([]),
            ),
          ],
          child: const MaterialApp(
            home: TreasurerMembersListScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Search by phone number
      await tester.enterText(find.byType(TextField), '998877');
      await tester.pump();

      expect(find.text('Amara Okonkwo'), findsOneWidget);
      expect(find.text('Chukwudi Emmanuel Nwosu'), findsNothing);

      // Clear search
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      expect(find.text('Chukwudi Emmanuel Nwosu'), findsOneWidget);
      expect(find.text('Amara Okonkwo'), findsOneWidget);
    });
  });
}
