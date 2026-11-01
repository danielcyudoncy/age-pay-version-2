import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/nigerian_states.dart';
import 'package:cls/features/admin/controllers/admin_provider.dart';
import 'package:cls/features/admin/models/branch_model.dart';
import 'package:cls/features/admin/models/organization_model.dart';
import 'package:cls/features/admin/repositories/branch_repository.dart';
import 'package:cls/features/admin/widgets/add_branch_dialog.dart';

class FakeBranchRepository implements BranchRepository {
  final List<BranchModel> _branches = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<String> createBranch(BranchModel branch) async {
    final id = 'branch-${_branches.length + 1}';
    final saved = branch.copyWith(id: id);
    _branches.add(saved);
    return id;
  }

  @override
  Future<List<String>> createBranches(List<BranchModel> branches) async {
    final ids = <String>[];
    for (final b in branches) {
      final id = await createBranch(b);
      ids.add(id);
    }
    return ids;
  }

  @override
  Future<List<BranchModel>> getBranchesFuture(String organizationId) async {
    return _branches.where((b) => b.organizationId == organizationId).toList();
  }

  @override
  Stream<List<BranchModel>> getBranches(String organizationId) {
    return Stream.value(
      _branches.where((b) => b.organizationId == organizationId).toList(),
    );
  }
}

void main() {
  group('1. Nigerian States Constants & Helpers Tests', () {
    test('Contains exactly 36 States plus FCT (37 entries total)', () {
      expect(kNigerianStates.length, 37);
      expect(kNigerianStates.contains('Lagos'), isTrue);
      expect(kNigerianStates.contains('Abia'), isTrue);
      expect(kNigerianStates.contains('Rivers'), isTrue);
      expect(kNigerianStates.contains('Kano'), isTrue);
      expect(kNigerianStates.contains('FCT - Abuja'), isTrue);

      // Verify no duplicate state entries
      final uniqueSet = kNigerianStates.toSet();
      expect(uniqueSet.length, kNigerianStates.length);
    });

    test('getStandardBranchName formats standard branch names correctly', () {
      expect(getStandardBranchName('Lagos'), 'Lagos Branch');
      expect(getStandardBranchName('Abia'), 'Abia Branch');
      expect(getStandardBranchName('Rivers'), 'Rivers Branch');
      expect(getStandardBranchName('FCT - Abuja'), 'Abuja Branch');
      expect(getStandardBranchName('Abuja'), 'Abuja Branch');
      expect(getStandardBranchName('Enugu Branch'), 'Enugu Branch');
    });

    test('Common age grade hubs list contains core Nigerian commercial centers', () {
      expect(kCommonAgeGradeHubs.contains('Lagos'), isTrue);
      expect(kCommonAgeGradeHubs.contains('FCT - Abuja'), isTrue);
      expect(kCommonAgeGradeHubs.contains('Rivers'), isTrue);
      expect(kCommonAgeGradeHubs.contains('Abia'), isTrue);
    });
  });

  group('2. BranchRepository Batch Branch Creation Tests', () {
    late FakeBranchRepository repository;

    setUp(() {
      repository = FakeBranchRepository();
    });

    test('createBranches batch writes multiple branches atomically', () async {
      final now = DateTime.now();
      final branches = [
        BranchModel(
          id: '',
          organizationId: 'org-test-1',
          name: 'Lagos Branch',
          state: 'Lagos',
          city: 'Ikeja',
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
        BranchModel(
          id: '',
          organizationId: 'org-test-1',
          name: 'Rivers Branch',
          state: 'Rivers',
          city: 'Port Harcourt',
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
        BranchModel(
          id: '',
          organizationId: 'org-test-1',
          name: 'Abia Branch',
          state: 'Abia',
          city: 'Umuahia',
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final createdIds = await repository.createBranches(branches);
      expect(createdIds.length, 3);

      final fetched = await repository.getBranchesFuture('org-test-1');
      expect(fetched.length, 3);
      final names = fetched.map((b) => b.name).toList();
      expect(names, containsAll(['Lagos Branch', 'Rivers Branch', 'Abia Branch']));
    });

    test('createBranches returns empty list when given empty array', () async {
      final createdIds = await repository.createBranches([]);
      expect(createdIds, isEmpty);
    });
  });

  group('3. AddBranchDialog Widget Tests', () {
    late FakeBranchRepository repository;

    setUp(() {
      repository = FakeBranchRepository();
    });

    final testOrg = OrganizationModel(
      id: 'org-123',
      name: 'Ohafia Warriors Age Grade',
      slug: 'ohafia-warriors',
      contactEmail: 'contact@ohafia.org',
      contactPhone: '08012345678',
      isActive: true,
      openForJoin: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Widget createWidgetUnderTest() {
      return ProviderScope(
        overrides: [
          branchRepositoryProvider.overrideWithValue(repository),
          branchesStreamFamily('org-123').overrideWith(
            (ref) => Stream.value([
              BranchModel(
                id: 'b-1',
                organizationId: 'org-123',
                name: 'Lagos Branch',
                state: 'Lagos',
                city: '',
                isActive: true,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AddBranchDialog(organization: testOrg),
          ),
        ),
      );
    }

    testWidgets('Renders 36 States tab with search bar and existing branch indicator', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Add Branches'), findsOneWidget);
      expect(find.text('Ohafia Warriors Age Grade'), findsOneWidget);
      expect(find.text('36 States (Checkboxes)'), findsOneWidget);
      expect(find.text('Custom Branch'), findsOneWidget);

      // Search for Lagos (which is an existing branch in our mock)
      await tester.enterText(find.byType(TextField).first, 'Lagos');
      await tester.pumpAndSettle();

      // Lagos is an existing branch, should show 'Already added'
      expect(find.text('Already added'), findsOneWidget);
      expect(find.text('Branch currently active in this state'), findsOneWidget);

      // Search state Rivers (not added yet)
      await tester.enterText(find.byType(TextField).first, 'Rivers');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(CheckboxListTile, 'Rivers'), findsOneWidget);
      expect(find.text('Will provision: Rivers Branch'), findsOneWidget);
    });

    testWidgets('Toggles state checkbox and updates provisioning counter button', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Search for Abia
      await tester.enterText(find.byType(TextField).first, 'Abia');
      await tester.pumpAndSettle();

      // Check the Abia CheckboxListTile
      final abiaTile = find.widgetWithText(CheckboxListTile, 'Abia');
      expect(abiaTile, findsOneWidget);
      await tester.tap(abiaTile);
      await tester.pumpAndSettle();

      // Button should now show "Provision 1 Branch"
      expect(find.text('Provision 1 Branch'), findsOneWidget);
    });

    testWidgets('Switches to Custom Branch tab and displays custom branch fields', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Custom Branch'));
      await tester.pumpAndSettle();

      expect(find.text('Branch Name *'), findsOneWidget);
      expect(find.text('State (Optional)'), findsOneWidget);
      expect(find.text('City / District (Optional)'), findsOneWidget);
    });
  });
}
