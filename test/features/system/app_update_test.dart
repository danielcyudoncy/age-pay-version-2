import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/app_version.dart';
import 'package:cls/features/admin/models/system_settings_model.dart';
import 'package:cls/features/system/views/force_update_screen.dart';
import 'package:cls/features/system/widgets/app_update_dialog.dart';

void main() {
  group('SystemSettingsModel update logic', () {
    test('isUpdateAvailable returns true only when latestAppVersion is newer and valid URL exists', () {
      final settings = SystemSettingsModel.defaults().copyWith(
        latestAppVersion: '1.1.0',
        apkDownloadUrl: 'https://firebasestorage.googleapis.com/v0/b/agepay.appspot.com/o/releases%2Fapp.apk',
      );

      expect(settings.isUpdateAvailable('1.0.0'), isTrue);
      expect(settings.isUpdateAvailable('1.1.0'), isFalse);
      expect(settings.isUpdateAvailable('1.2.0'), isFalse);
    });

    test('isUpdateAvailable returns false when apkDownloadUrl is empty', () {
      final settings = SystemSettingsModel.defaults().copyWith(
        latestAppVersion: '1.1.0',
        apkDownloadUrl: '',
      );

      expect(settings.isUpdateAvailable('1.0.0'), isFalse);
    });

    test('isUpdateRequired checks forceUpdate flag or minimumRequiredVersion threshold', () {
      // 1. Soft update (forceUpdate = false, minVersion <= current)
      final softSettings = SystemSettingsModel.defaults().copyWith(
        latestAppVersion: '1.2.0',
        minimumRequiredVersion: '1.0.0',
        apkDownloadUrl: 'https://example.com/app.apk',
        forceUpdate: false,
      );
      expect(softSettings.isUpdateRequired('1.0.0'), isFalse);
      expect(softSettings.isUpdateAvailable('1.0.0'), isTrue);

      // 2. Mandatory update via forceUpdate = true
      final forcedSettings = softSettings.copyWith(forceUpdate: true);
      expect(forcedSettings.isUpdateRequired('1.0.0'), isTrue);

      // 3. Mandatory update via minimumRequiredVersion > current
      final minVersionForcedSettings = softSettings.copyWith(
        forceUpdate: false,
        minimumRequiredVersion: '1.1.0',
      );
      expect(minVersionForcedSettings.isUpdateRequired('1.0.0'), isTrue);
      expect(minVersionForcedSettings.isUpdateRequired('1.1.0'), isFalse);
    });
  });

  group('ForceUpdateScreen Widget Tests', () {
    testWidgets('renders mandatory update screen with versions and release notes', (tester) async {
      final settings = SystemSettingsModel.defaults().copyWith(
        latestAppVersion: '2.0.0',
        minimumRequiredVersion: '2.0.0',
        apkDownloadUrl: 'https://example.com/app.apk',
        releaseNotes: 'Security fixes and instant payment reconciliations.',
        forceUpdate: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ForceUpdateScreen(
            settings: settings,
            autoStartDownload: false,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify title & messages
      expect(find.text('Update Required'), findsOneWidget);
      expect(find.textContaining('A mandatory update is required'), findsOneWidget);
      expect(find.text('v${AppVersion.currentVersion}'), findsOneWidget);
      expect(find.text('v2.0.0'), findsOneWidget);
      expect(find.text("What's New in v2.0.0"), findsOneWidget);
      expect(find.text('Security fixes and instant payment reconciliations.'), findsOneWidget);

      // Verify action buttons
      expect(find.text('Update Now'), findsOneWidget);
      expect(find.text('Download via Web Browser'), findsOneWidget);
    });
  });

  group('AppUpdateDialog Widget Tests', () {
    testWidgets('renders soft update dialog with Later and Update Now actions', (tester) async {
      final settings = SystemSettingsModel.defaults().copyWith(
        latestAppVersion: '1.1.0',
        apkDownloadUrl: 'https://example.com/app.apk',
        releaseNotes: 'Performance enhancements.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AppUpdateDialog.show(context, settings),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog contents
      expect(find.text('Update Available'), findsOneWidget);
      expect(find.textContaining('A new version of AgePay (v1.1.0) is available'), findsOneWidget);
      expect(find.text("What's New:"), findsOneWidget);
      expect(find.text('Performance enhancements.'), findsOneWidget);

      // Verify actions
      expect(find.text('Later'), findsOneWidget);
      expect(find.text('Update Now'), findsOneWidget);

      // Tapping Later dismisses dialog
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.text('Update Available'), findsNothing);
    });
  });
}
