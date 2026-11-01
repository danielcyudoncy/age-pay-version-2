import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/auth/services/auth_service.dart';
import 'package:cls/features/admin/views/admin_profile_screen.dart';

class MockAuthServiceForProfile implements AuthService {
  UserModel _currentUser;

  MockAuthServiceForProfile(this._currentUser);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<UserModel?> getCurrentUser() async => _currentUser;

  @override
  Future<UserModel> updateUserProfile({
    required String uid,
    required String displayName,
    required String phoneNumber,
    String? ninOrBvn,
  }) async {
    _currentUser = _currentUser.copyWith(
      displayName: displayName,
      phoneNumber: phoneNumber,
      ninOrBvn: ninOrBvn,
    );
    return _currentUser;
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  late UserModel testAdmin;
  late MockAuthServiceForProfile mockAuthService;

  setUp(() {
    testAdmin = UserModel(
      uid: 'admin-uid-123',
      organizationId: 'org-master-1',
      email: 'superadmin@agepay.com',
      displayName: 'Chief Daniel Udoncy',
      phoneNumber: '08012345678',
      role: UserRole.superAdmin,
      ninOrBvn: '22233344455',
      createdAt: DateTime(2026, 1, 1),
    );
    mockAuthService = MockAuthServiceForProfile(testAdmin);
  });

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(mockAuthService),
      ],
      child: const MaterialApp(
        home: AdminProfileScreen(),
      ),
    );
  }

  group('Super Admin Profile Screen Tests', () {
    testWidgets('Renders Super Admin credentials, role tags, and personal details', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Super Admin Profile'), findsOneWidget);
      expect(find.text('Chief Daniel Udoncy'), findsWidgets);
      expect(find.text('superadmin@agepay.com'), findsWidgets);
      expect(find.text('SUPER ADMIN'), findsOneWidget);
      expect(find.text('Global Governance'), findsOneWidget);
      expect(find.text('Governance Privileges'), findsOneWidget);
      expect(find.text('Security & Authentication'), findsOneWidget);
    });

    testWidgets('Enters Edit Mode and updates Super Admin profile details', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap Edit IconButton in AppBar
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Edit Profile Information'), findsOneWidget);

      // Enter updated Name and Phone
      final nameField = find.widgetWithText(TextFormField, 'Full Name *');
      final phoneField = find.widgetWithText(TextFormField, 'Phone Number *');

      await tester.enterText(nameField, 'Dr. Daniel Udoncy (Executive)');
      await tester.enterText(phoneField, '08099887766');
      await tester.pumpAndSettle();

      // Tap Save Changes
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(find.text('Dr. Daniel Udoncy (Executive)'), findsWidgets);
      expect(find.text('08099887766'), findsOneWidget);
      expect(find.text('Super Admin profile updated successfully!'), findsOneWidget);
    });

    testWidgets('Validates 11-digit NIN/BVN when editing profile', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      final ninField = find.widgetWithText(TextFormField, 'NIN / BVN (11 Digits)');
      await tester.enterText(ninField, '12345'); // invalid length
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Should show validation error message
      expect(find.text('National Identity (NIN) or BVN must be exactly 11 digits.'), findsOneWidget);
    });

    testWidgets('Renders properly without overflow on narrow mobile screens (320px width)', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AdminProfileScreen), findsOneWidget);

      // Also enter edit mode on 320px screen
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Edit Profile Information'), findsOneWidget);
    });
  });
}
