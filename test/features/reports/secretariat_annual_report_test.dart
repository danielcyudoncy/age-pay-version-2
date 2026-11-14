import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/features/meetings/models/meeting_model.dart';
import 'package:cls/features/meetings/models/meeting_resolution_model.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/reports/controllers/reports_provider.dart';
import 'package:cls/features/reports/services/pdf_service.dart';
import 'package:cls/features/reports/widgets/secretariat_annual_report_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Secretariat Annual Activity Report & PDF Tests', () {
    final reportYear = 2026;

    final testMembers = [
      MemberModel(
        id: 'mem_1',
        userId: 'u1',
        fullName: 'Chief Emeka President',
        email: 'pres@test.com',
        phoneNumber: '+2348011111111',
        dateOfBirth: DateTime(1980, 1, 1),
        joinedDate: DateTime(2020, 1, 1),
        status: 'active',
        isActive: true,
        createdAt: DateTime(2020, 1, 1),
        updatedAt: DateTime.now(),
      ),
      MemberModel(
        id: 'mem_2',
        userId: 'u2',
        fullName: 'Chidi Secretary',
        email: 'sec@test.com',
        phoneNumber: '+2348022222222',
        dateOfBirth: DateTime(1985, 2, 2),
        joinedDate: DateTime(2021, 2, 1),
        status: 'probationary',
        isActive: true,
        createdAt: DateTime(2026, 3, 1), // Intake in 2026
        updatedAt: DateTime.now(),
      ),
      MemberModel(
        id: 'mem_3',
        userId: 'u3',
        fullName: 'Ngozi Diaspora',
        email: 'ngozi@uk.com',
        phoneNumber: '+447000000000',
        dateOfBirth: DateTime(1990, 5, 5),
        joinedDate: DateTime(2022, 5, 1),
        status: 'diaspora',
        isActive: true,
        createdAt: DateTime(2022, 5, 1),
        updatedAt: DateTime.now(),
      ),
      MemberModel(
        id: 'mem_4',
        userId: 'u4',
        fullName: 'Late Elder Nduka',
        email: 'nduka@archived.com',
        phoneNumber: '+2348044444444',
        dateOfBirth: DateTime(1950, 4, 4),
        joinedDate: DateTime(2010, 1, 1),
        status: 'deceased',
        isActive: false,
        createdAt: DateTime(2010, 1, 1),
        updatedAt: DateTime.now(),
      ),
    ];

    final List<MeetingModel> testMeetings = [
      MeetingModel(
        id: 'meet_2026_1',
        title: 'Q1 General Meeting',
        venue: 'Lagos Secretariat',
        meetingDate: DateTime(2026, 3, 15, 14, 0),
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 16),
        createdBy: 'u2',
        isAdopted: true,
        adoptedAt: DateTime(2026, 4, 10),
        movedBy: 'Chief Emeka President',
        secondedBy: 'Chidi Secretary',
        adoptionNotes: 'Adopted unanimously without objection.',
        minutesText: 'Meeting called to order at 2:00 PM.',
        resolutions: [
          MeetingResolutionModel(
            id: 'r_1',
            title: 'Fix branch generator',
            assigneeName: 'Provost',
            isCompleted: true,
            completedAt: DateTime(2026, 3, 20),
          ),
          MeetingResolutionModel(
            id: 'r_2',
            title: 'Audit hall renovation invoices',
            assigneeName: 'Auditor',
            isCompleted: false,
          ),
        ],
      ),
      MeetingModel(
        id: 'meet_2026_2',
        title: 'Q2 General Meeting',
        venue: 'Lagos Secretariat',
        meetingDate: DateTime(2026, 6, 20, 14, 0),
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 21),
        createdBy: 'u2',
        isAdopted: false,
        resolutions: [
          MeetingResolutionModel(
            id: 'r_3',
            title: 'Organize end-of-year symposium',
            assigneeName: 'PRO',
            isCompleted: false,
          ),
        ],
      ),
    ];

    testWidgets('SecretariatAnnualReportWidget renders all KPI cards and registers',
        (tester) async {
      final request = ReportRequest(
        type: ReportType.secretariatAnnualReport,
        year: reportYear,
        organizationName: 'Umuahia Progressive Union',
        branchName: 'Lagos Mainland Branch',
        meetings: testMeetings,
        members: testMembers,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SecretariatAnnualReportWidget(request: request),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header assertions
      expect(find.text('Umuahia Progressive Union'), findsOneWidget);
      expect(find.textContaining('Lagos Mainland Branch'), findsOneWidget);
      expect(find.textContaining('2026 Annual Activity Report'), findsOneWidget);

      // Governance KPIs
      expect(find.text('Meetings Held'), findsOneWidget);
      expect(find.text('Minutes Adopted'), findsOneWidget);
      expect(find.text('50% ratified'), findsOneWidget);
      expect(find.text('Resolutions Logged'), findsOneWidget);
      expect(find.text('1 completed'), findsOneWidget);
      expect(find.text('Total Members'), findsOneWidget);

      // Section 2: Membership Breakdown
      expect(find.text('Membership Roll & Vital Statistics'), findsOneWidget);
      expect(find.text('Active Members in Good Standing'), findsOneWidget);
      expect(find.text('Probationary Members (New Intakes)'), findsOneWidget);
      expect(find.text('Diaspora & Relocated Members'), findsOneWidget);
      expect(find.text('Deceased Members (In Memoriam)'), findsOneWidget);

      // Section 3: Meetings & Minutes Log
      expect(find.text('Q1 General Meeting'), findsOneWidget);
      expect(find.text('Q2 General Meeting'), findsOneWidget);
      expect(find.text('Adopted'), findsOneWidget);

      // Section 4: Resolutions & Matters Arising Tracker
      expect(find.text('Fix branch generator'), findsOneWidget);
      expect(find.text('Audit hall renovation invoices'), findsOneWidget);
      expect(find.text('Organize end-of-year symposium'), findsOneWidget);

      // Section 5: Dual Attestation Signatures
      expect(find.text('General Secretary'), findsOneWidget);
      expect(find.text('President / Chairman'), findsOneWidget);
    });

    test('PdfService generates non-empty PDF bytes for secretariat annual report',
        () async {
      final pdfService = PdfService();
      final Uint8List pdfBytes = await pdfService.generateSecretariatAnnualReport(
        year: reportYear,
        organizationName: 'Umuahia Progressive Union',
        branchName: 'Lagos Mainland Branch',
        meetings: testMeetings,
        members: testMembers,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, true);
      // PDF documents start with '%PDF-'
      expect(pdfBytes.length, greaterThan(500));
    });
  });
}
