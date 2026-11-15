import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/auth/services/auth_service.dart';
import 'package:cls/features/meetings/controllers/meeting_provider.dart';
import 'package:cls/features/meetings/models/meeting_model.dart';
import 'package:cls/features/meetings/models/meeting_resolution_model.dart';
import 'package:cls/features/meetings/views/meeting_detail_screen.dart';
import 'package:cls/features/meetings/views/meeting_minutes_reader_screen.dart';

class _MockAuthService implements AuthService {
  final UserModel user;
  _MockAuthService(this.user);

  @override
  Future<UserModel?> getCurrentUser() async => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testUser = UserModel(
    uid: 'user-001',
    organizationId: 'org-1',
    email: 'pro@test.com',
    displayName: 'Emeka PRO',
    phoneNumber: '08012345678',
    role: UserRole.publicRelationsOfficer,
    branchId: 'branch-aba',
    createdAt: DateTime.now(),
  );

  final testMeeting = MeetingModel(
    id: 'meet-100',
    organizationId: 'org-1',
    title: 'Aba Monthly General Assembly',
    venue: 'Aba Civic Centre',
    meetingDate: DateTime.now().subtract(const Duration(hours: 1)),
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    updatedAt: DateTime.now().subtract(const Duration(minutes: 30)),
    createdBy: 'sec-1',
    scope: 'branch',
    branchId: 'branch-aba',
    targetAudience: 'all',
    minutesText: 'Deliberated on hall renovation, water borehole maintenance, and security levies.',
    isAdopted: true,
    adoptedAt: DateTime.now().subtract(const Duration(minutes: 20)),
    movedBy: 'Chief Okeke',
    secondedBy: 'Mazi Nnamdi',
    adoptionNotes: 'Approved unanimously with no amendments.',
    resolutions: [
      MeetingResolutionModel(
        id: 'res-1',
        title: 'Complete security levy collection by end of month',
        assigneeName: 'Financial Secretary',
        dueDate: DateTime.now().add(const Duration(days: 14)),
      ),
    ],
  );

  Widget createWidget({required MeetingModel meeting, bool readOnly = true}) {
    final mockAuth = _MockAuthService(testUser);
    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWith((ref) => mockAuth),
        authProvider.overrideWith((ref) {
          final notifier = AuthNotifier(ref.watch(authServiceProvider));
          notifier.state = AsyncValue.data(testUser);
          return notifier;
        }),
        singleMeetingStreamProvider(meeting.id).overrideWith(
          (ref) => Stream.value(meeting),
        ),
      ],
      child: MaterialApp(
        home: MeetingDetailScreen(meeting: meeting, readOnly: readOnly),
      ),
    );
  }

  testWidgets(
    'MeetingDetailScreen readOnly renders clean overview header without grayed-out form inputs',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidget(meeting: testMeeting, readOnly: true));
      await tester.pumpAndSettle();

      // Heading card displays meeting details
      expect(find.text('Aba Monthly General Assembly'), findsOneWidget);
      expect(find.text('Aba Civic Centre'), findsOneWidget);
      expect(find.text('ALL MEMBERS'), findsOneWidget);
      expect(find.text('MINUTES READY'), findsOneWidget);

      // Verify that editable form inputs for title/venue are NOT rendered in read-only mode
      expect(find.byType(TextField), findsNothing);

      // Official Deliberations card is rendered
      expect(find.text('Official Deliberations & Proceedings'), findsOneWidget);
      expect(find.text('Read Full Official Minutes'), findsOneWidget);
    },
  );

  testWidgets(
    'Tapping "Read Full Official Minutes" navigates to MeetingMinutesReaderScreen',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidget(meeting: testMeeting, readOnly: true));
      await tester.pumpAndSettle();

      final readButton = find.text('Read Full Official Minutes');
      expect(readButton, findsOneWidget);

      await tester.ensureVisible(readButton);
      await tester.tap(readButton);
      await tester.pumpAndSettle();

      // Navigated to full reader screen
      expect(find.byType(MeetingMinutesReaderScreen), findsOneWidget);
      expect(find.text('Official Minutes Reader'), findsOneWidget);
      expect(find.text('OFFICIAL PROCEEDINGS'), findsOneWidget);
      expect(find.text('Formally Adopted & Ratified'), findsOneWidget);
      expect(find.text('• Motion Moved By: Chief Okeke'), findsOneWidget);
      expect(find.text('• Seconded By: Mazi Nnamdi'), findsOneWidget);
      expect(
        find.text('Deliberated on hall renovation, water borehole maintenance, and security levies.'),
        findsOneWidget,
      );
      expect(
        find.text('Complete security levy collection by end of month'),
        findsOneWidget,
      );
      expect(find.text('Official Document of the Secretariat'), findsOneWidget);
    },
  );
}
