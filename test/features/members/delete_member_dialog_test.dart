import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/members/repositories/member_repository.dart';
import 'package:cls/features/dashboard/controllers/treasurer_dashboard_provider.dart';
import 'package:cls/features/members/widgets/delete_member_dialog.dart';

class _FakeMemberRepository implements MemberRepository {
  final int paymentCountToReturn;
  bool softDeleted = false;
  bool permanentlyPurged = false;

  _FakeMemberRepository({this.paymentCountToReturn = 0});

  @override
  Future<int> getMemberPaymentCount(String memberId, {String? userId}) async {
    return paymentCountToReturn;
  }

  @override
  Future<void> softDeleteMember(String id, {String? userId}) async {
    softDeleted = true;
  }

  @override
  Future<void> purgeMemberPermanently(String id, {String? userId}) async {
    permanentlyPurged = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final testMemberNoPayments = MemberModel(
    id: 'mem_clean',
    userId: 'user_clean',
    fullName: 'Emeka Okafor',
    email: 'emeka@example.com',
    phoneNumber: '+234 803 111 2222',
    branchName: 'Enugu Urban Branch',
    dateOfBirth: DateTime(1992, 1, 1),
    joinedDate: DateTime(2025, 1, 1),
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
  );

  final testMemberWithPayments = MemberModel(
    id: 'mem_with_ledger',
    userId: 'user_with_ledger',
    fullName: 'Ngozi Eze',
    email: 'ngozi@example.com',
    phoneNumber: '+234 802 333 4444',
    branchName: 'Onitsha Main Branch',
    dateOfBirth: DateTime(1990, 5, 20),
    joinedDate: DateTime(2024, 1, 1),
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
  );

  testWidgets('DeleteMemberDialog renders zero-payment state with permanent purge and deactivate options', (tester) async {
    final fakeRepo = _FakeMemberRepository(paymentCountToReturn: 0);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memberRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DeleteMemberDialog.show(
                  context,
                  member: testMemberNoPayments,
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

    // Verify dialog header & member details
    expect(find.text('Delete Member'), findsOneWidget);
    expect(find.text('SuperAdmin Governance Access'), findsOneWidget);
    expect(find.text('Emeka Okafor'), findsOneWidget);
    expect(find.text('Enugu Urban Branch'), findsOneWidget);

    // Verify zero financial transaction callout
    expect(find.text('No Financial Transactions Found'), findsOneWidget);
    expect(find.text('Permanently Delete'), findsOneWidget);
    expect(find.text('Deactivate Only'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Test permanent delete tap
    await tester.tap(find.text('Permanently Delete'));
    await tester.pumpAndSettle();

    expect(fakeRepo.permanentlyPurged, isTrue);
    expect(find.text('Delete Member'), findsNothing);
  });

  testWidgets('DeleteMemberDialog renders financial integrity protection when payments exist', (tester) async {
    final fakeRepo = _FakeMemberRepository(paymentCountToReturn: 3);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memberRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DeleteMemberDialog.show(
                  context,
                  member: testMemberWithPayments,
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

    // Verify financial history warning banner
    expect(find.text('Financial History Found (3 record(s))'), findsOneWidget);
    expect(find.text('Permanently Delete'), findsNothing); // Never allows permanent delete with payments!
    expect(find.text('Deactivate & Archive'), findsOneWidget);

    // Test Deactivate & Archive tap
    final deactivateButton = find.text('Deactivate & Archive');
    await tester.ensureVisible(deactivateButton);
    await tester.pumpAndSettle();
    await tester.tap(deactivateButton);
    await tester.pumpAndSettle();

    expect(fakeRepo.softDeleted, isTrue);
    expect(find.text('Delete Member'), findsNothing);
  });
}
