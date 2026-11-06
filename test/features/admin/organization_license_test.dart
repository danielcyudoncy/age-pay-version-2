import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cls/features/admin/models/organization_model.dart';
import 'package:cls/features/admin/models/system_settings_model.dart';

void main() {
  group('OrganizationModel License & Subscription Tests', () {
    test('Default OrganizationModel has starter license active', () {
      final org = OrganizationModel(
        id: 'org_1',
        name: 'Test Age Grade',
        slug: 'test-age-grade',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(org.subscriptionTier, equals('starter'));
      expect(org.subscriptionStatus, equals('active'));
      expect(org.isLicenseActive, isTrue);
      expect(org.isLicenseExpired, isFalse);
      expect(org.isLicensePendingVerification, isFalse);
      expect(org.licenseDaysRemaining, equals(365));
    });

    test('Organization with future expiration date is active with days remaining', () {
      final futureDate = DateTime.now().add(const Duration(days: 120));
      final org = OrganizationModel(
        id: 'org_2',
        name: 'Active Pro Grade',
        slug: 'active-pro',
        subscriptionTier: 'pro',
        subscriptionStatus: 'active',
        subscriptionExpiresAt: futureDate,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(org.subscriptionTier, equals('pro'));
      expect(org.isLicenseActive, isTrue);
      expect(org.isLicenseExpired, isFalse);
      expect(org.isLicensePendingVerification, isFalse);
      expect(org.licenseDaysRemaining, inInclusiveRange(119, 120));
    });

    test('Organization with past expiration date is expired', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 5));
      final org = OrganizationModel(
        id: 'org_3',
        name: 'Expired Org',
        slug: 'expired-org',
        subscriptionTier: 'pro',
        subscriptionStatus: 'expired',
        subscriptionExpiresAt: pastDate,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(org.isLicenseActive, isFalse);
      expect(org.isLicenseExpired, isTrue);
      expect(org.licenseDaysRemaining, equals(0));
    });

    test('Organization with pending_verification status is marked pending', () {
      final org = OrganizationModel(
        id: 'org_4',
        name: 'Pending Renewal Org',
        slug: 'pending-org',
        subscriptionTier: 'pro',
        subscriptionStatus: 'pending_verification',
        licenseProofUrl: 'https://storage.googleapis.com/test.jpg',
        licensePaymentReference: 'ZEN-REF-9988',
        licensePaymentBank: 'First Bank',
        licensePaymentAmount: 35000.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(org.isLicensePendingVerification, isTrue);
      expect(org.isLicenseActive, isFalse);
      expect(org.licensePaymentReference, equals('ZEN-REF-9988'));
      expect(org.licensePaymentAmount, equals(35000.0));
      expect(org.licenseProofUrl, contains('test.jpg'));
    });

    test('toFirestore serializes license fields correctly', () {
      final expiresAt = DateTime(2027, 11, 3);
      final submittedAt = DateTime(2026, 11, 3, 10, 30);
      final org = OrganizationModel(
        id: 'org_5',
        name: 'Full Serialized Org',
        slug: 'full-serialized',
        subscriptionTier: 'pro',
        subscriptionStatus: 'pending_verification',
        subscriptionExpiresAt: expiresAt,
        licenseProofUrl: 'https://storage/proof.jpg',
        licensePaymentReference: 'REF123',
        licensePaymentBank: 'GTBank',
        licensePaymentAmount: 35000.0,
        licenseSubmittedAt: submittedAt,
        licenseVerifiedBy: 'admin@agepay.com',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final map = org.toFirestore();
      expect(map['subscriptionTier'], equals('pro'));
      expect(map['subscriptionStatus'], equals('pending_verification'));
      expect(map['subscriptionExpiresAt'], isA<Timestamp>());
      expect(map['licenseProofUrl'], equals('https://storage/proof.jpg'));
      expect(map['licensePaymentReference'], equals('REF123'));
      expect(map['licensePaymentBank'], equals('GTBank'));
      expect(map['licensePaymentAmount'], equals(35000.0));
      expect(map['licenseVerifiedBy'], equals('admin@agepay.com'));
    });
  });

  group('SystemSettingsModel Corporate Bank Tests', () {
    test('Default SystemSettingsModel includes AgePay corporate bank details', () {
      final settings = SystemSettingsModel.defaults();
      expect(settings.companyBankName, equals('Zenith Bank'));
      expect(settings.companyAccountName, equals('AgePay Technologies Ltd'));
      expect(settings.companyAccountNumber, equals('1012345678'));
      expect(settings.annualLicenseFee, equals(35000.0));
    });

    test('Custom SystemSettingsModel preserves company bank details in toFirestore', () {
      final custom = SystemSettingsModel(
        companyBankName: 'Access Bank',
        companyAccountName: 'AgePay West Africa',
        companyAccountNumber: '0987654321',
        annualLicenseFee: 40000.0,
        updatedAt: DateTime.now(),
      );

      final map = custom.toFirestore();
      expect(map['companyBankName'], equals('Access Bank'));
      expect(map['companyAccountName'], equals('AgePay West Africa'));
      expect(map['companyAccountNumber'], equals('0987654321'));
      expect(map['annualLicenseFee'], equals(40000.0));
    });
  });
}

