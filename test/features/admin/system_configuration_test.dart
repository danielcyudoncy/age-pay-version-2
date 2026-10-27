import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/features/admin/controllers/admin_provider.dart';
import 'package:cls/features/admin/models/system_settings_model.dart';
import 'package:cls/features/admin/repositories/system_settings_repository.dart';
import 'package:cls/features/admin/views/system_configuration_screen.dart';

class FakeSystemSettingsRepository implements SystemSettingsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream<SystemSettingsModel> streamSettings() => const Stream.empty();

  @override
  Future<SystemSettingsModel> getSettings() async => SystemSettingsModel.defaults();

  @override
  Future<bool> updateSettings(SystemSettingsModel settings, {required String updatedBy}) async => true;

  @override
  Future<void> toggleMaintenanceMode(bool enabled, {String? message, required String updatedBy}) async {}
}

void main() {
  final defaultSettings = SystemSettingsModel(
    paymentEnvironment: 'live',
    feeBearer: 'member',
    dualApprovalExpenseThreshold: 50000.0,
    requirePresidentApproval: true,
    maxUploadSizeBytes: 10485760,
    sessionTimeoutMinutes: 60,
    pushNotificationsEnabled: true,
    smsNotificationsEnabled: true,
    smsProvider: 'Termii',
    emailNotificationsEnabled: true,
    maintenanceMode: false,
    maintenanceMessage: 'System under maintenance.',
    updatedAt: DateTime(2025, 1, 1),
    updatedBy: 'admin@naat.org',
  );

  test('SystemSettingsModel copyWith and defaults work correctly', () {
    final model = SystemSettingsModel.defaults();
    expect(model.paymentEnvironment, 'live');
    expect(model.dualApprovalExpenseThreshold, 50000.0);
    expect(model.maintenanceMode, isFalse);

    final updated = model.copyWith(
      paymentEnvironment: 'test',
      maintenanceMode: true,
      dualApprovalExpenseThreshold: 100000.0,
    );
    expect(updated.paymentEnvironment, 'test');
    expect(updated.maintenanceMode, isTrue);
    expect(updated.dualApprovalExpenseThreshold, 100000.0);

    final map = updated.toFirestore();
    expect(map['paymentEnvironment'], 'test');
    expect(map['maintenanceMode'], isTrue);
    expect(map['dualApprovalExpenseThreshold'], 100000.0);
  });

  testWidgets('SystemConfigurationScreen renders grouped sections and options', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          systemSettingsRepositoryProvider.overrideWithValue(FakeSystemSettingsRepository()),
          systemSettingsStreamProvider.overrideWith(
            (ref) => Stream.value(defaultSettings),
          ),
        ],
        child: const MaterialApp(
          home: SystemConfigurationScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify app bar title
    expect(find.text('System Configuration'), findsOneWidget);

    // 2. Verify Section Headers
    expect(find.text('System Status & Maintenance'), findsOneWidget);
    expect(find.text('Payment Gateway & Financial Policies'), findsOneWidget);
    expect(find.text('Platform Policies & Security'), findsOneWidget);
    expect(find.text('Communication & Gateways'), findsOneWidget);
    expect(find.text('System Diagnostics & Information'), findsOneWidget);

    // 3. Verify Switches & Chips
    expect(find.text('Enable Maintenance Mode'), findsOneWidget);
    expect(find.text('Live Production'), findsOneWidget);
    expect(find.text('Test Sandbox'), findsOneWidget);
    expect(find.text('Require President Approval for New Members'), findsOneWidget);
    expect(find.text('Push Notifications (FCM)'), findsOneWidget);
    expect(find.text('SMS Broadcast Notifications'), findsOneWidget);

    // 4. Verify Save Configuration Button
    expect(find.text('Save Configuration'), findsOneWidget);
  });
}
