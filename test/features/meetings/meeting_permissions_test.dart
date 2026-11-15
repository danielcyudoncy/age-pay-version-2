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
import 'package:cls/features/meetings/views/meeting_list_screen.dart';

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

  final testMeeting = MeetingModel(
    id: 'meet-101',
    organizationId: 'org-1',
    title: 'Monthly Governance Sitting',
    venue: 'Secretariat Hall',
    meetingDate: DateTime.now().subtract(const Duration(hours: 2)),
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    updatedAt: DateTime.now().subtract(const Duration(minutes: 10)),
    createdBy: 'sec-1',
    scope: 'branch',
    branchId: 'branch-aba',
    targetAudience: 'all',
    minutesText: 'Official secretarial deliberations.',
    isAdopted: false,
    resolutions: [
      MeetingResolutionModel(
        id: 'res-1',
        title: 'Draft annual expenditure summary',
      ),
    ],
  );

  Widget createDetailWidget({
    required UserModel user,
    required MeetingModel meeting,
    bool readOnly = false,
  }) {
    final mockAuth = _MockAuthService(user);
    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWith((ref) => mockAuth),
        authProvider.overrideWith((ref) {
          final notifier = AuthNotifier(ref.watch(authServiceProvider));
          notifier.state = AsyncValue.data(user);
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

  Widget createListWidget({required UserModel user}) {
    final mockAuth = _MockAuthService(user);
    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWith((ref) => mockAuth),
        authProvider.overrideWith((ref) {
          final notifier = AuthNotifier(ref.watch(authServiceProvider));
          notifier.state = AsyncValue.data(user);
          return notifier;
        }),
        meetingsStreamProvider.overrideWith(
          (ref) => Stream.value([testMeeting]),
        ),
      ],
      child: const MaterialApp(
        home: MeetingListScreen(),
      ),
    );
  }

  group('Meeting Permissions - Secretariat Exclusivity', () {
    testWidgets(
      'Non-secretary (PRO/President/Member) cannot publish minutes, edit, or adopt minutes',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final proUser = UserModel(
          uid: 'user-pro',
          organizationId: 'org-1',
          email: 'pro@test.com',
          displayName: 'Chidi PRO',
          phoneNumber: '08011112222',
          role: UserRole.publicRelationsOfficer,
          branchId: 'branch-aba',
          createdAt: DateTime.now(),
        );

        // Even if readOnly: false is passed, non-secretary is locked into read-only
        await tester.pumpWidget(
          createDetailWidget(user: proUser, meeting: testMeeting, readOnly: false),
        );
        await tester.pumpAndSettle();

        // Title shows 'Meeting Details'
        expect(find.text('Meeting Details'), findsOneWidget);
        expect(find.text('Meeting Minutes'), findsNothing);

        // Edit button is NOT visible to non-secretary
        expect(find.byIcon(Icons.edit_outlined), findsNothing);

        // Minutes publishing / saving buttons are NOT rendered
        expect(find.text('Publish Minutes & Notify Members'), findsNothing);
        expect(find.text('Save Details (Without Notifying)'), findsNothing);

        // Adoption & resolution buttons are NOT rendered
        expect(find.text('Record Minutes Adoption (Proposer & Seconder)'), findsNothing);
        expect(find.text('Add Action Item'), findsNothing);

        // Full Reader button IS accessible to read the proceedings
        expect(find.text('Read Full Official Minutes'), findsOneWidget);
      },
    );

    testWidgets(
      'Secretary has full rights to edit and publish minutes',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final secUser = UserModel(
          uid: 'user-sec',
          organizationId: 'org-1',
          email: 'sec@test.com',
          displayName: 'Ada Secretary',
          phoneNumber: '08099998888',
          role: UserRole.secretary,
          branchId: 'branch-aba',
          createdAt: DateTime.now(),
        );

        // 1. In readOnly: true mode, Secretary sees the edit button
        await tester.pumpWidget(
          createDetailWidget(user: secUser, meeting: testMeeting, readOnly: true),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

        // 2. In edit mode (readOnly: false), Secretary sees publishing and documentation controls
        await tester.pumpWidget(
          createDetailWidget(user: secUser, meeting: testMeeting, readOnly: false),
        );
        await tester.pumpAndSettle();

        expect(find.text('Meeting Minutes'), findsOneWidget);
        expect(find.text('Publish Minutes & Notify Members'), findsOneWidget);
        expect(find.text('Save Details (Without Notifying)'), findsOneWidget);
        expect(find.text('Record Minutes Adoption (Proposer & Seconder)'), findsOneWidget);
        expect(find.text('Add Action Item'), findsOneWidget);
      },
    );

    testWidgets(
      'MeetingListScreen hides Schedule Meeting button from non-Secretariat members',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final memberUser = UserModel(
          uid: 'user-mem',
          organizationId: 'org-1',
          email: 'member@test.com',
          displayName: 'John Member',
          phoneNumber: '08033334444',
          role: UserRole.member,
          branchId: 'branch-aba',
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(createListWidget(user: memberUser));
        await tester.pumpAndSettle();

        // Non-secretary should NOT see Add (+) button
        expect(find.byIcon(Icons.add), findsNothing);
      },
    );

    testWidgets(
      'MeetingListScreen displays Schedule Meeting button for Secretary',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final secUser = UserModel(
          uid: 'user-sec-2',
          organizationId: 'org-1',
          email: 'sec2@test.com',
          displayName: 'Ada Secretary',
          phoneNumber: '08099998888',
          role: UserRole.secretary,
          branchId: 'branch-aba',
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(createListWidget(user: secUser));
        await tester.pumpAndSettle();

        // Secretary sees both the AppBar Schedule button and the Floating Action Button
        expect(find.byTooltip('Schedule Meeting'), findsOneWidget);
        expect(find.text('New Meeting'), findsOneWidget);
      },
    );
  });
}
