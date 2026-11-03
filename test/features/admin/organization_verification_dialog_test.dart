import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/features/admin/models/organization_model.dart';
import 'package:cls/features/admin/widgets/organization_verification_dialog.dart';

void main() {
  final testOrgPending = OrganizationModel(
    id: 'org-123',
    name: 'Umualoma Youths Age Grade',
    slug: 'umualoma-youths',
    contactEmail: 'contact@umualoma.org',
    contactPhone: '+234 803 123 4567',
    address: 'Anambra, Nigeria',
    isActive: false,
    openForJoin: false,
    verificationStatus: 'pending_verification',
    founderNinOrBvn: '12345678901',
    secretaryNinOrBvn: null,
    cacNumber: 'IT-123456',
    townUnionName: 'Umualoma Town Union Central',
    townUnionContact: '+234 802 987 6543',
    bankName: 'Zenith Bank',
    accountNumber: '1029384756',
    accountName: 'UMUALOMA YOUTHS AGE GRADE',
    isBankVerified: true,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
  );

  testWidgets('OrganizationVerificationDialog renders redesigned layout and sections', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => OrganizationVerificationDialog.show(
                  context,
                  organization: testOrgPending,
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap to open dialog
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // 1. Verify Header (Single-line title and shield badge)
    expect(find.text('Platform Verification Review'), findsOneWidget);
    expect(find.byIcon(Icons.shield_outlined), findsOneWidget);

    // 2. Verify Hero Card
    expect(find.text('Umualoma Youths Age Grade'), findsOneWidget);
    expect(find.text('@umualoma-youths'), findsOneWidget);
    expect(find.text('PENDING REVIEW'), findsOneWidget);

    // 3. Verify Executive Identification Section
    expect(find.text('Executive Identification'), findsOneWidget);
    expect(find.text('FOUNDER (PRESIDENT) IDENTITY'), findsOneWidget);
    expect(find.text('12345678901'), findsOneWidget);
    expect(find.text('Captured'), findsOneWidget);
    expect(find.text('GENERAL SECRETARY IDENTITY'), findsOneWidget);
    expect(find.text('Pending Co-Sign Verification'), findsOneWidget);
    expect(find.text('Pending Co-Sign'), findsOneWidget);

    // 4. Verify Community & Legal Credentials Section
    expect(find.text('Community & Legal Credentials'), findsOneWidget);
    expect(find.text('CAC REGISTRATION NUMBER'), findsOneWidget);
    expect(find.text('IT-123456'), findsOneWidget);
    expect(find.text('Registered'), findsOneWidget);
    expect(find.text('TOWN UNION / APEX BODY'), findsOneWidget);
    expect(find.text('Umualoma Town Union Central'), findsOneWidget);
    expect(find.text('TOWN UNION ENDORSEMENT CONTACT'), findsOneWidget);
    expect(find.text('+234 802 987 6543'), findsOneWidget);

    // 5. Verify Receiving Bank Account Audit Section
    expect(find.text('Receiving Bank Account Audit'), findsOneWidget);
    expect(find.text('Zenith Bank  •  1029384756'), findsOneWidget);
    expect(find.text('UMUALOMA YOUTHS AGE GRADE'), findsOneWidget);
    expect(
      find.text('Association Name Verified: Bank account name matches registered Age Grade records.'),
      findsOneWidget,
    );

    // 6. Verify Actions
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Verify & Activate'), findsOneWidget);

    // 7. Test Close Button dismisses dialog
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Platform Verification Review'), findsNothing);
  });
}
