import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/admin/controllers/admin_provider.dart';
import 'package:cls/features/admin/services/system_reset_service.dart';
import 'package:cls/features/admin/widgets/system_reset_dialog.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';

class FakeSystemResetService implements SystemResetService {
  bool didCallReset = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> resetAllTestData({
    required String currentUserId,
    void Function(String status, double progress)? onProgress,
  }) async {
    didCallReset = true;
    onProgress?.call('Done', 1.0);
  }
}

void main() {
  testWidgets('SystemResetDialog requires RESET confirmation to enable button', (tester) async {
    final fakeService = FakeSystemResetService();
    final testUser = UserModel(
      uid: 'super-admin-uid',
      organizationId: 'org-1',
      email: 'danielcyudoncy@gmail.com',
      displayName: 'Super Admin',
      phoneNumber: '08012345678',
      role: UserRole.superAdmin,
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          systemResetServiceProvider.overrideWithValue(fakeService),
          authProvider.overrideWith((ref) => _SimpleAuthNotifier(testUser)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SystemResetDialog(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify title and prompt
    expect(find.text('Reset System Data'), findsOneWidget);
    expect(find.text('Type RESET below to confirm:'), findsOneWidget);

    // Confirm button should initially be disabled
    final resetButtonFinder = find.widgetWithText(FilledButton, 'Reset All Data');
    expect(resetButtonFinder, findsOneWidget);
    FilledButton button = tester.widget<FilledButton>(resetButtonFinder);
    expect(button.onPressed, isNull);

    // Enter wrong text
    await tester.enterText(find.byType(TextField), 'WRONG');
    await tester.pump();
    button = tester.widget<FilledButton>(resetButtonFinder);
    expect(button.onPressed, isNull);

    // Enter 'RESET'
    await tester.enterText(find.byType(TextField), 'RESET');
    await tester.pump();
    button = tester.widget<FilledButton>(resetButtonFinder);
    expect(button.onPressed, isNotNull);

    // Tap button to execute reset
    await tester.tap(resetButtonFinder);
    await tester.pump();

    expect(fakeService.didCallReset, isTrue);
  });
}

class _SimpleAuthNotifier extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  _SimpleAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

