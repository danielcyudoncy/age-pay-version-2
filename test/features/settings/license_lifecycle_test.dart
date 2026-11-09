import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/features/admin/models/organization_model.dart';
import 'package:cls/features/settings/widgets/license_status_banner.dart';
import 'package:cls/features/settings/widgets/read_only_license_dialog.dart';

void main() {
  group('OrganizationModel - Software License Lifecycle & 60-Day Trial', () {
    test('Constants match business specifications', () {
      expect(OrganizationModel.trialDurationDays, 60);
      expect(OrganizationModel.gracePeriodDays, 14);
    });

    test('60-Day Trial Organization has correct active properties', () {
      final now = DateTime.now();
      final org = OrganizationModel(
        id: 'test-org-1',
        name: 'Igbo Community Association',
        slug: 'test-org',
        contactEmail: 'contact@igbo.org',
        contactPhone: '08012345678',
        address: '123 Lagos Way',
        createdAt: now,
        updatedAt: now,
        subscriptionTier: 'trial',
        subscriptionStatus: 'active',
        subscriptionExpiresAt: now.add(const Duration(days: 60)),
        isTrial: true,
      );

      expect(org.isTrial, isTrue);
      expect(org.isLicenseActive, isTrue);
      expect(org.isLicenseExpired, isFalse);
      expect(org.isInGracePeriod, isFalse);
      expect(org.isLicenseHardExpired, isFalse);
      expect(org.isReadOnly, isFalse);
      expect(org.licenseDaysRemaining, closeTo(60, 1));
      expect(org.isRenewalDueSoon, isFalse);
    });

    test('Trial organization within 30 days of expiry triggers isRenewalDueSoon', () {
      final now = DateTime.now();
      final org = OrganizationModel(
        id: 'test-org-2',
        name: 'Yoruba Progressive Union',
        slug: 'test-org',
        contactEmail: 'contact@ypu.org',
        contactPhone: '08012345678',
        address: '456 Ibadan Road',
        createdAt: now.subtract(const Duration(days: 45)),
        updatedAt: now,
        subscriptionTier: 'trial',
        subscriptionStatus: 'active',
        subscriptionExpiresAt: now.add(const Duration(days: 15)),
        isTrial: true,
      );

      expect(org.isTrial, isTrue);
      expect(org.isLicenseActive, isTrue);
      expect(org.isLicenseExpired, isFalse);
      expect(org.isRenewalDueSoon, isTrue);
      expect(org.licenseDaysRemaining, 15);
      expect(org.isInGracePeriod, isFalse);
      expect(org.isReadOnly, isFalse);
    });

    test('14-Day Grace Period applies immediately post-expiry without blocking access', () {
      final now = DateTime.now();
      final org = OrganizationModel(
        id: 'test-org-3',
        name: 'Hausa Cultural League',
        slug: 'test-org',
        contactEmail: 'contact@hcl.org',
        contactPhone: '08012345678',
        address: '789 Kano Street',
        createdAt: now.subtract(const Duration(days: 65)),
        updatedAt: now,
        subscriptionTier: 'trial',
        subscriptionStatus: 'active',
        subscriptionExpiresAt: now.subtract(const Duration(days: 5)),
        isTrial: true,
      );

      expect(org.isLicenseExpired, isTrue);
      expect(org.isInGracePeriod, isTrue);
      expect(org.gracePeriodDaysRemaining, 9);
      expect(org.isLicenseHardExpired, isFalse);
      expect(org.isReadOnly, isFalse);
      expect(org.isLicenseActive, isFalse);
    });

    test('Read-Only Mode activates once the 14-day grace period lapses', () {
      final now = DateTime.now();
      final org = OrganizationModel(
        id: 'test-org-4',
        name: 'Niger Delta Forum',
        slug: 'test-org',
        contactEmail: 'contact@ndf.org',
        contactPhone: '08012345678',
        address: '10 Port Harcourt Crescent',
        createdAt: now.subtract(const Duration(days: 80)),
        updatedAt: now,
        subscriptionTier: 'trial',
        subscriptionStatus: 'active',
        subscriptionExpiresAt: now.subtract(const Duration(days: 15)),
        isTrial: true,
      );

      expect(org.isLicenseExpired, isTrue);
      expect(org.isInGracePeriod, isFalse);
      expect(org.gracePeriodDaysRemaining, 0);
      expect(org.isLicenseHardExpired, isTrue);
      expect(org.isReadOnly, isTrue);
    });

    test('Pending verification unblocks read-only mode during SuperAdmin review', () {
      final now = DateTime.now();
      final org = OrganizationModel(
        id: 'test-org-5',
        name: 'Benue Development Forum',
        slug: 'test-org',
        contactEmail: 'contact@bdf.org',
        contactPhone: '08012345678',
        address: '22 Makurdi Avenue',
        createdAt: now.subtract(const Duration(days: 90)),
        updatedAt: now,
        subscriptionTier: 'trial',
        subscriptionStatus: 'pending_verification',
        subscriptionExpiresAt: now.subtract(const Duration(days: 20)),
        isTrial: true,
      );

      expect(org.isLicensePendingVerification, isTrue);
      expect(org.isReadOnly, isFalse);
      expect(org.isLicenseHardExpired, isTrue);
    });

    test('Active standard annual subscription with over 30 days left', () {
      final now = DateTime.now();
      final org = OrganizationModel(
        id: 'test-org-6',
        name: 'Enugu City Club',
        slug: 'test-org',
        contactEmail: 'contact@enugu.org',
        contactPhone: '08012345678',
        address: '50 Ogui Road',
        createdAt: now.subtract(const Duration(days: 100)),
        updatedAt: now,
        subscriptionTier: 'standard',
        subscriptionStatus: 'active',
        subscriptionExpiresAt: now.add(const Duration(days: 200)),
        isTrial: false,
      );

      expect(org.isTrial, isFalse);
      expect(org.isLicenseActive, isTrue);
      expect(org.isLicenseExpired, isFalse);
      expect(org.isRenewalDueSoon, isFalse);
      expect(org.isInGracePeriod, isFalse);
      expect(org.isReadOnly, isFalse);
    });
  });

  group('LicenseStatusBanner Widget Tests', () {
    testWidgets('Renders 60-Day Welcome Trial banner for executives', (tester) async {
      final now = DateTime.now();
      final org = OrganizationModel(
        id: 'org-w1',
        name: 'Test Org',
        slug: 'test-org',
        contactEmail: 'test@org.com',
        contactPhone: '08000000000',
        address: 'Address',
        createdAt: now,
        updatedAt: now,
        subscriptionTier: 'trial',
        subscriptionStatus: 'active',
        subscriptionExpiresAt: now.add(const Duration(days: 55)),
        isTrial: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LicenseStatusBanner(org: org, isExecutive: true),
          ),
        ),
      );

      expect(find.text('60-Day Welcome Trial Active'), findsOneWidget);
      expect(find.textContaining('55 days remaining'), findsOneWidget);
    });

    testWidgets('Renders Trial Ending Soon banner when remaining days <= 30', (tester) async {
      final now = DateTime.now();
      final org = OrganizationModel(
        id: 'org-w2',
        name: 'Test Org',
        slug: 'test-org',
        contactEmail: 'test@org.com',
        contactPhone: '08000000000',
        address: 'Address',
        createdAt: now.subtract(const Duration(days: 40)),
        updatedAt: now,
        subscriptionTier: 'trial',
        subscriptionStatus: 'active',
        subscriptionExpiresAt: now.add(const Duration(days: 20)),
        isTrial: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LicenseStatusBanner(org: org, isExecutive: true),
          ),
        ),
      );

      expect(find.text('60-Day Trial Ending Soon'), findsOneWidget);
      expect(find.textContaining('20 day(s) remaining'), findsOneWidget);
    });

    testWidgets('Renders 14-Day Grace Period banner for executive, hides for member', (tester) async {
      final now = DateTime.now();
      final org = OrganizationModel(
        id: 'org-w3',
        name: 'Test Org',
        slug: 'test-org',
        contactEmail: 'test@org.com',
        contactPhone: '08000000000',
        address: 'Address',
        createdAt: now.subtract(const Duration(days: 62)),
        updatedAt: now,
        subscriptionTier: 'trial',
        subscriptionStatus: 'active',
        subscriptionExpiresAt: now.subtract(const Duration(days: 2)),
        isTrial: true,
      );

      // Executive view
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LicenseStatusBanner(org: org, isExecutive: true),
          ),
        ),
      );
      expect(find.text('Software License Expired — 14-Day Grace Period'), findsOneWidget);
      expect(find.textContaining('12 day(s) remaining in your grace period'), findsOneWidget);

      // Member view - grace period alert is suppressed
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LicenseStatusBanner(org: org, isExecutive: false),
          ),
        ),
      );
      expect(find.text('Software License Expired — 14-Day Grace Period'), findsNothing);
    });

    testWidgets('Renders Read-Only banner for both executives and regular members', (tester) async {
      final now = DateTime.now();
      final org = OrganizationModel(
        id: 'org-w4',
        name: 'Test Org',
        slug: 'test-org',
        contactEmail: 'test@org.com',
        contactPhone: '08000000000',
        address: 'Address',
        createdAt: now.subtract(const Duration(days: 80)),
        updatedAt: now,
        subscriptionTier: 'trial',
        subscriptionStatus: 'active',
        subscriptionExpiresAt: now.subtract(const Duration(days: 16)),
        isTrial: true,
      );

      // Executive view
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LicenseStatusBanner(org: org, isExecutive: true),
          ),
        ),
      );
      expect(find.text('Annual License Expired — Read-Only Mode'), findsOneWidget);
      expect(find.text('Renew License'), findsOneWidget);

      // Member view
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LicenseStatusBanner(org: org, isExecutive: false),
          ),
        ),
      );
      expect(find.text('Organisation in Read-Only Mode'), findsOneWidget);
      expect(find.text('License Status'), findsOneWidget);
    });

    testWidgets('Renders Pending Verification banner', (tester) async {
      final now = DateTime.now();
      final org = OrganizationModel(
        id: 'org-w5',
        name: 'Test Org',
        slug: 'test-org',
        contactEmail: 'test@org.com',
        contactPhone: '08000000000',
        address: 'Address',
        createdAt: now.subtract(const Duration(days: 80)),
        updatedAt: now,
        subscriptionTier: 'trial',
        subscriptionStatus: 'pending_verification',
        subscriptionExpiresAt: now.subtract(const Duration(days: 16)),
        isTrial: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LicenseStatusBanner(org: org, isExecutive: true),
          ),
        ),
      );

      expect(find.text('Renewal Proof Under Verification'), findsOneWidget);
      expect(find.text('View Status'), findsOneWidget);
    });
  });

  group('ReadOnlyLicenseDialog Tests', () {
    testWidgets('Shows dialog and handles dismiss action', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    ReadOnlyLicenseDialog.show(
                      context,
                      actionName: 'creating a new levy',
                    );
                  },
                  child: const Text('Trigger Action'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Action'));
      await tester.pumpAndSettle();

      expect(find.text('Read-Only Mode Active'), findsOneWidget);
      expect(find.textContaining('creating a new levy'), findsOneWidget);
      expect(find.text('Renew License'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Read-Only Mode Active'), findsNothing);
    });
  });
}
