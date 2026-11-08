import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/features/admin/controllers/admin_provider.dart';
import 'package:cls/features/admin/models/organization_model.dart';
import 'package:cls/features/auth/views/organization_picker_screen.dart';

void main() {
  final now = DateTime.now();

  final org1 = OrganizationModel(
    id: 'org-1',
    name: 'Udoka Age Grade',
    slug: 'udoka-age-grade',
    isActive: true,
    openForJoin: true,
    createdAt: now,
    updatedAt: now,
  );

  final org2 = OrganizationModel(
    id: 'org-2',
    name: 'Akokwa Age Grade',
    slug: 'akokwa-age-grade',
    isActive: true,
    openForJoin: true,
    createdAt: now,
    updatedAt: now,
  );

  testWidgets(
    'organizationsFutureProvider updates reactively from empty cache to live server organizations',
    (tester) async {
      final controller = StreamController<List<OrganizationModel>>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            organizationsFutureProvider.overrideWith(
              (ref) => controller.stream,
            ),
          ],
          child: const MaterialApp(
            home: OrganizationPickerScreen(),
          ),
        ),
      );

      // Initially stream emits empty (e.g. fresh local cache after data deletion)
      controller.add([]);
      await tester.pump();

      expect(find.text('No organisations are available yet.'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);

      // Server returns the newly created organizations in real time
      controller.add([org1, org2]);
      await tester.pumpAndSettle();

      // Dropdown now appears reactively without needing manual app restart
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

      // Tap the dropdown to verify alphabetical order
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      expect(find.text('Akokwa Age Grade').hitTestable(), findsOneWidget);
      expect(find.text('Udoka Age Grade').hitTestable(), findsOneWidget);

      await controller.close();
    },
  );
}
