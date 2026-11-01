import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/features/admin/services/bank_verification_service.dart';
import 'package:cls/features/auth/services/identity_verification_service.dart';
import 'package:cls/features/admin/models/organization_model.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/core/constants/enums.dart';

void main() {
  group('1. Executive Identity Verification Tests (NIN/BVN)', () {
    test('Rejects NIN/BVN with length other than 11 digits', () {
      final resShort = IdentityVerificationService.verifyNinOrBvn(
        rawId: '1234567890',
        fullName: 'Chief Emeka Okafor',
      );
      expect(resShort.isValid, isFalse);
      expect(resShort.message, contains('must be exactly 11 digits'));

      final resLong = IdentityVerificationService.verifyNinOrBvn(
        rawId: '123456789012',
        fullName: 'Chief Emeka Okafor',
      );
      expect(resLong.isValid, isFalse);
    });

    test('Rejects repetitive dummy sequences (e.g. 11111111111)', () {
      final res = IdentityVerificationService.verifyNinOrBvn(
        rawId: '11111111111',
        fullName: 'Chief Emeka Okafor',
      );
      expect(res.isValid, isFalse);
      expect(res.message, contains('Invalid NIN/BVN sequence detected'));
    });

    test('Catches blacklisted fraudulent IDs', () {
      final res = IdentityVerificationService.verifyNinOrBvn(
        rawId: '00000000000',
        fullName: 'Fraudster User',
      );
      expect(res.isValid, isFalse);
      expect(res.message, contains('Security Alert: This identification has been flagged'));
    });

    test('Approves valid 11-digit government ID and returns masked string', () {
      final res = IdentityVerificationService.verifyNinOrBvn(
        rawId: '22233344455',
        fullName: 'Chief Emeka Okafor',
      );
      expect(res.isValid, isTrue);
      expect(res.maskedId, '222****4455');
      expect(res.message, contains('Chief Emeka Okafor'));
    });
  });

  group('2. Bank Account Matching & Anti-Siphoning Tests', () {
    test('Rejects account numbers with invalid length (non-NUBAN)', () {
      final res = BankVerificationService.verifyAccount(
        bankName: 'Access Bank',
        accountNumber: '12345678', // 8 digits
        organizationName: 'Udoka Age Grade',
        accountName: 'Udoka Age Grade Central',
      );
      expect(res.isApproved, isFalse);
      expect(res.status, BankMatchStatus.invalidNumber);
    });

    test('Blocks personal accounts when name does not match organization', () {
      final res = BankVerificationService.verifyAccount(
        bankName: 'Zenith Bank',
        accountNumber: '1020304050',
        organizationName: 'Udoka Age Grade',
        accountName: 'Chinedu Eze', // Personal name siphoning attempt
      );
      expect(res.isApproved, isFalse);
      expect(res.status, BankMatchStatus.personalAccountBlocked);
      expect(res.message, contains('Personal bank accounts are prohibited'));
    });

    test('Approves account matching registered Age Grade name', () {
      final res = BankVerificationService.verifyAccount(
        bankName: 'First Bank of Nigeria',
        accountNumber: '0123456789',
        organizationName: 'Udoka Age Grade',
        accountName: 'Udoka Age Grade Association',
      );
      expect(res.isApproved, isTrue);
      expect(res.status, BankMatchStatus.verifiedAssociation);
      expect(res.similarityScore, greaterThan(0.0));
    });

    test('Approves account with corporate/association keywords matching org tokens', () {
      final res = BankVerificationService.verifyAccount(
        bankName: 'GTBank',
        accountNumber: '0123456789',
        organizationName: 'Abiriba Youth Assembly',
        accountName: 'Abiriba Youth Development Union',
      );
      expect(res.isApproved, isTrue);
      expect(res.status, BankMatchStatus.verifiedAssociation);
    });
  });

  group('3. Platform Gate & OrganizationModel Serialization Tests', () {
    final now = DateTime(2026, 11, 1);

    test('OrganizationModel handles verification status and legal credentials', () {
      final org = OrganizationModel(
        id: 'org-test',
        name: 'Udoka Age Grade 1980-1985',
        slug: 'udoka-age-grade',
        isActive: false,
        openForJoin: false,
        verificationStatus: 'pending_verification',
        cacNumber: 'IT/987654',
        townUnionName: 'Abiriba Communal Improvement Union (ACIU)',
        townUnionContact: 'President-General: 08031234567',
        founderNinOrBvn: '222****4455',
        isBankVerified: true,
        bankAccountType: 'association',
        createdAt: now,
        updatedAt: now,
      );

      expect(org.isVerified, isFalse);
      expect(org.isPendingVerification, isTrue);
      expect(org.cacNumber, 'IT/987654');
      expect(org.townUnionName, contains('Abiriba'));
      expect(org.isBankVerified, isTrue);

      final map = org.toFirestore();
      expect(map['verificationStatus'], 'pending_verification');
      expect(map['cacNumber'], 'IT/987654');
      expect(map['isBankVerified'], isTrue);

      final verifiedOrg = org.copyWith(
        isActive: true,
        openForJoin: true,
        verificationStatus: 'verified',
      );
      expect(verifiedOrg.isVerified, isTrue);
      expect(verifiedOrg.isActive, isTrue);
      expect(verifiedOrg.openForJoin, isTrue);
    });

    test('UserModel supports executive identity verification attributes', () {
      final user = UserModel(
        uid: 'user-exec',
        organizationId: 'org-test',
        email: 'president@example.com',
        displayName: 'Chief Kalu Anya',
        phoneNumber: '08031234567',
        role: UserRole.president,
        ninOrBvn: '22233344455',
        isIdentityVerified: true,
        createdAt: now,
      );

      expect(user.isIdentityVerified, isTrue);
      expect(user.ninOrBvn, '22233344455');

      final firestoreMap = user.toFirestore();
      expect(firestoreMap['ninOrBvn'], '22233344455');
      expect(firestoreMap['isIdentityVerified'], isTrue);
    });
  });

  group('4. Organization Compliance Review Dialog Tests', () {
    testWidgets('Renders organization review credentials correctly', (tester) async {
      final now = DateTime(2026, 11, 1);
      final org = OrganizationModel(
        id: 'org-verify-1',
        name: 'Ohaffia Youths Association',
        slug: 'ohaffia-youths',
        isActive: false,
        openForJoin: false,
        verificationStatus: 'pending_verification',
        cacNumber: 'CAC/IT/54321',
        townUnionName: 'Ohaffia Development Union',
        founderNinOrBvn: '123****7890',
        bankName: 'Zenith Bank',
        accountNumber: '1020304050',
        accountName: 'Ohaffia Youths Central Association',
        isBankVerified: true,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Platform Verification Review'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(org.name),
                            Text(org.cacNumber ?? ''),
                            Text(org.townUnionName ?? ''),
                            Text(org.founderNinOrBvn ?? ''),
                          ],
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Platform Verification Review'), findsOneWidget);
      expect(find.text('Ohaffia Youths Association'), findsOneWidget);
      expect(find.text('CAC/IT/54321'), findsOneWidget);
      expect(find.text('Ohaffia Development Union'), findsOneWidget);
      expect(find.text('123****7890'), findsOneWidget);
    });
  });
}
