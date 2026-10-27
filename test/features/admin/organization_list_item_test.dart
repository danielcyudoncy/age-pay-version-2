import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/features/admin/controllers/admin_provider.dart';
import 'package:cls/features/admin/models/branch_model.dart';
import 'package:cls/features/admin/models/organization_model.dart';
import 'package:cls/features/admin/widgets/organization_list_item.dart';

void main() {
  final testOrg = OrganizationModel(
    id: 'org-1',
    name: 'National Association of Academic Technologists',
    slug: 'naat-national',
    contactEmail: 'contact@naat.org',
    contactPhone: '+234 800 123 4567',
    address: 'Abuja, Nigeria',
    isActive: true,
    openForJoin: true,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
  );

  final testBranch = BranchModel(
    id: 'b-1',
    organizationId: 'org-1',
    name: 'Abuja Central Branch',
    city: 'Abuja',
    state: 'FCT',
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
  );

  testWidgets('OrganizationListItem renders 2-tier layout, badges, metadata, and popup menu actions', (tester) async {
    bool toggledStatus = false;
    bool toggledJoin = false;
    bool edited = false;
    bool addedBranch = false;
    bool deleted = false;
    BranchModel? tappedBranch;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          branchesStreamFamily('org-1').overrideWith(
            (ref) => Stream.value([testBranch]),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: OrganizationListItem(
                organization: testOrg,
                onToggleStatus: () => toggledStatus = true,
                onToggleJoin: () => toggledJoin = true,
                onEdit: () => edited = true,
                onAddBranch: () => addedBranch = true,
                onDelete: () => deleted = true,
                onBranchTap: (b) => tappedBranch = b,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify organization name is visible and fully rendered
    expect(find.text('National Association of Academic Technologists'), findsOneWidget);

    // 2. Verify status pills & slug tag are displayed
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Join Open'), findsOneWidget);
    expect(find.text('@naat-national'), findsOneWidget);

    // 3. Verify metadata row (Tier 2) is displayed
    expect(find.text('contact@naat.org'), findsOneWidget);
    expect(find.text('+234 800 123 4567'), findsOneWidget);
    expect(find.text('Abuja, Nigeria'), findsOneWidget);

    // 4. Verify branch info is displayed
    expect(find.text('Branches'), findsOneWidget);
    expect(find.text('Abuja Central Branch'), findsOneWidget);
    expect(find.text('(Abuja)'), findsOneWidget);

    // 5. Test Branch Tap
    await tester.tap(find.text('Abuja Central Branch'));
    await tester.pumpAndSettle();
    expect(tappedBranch?.id, 'b-1');

    // 6. Test Add Branch Tap
    await tester.tap(find.text('Add Branch'));
    await tester.pumpAndSettle();
    expect(addedBranch, isTrue);

    // 7. Test Popup Menu Button & Options
    final moreButton = find.byType(PopupMenuButton<String>);
    expect(moreButton, findsOneWidget);

    // Open popup menu
    await tester.tap(moreButton);
    await tester.pumpAndSettle();

    expect(find.text('Edit details'), findsOneWidget);
    expect(find.text('Close Join'), findsOneWidget);
    expect(find.text('Deactivate'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    // Tap "Edit details"
    await tester.tap(find.text('Edit details'));
    await tester.pumpAndSettle();
    expect(edited, isTrue);

    // Open popup menu again to test "Close Join"
    await tester.tap(moreButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close Join'));
    await tester.pumpAndSettle();
    expect(toggledJoin, isTrue);

    // Open popup menu again to test "Deactivate"
    await tester.tap(moreButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deactivate'));
    await tester.pumpAndSettle();
    expect(toggledStatus, isTrue);

    // Open popup menu again to test "Delete"
    await tester.tap(moreButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
  });

  testWidgets('OrganizationListItem displays Inactive and Join Closed states properly', (tester) async {
    final inactiveOrg = testOrg.copyWith(
      isActive: false,
      openForJoin: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          branchesStreamFamily('org-1').overrideWith(
            (ref) => Stream.value([]),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: OrganizationListItem(
                organization: inactiveOrg,
                onToggleStatus: () {},
                onToggleJoin: () {},
                onEdit: () {},
                onAddBranch: () {},
                onDelete: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify pills
    expect(find.text('Inactive'), findsOneWidget);
    expect(find.text('Join Closed'), findsOneWidget);

    // Verify empty branches state
    expect(
      find.text('No branches registered yet under this organization.'),
      findsOneWidget,
    );

    // Open popup menu
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('Activate'), findsOneWidget);
    expect(find.text('Open Join'), findsOneWidget);
  });
}
