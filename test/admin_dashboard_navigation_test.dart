import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/auth/services/auth_service.dart';
import 'package:cls/features/admin/controllers/admin_provider.dart';
import 'package:cls/features/admin/models/admin_dashboard_data.dart';
import 'package:cls/features/admin/models/organization_model.dart';
import 'package:cls/features/admin/views/admin_dashboard.dart';
import 'package:cls/features/national/controllers/national_provider.dart';
import 'package:cls/features/dashboard/controllers/member_dashboard_provider.dart';
import 'package:cls/features/obligations/controllers/obligation_provider.dart';
import 'package:cls/features/secretary/controllers/secretary_dashboard_provider.dart';

class MockAuthServiceForAdminDashboard implements AuthService {
  final UserModel _currentUser;

  MockAuthServiceForAdminDashboard(this._currentUser);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<UserModel?> getCurrentUser() async => _currentUser;

  @override
  Future<void> signOut() async {}

  @override
  Future<String> getActiveOrganizationId() async => _currentUser.organizationId;
}

void main() {
  late UserModel testSuperAdmin;
  late MockAuthServiceForAdminDashboard mockAuthService;

  setUp(() {
    testSuperAdmin = UserModel(
      uid: 'admin-123',
      organizationId: 'org-1',
      email: 'admin@agepay.com',
      displayName: 'Super Admin Daniel',
      phoneNumber: '08011223344',
      role: UserRole.superAdmin,
      branchId: 'branch-abuja',
      branchName: 'Abuja Branch',
      nationalRole: UserRole.president,
      isEnrolledInNational: true,
      createdAt: DateTime(2026, 1, 1),
    );
    mockAuthService = MockAuthServiceForAdminDashboard(testSuperAdmin);
  });

  Widget buildDashboardTestWidget() {
    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(mockAuthService),
        authProvider.overrideWith(
          (ref) => AuthNotifier(mockAuthService)..setUser(testSuperAdmin),
        ),
        organizationIdProvider.overrideWith((ref) => Future.value('org-1')),
        currentOrganizationProvider.overrideWith(
          (ref) => Stream.value(
            OrganizationModel(
              id: 'org-1',
              name: 'AgePay Master Org',
              slug: 'agepay-master',
              createdAt: DateTime(2026, 1, 1),
              updatedAt: DateTime(2026, 1, 1),
            ),
          ),
        ),
        adminDashboardProvider.overrideWith(
          (ref) => const AsyncValue.data(
            AdminDashboardData(
              totalOrganizations: 3,
              totalUsers: 45,
              activeOrganizations: 2,
              pendingApprovals: 1,
              recentOrganizations: [],
            ),
          ),
        ),
        // Member dashboard mock providers
        memberTotalPaidProvider('admin-123').overrideWithValue(const AsyncValue.data(50000.0)),
        memberTotalOutstandingProvider('admin-123').overrideWithValue(const AsyncValue.data(0.0)),
        memberActiveLeviesProvider('admin-123').overrideWithValue(const AsyncValue.data(0)),
        memberRecentPaymentsProvider('admin-123').overrideWithValue(const AsyncValue.data([])),
        memberRegistrationFeeStatusProvider('admin-123').overrideWithValue(const AsyncValue.data(true)),
        memberActiveObligationsProvider('admin-123').overrideWithValue(const AsyncValue.data([])),
        memberObligationReconciliationProvider('admin-123').overrideWith((ref) => Future.value(0)),
        announcementsStreamProvider('org-1').overrideWith((ref) => Stream.value([])),
        // National hub mock providers
        nationalContributionsProvider('org-1').overrideWith((ref) => Stream.value([])),
        nationalMembersProvider('org-1').overrideWith((ref) => Stream.value([])),
        branchComplianceLeaderboardProvider('org-1').overrideWith((ref) => Stream.value([])),
      ],
      child: const MaterialApp(
        home: AdminDashboard(),
      ),
    );
  }

  testWidgets('AdminDashboard renders BottomNavigationBar with 3 tabs and Affiliations card', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildDashboardTestWidget());
    await tester.pumpAndSettle();

    // Verify Welcome text and Bottom Navigation Bar tabs
    expect(find.text('Welcome, Super Admin Daniel'), findsOneWidget);
    expect(find.descendant(of: find.byType(BottomNavigationBar), matching: find.text('Admin Console')), findsOneWidget);
    expect(find.descendant(of: find.byType(BottomNavigationBar), matching: find.text('Branch Member')), findsOneWidget);
    expect(find.descendant(of: find.byType(BottomNavigationBar), matching: find.text('National Branch')), findsOneWidget);

    // Verify Member Affiliations card
    expect(find.text('Member Affiliations'), findsOneWidget);
    expect(find.text('Abuja Branch'), findsOneWidget);
    expect(find.text('National Executive (President)'), findsOneWidget);
    expect(find.text('Member View'), findsOneWidget);
    expect(find.text('National Hub'), findsOneWidget);
  });

  testWidgets('Tapping Branch Member tab switches to MemberDashboard and back', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildDashboardTestWidget());
    await tester.pumpAndSettle();

    // Tap on the BottomNavigationBar "Branch Member" tab
    await tester.tap(find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text('Branch Member'),
    ));
    await tester.pumpAndSettle();

    // BottomNavigationBar should still be visible
    expect(find.descendant(of: find.byType(BottomNavigationBar), matching: find.text('Branch Member')), findsOneWidget);
    expect(find.descendant(of: find.byType(BottomNavigationBar), matching: find.text('Admin Console')), findsOneWidget);

    // Switch back to Admin Console
    await tester.tap(find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text('Admin Console'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Member Affiliations'), findsOneWidget);
    expect(find.text('Welcome, Super Admin Daniel'), findsOneWidget);
  });

  testWidgets('Tapping Member View button on Affiliations card switches to MemberDashboard', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildDashboardTestWidget());
    await tester.pumpAndSettle();

    // Tap on the "Member View" button inside the affiliations card
    await tester.tap(find.widgetWithText(OutlinedButton, 'Member View'));
    await tester.pumpAndSettle();

    // Verify BottomNavigationBar remains accessible
    expect(find.descendant(of: find.byType(BottomNavigationBar), matching: find.text('Admin Console')), findsOneWidget);

    // Tap "Admin Console" to return
    await tester.tap(find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text('Admin Console'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Member Affiliations'), findsOneWidget);
  });

  testWidgets('Tapping National Branch tab switches to NationalHubScreen and back', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildDashboardTestWidget());
    await tester.pumpAndSettle();

    // Tap on the BottomNavigationBar "National Branch" tab
    await tester.tap(find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text('National Branch'),
    ));
    await tester.pumpAndSettle();

    // National Hub tabs should be present
    expect(find.text('Contributions'), findsOneWidget);
    expect(find.text('Assembly Roll'), findsOneWidget);

    // Tap "Admin Console" to return
    await tester.tap(find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text('Admin Console'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Member Affiliations'), findsOneWidget);
  });
}
