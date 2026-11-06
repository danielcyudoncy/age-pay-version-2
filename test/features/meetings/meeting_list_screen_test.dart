import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/meetings/controllers/meeting_provider.dart';
import 'package:cls/features/meetings/models/meeting_model.dart';
import 'package:cls/features/meetings/views/meeting_list_screen.dart';
import 'package:cls/features/meetings/views/meeting_detail_screen.dart';
import 'package:cls/features/national/controllers/national_provider.dart';

class _SimpleAuthNotifier extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  _SimpleAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime.now();

  final upcomingBranchMeeting = MeetingModel(
    id: 'm-upcoming-branch',
    organizationId: 'org-1',
    title: 'Aba Branch Monthly Meeting',
    venue: 'Aba Town Hall',
    meetingDate: now.add(const Duration(days: 5)),
    createdAt: now.subtract(const Duration(days: 2)),
    updatedAt: now.subtract(const Duration(days: 2)),
    createdBy: 'sec-1',
    scope: 'branch',
    branchId: 'branch-aba',
    targetAudience: 'all',
  );

  final pastBranchMeetingWithMinutes = MeetingModel(
    id: 'm-past-branch-minutes',
    organizationId: 'org-1',
    title: 'Aba Branch General Meeting',
    venue: 'Aba Community Center',
    meetingDate: now.subtract(const Duration(days: 10)),
    minutesText: 'Resolved that all members shall pay the annual hall renovation levy.',
    minutesFileName: 'meeting_minutes_oct.pdf',
    minutesFileUrl: 'https://storage.googleapis.com/minutes.pdf',
    createdAt: now.subtract(const Duration(days: 15)),
    updatedAt: now.subtract(const Duration(days: 10)),
    createdBy: 'sec-1',
    scope: 'branch',
    branchId: 'branch-aba',
    targetAudience: 'all',
  );

  final pastNationalAssemblyWithMinutes = MeetingModel(
    id: 'm-past-national-minutes',
    organizationId: 'org-1',
    title: 'National Convention Assembly',
    venue: 'National Secretariat, Enugu',
    meetingDate: now.subtract(const Duration(days: 20)),
    minutesText: 'Deliberated on national constitution amendments and constitution adoption.',
    createdAt: now.subtract(const Duration(days: 30)),
    updatedAt: now.subtract(const Duration(days: 20)),
    createdBy: 'nat-sec-1',
    scope: 'national',
    branchId: 'national',
    targetAudience: 'all',
  );

  final pastExecutiveMeeting = MeetingModel(
    id: 'm-past-exec',
    organizationId: 'org-1',
    title: 'Branch Executive Disciplinary Review',
    venue: 'Executive Chamber',
    meetingDate: now.subtract(const Duration(days: 12)),
    minutesText: 'Confidential executive disciplinary deliberations.',
    createdAt: now.subtract(const Duration(days: 14)),
    updatedAt: now.subtract(const Duration(days: 12)),
    createdBy: 'sec-1',
    scope: 'branch',
    branchId: 'branch-aba',
    targetAudience: 'executives',
  );

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Widget createWidget({
    required UserModel user,
    ExecutiveScope scope = ExecutiveScope.branch,
    List<MeetingModel>? meetings,
    int initialTabIndex = 0,
  }) {
    final meetingList = meetings ?? [
      upcomingBranchMeeting,
      pastBranchMeetingWithMinutes,
      pastNationalAssemblyWithMinutes,
      pastExecutiveMeeting,
    ];

    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => _SimpleAuthNotifier(user)),
        activeExecutiveScopeProvider.overrideWith((ref) => scope),
        meetingsStreamProvider.overrideWith((ref) => Stream.value(meetingList)),
      ],
      child: MaterialApp(
        home: MeetingListScreen(initialTabIndex: initialTabIndex),
      ),
    );
  }

  testWidgets('MeetingListScreen displays Upcoming tab and lists upcoming meetings', (tester) async {
    final memberUser = UserModel(
      uid: 'user-1',
      email: 'member@test.com',
      phoneNumber: '08011112222',
      displayName: 'Emeka Okafor',
      role: UserRole.member,
      branchId: 'branch-aba',
      branchName: 'Aba Branch',
      organizationId: 'org-1',
      createdAt: now,
    );

    await tester.pumpWidget(createWidget(user: memberUser, initialTabIndex: 0));
    await tester.pumpAndSettle();

    expect(find.text('Meetings & Minutes Archive'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Past & Minutes'), findsOneWidget);

    // Upcoming meeting is visible in tab 0
    expect(find.text('Aba Branch Monthly Meeting'), findsOneWidget);
    expect(find.text('Branch Meeting'), findsOneWidget);
    expect(find.text('View Minutes & Details'), findsOneWidget);

    // Regular member should NOT see the "+ New Meeting" FAB
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('MeetingListScreen Past & Minutes tab shows minutes badge, snippet, and doc attached tag', (tester) async {
    final memberUser = UserModel(
      uid: 'user-1',
      email: 'member@test.com',
      phoneNumber: '08011112222',
      displayName: 'Emeka Okafor',
      role: UserRole.member,
      branchId: 'branch-aba',
      branchName: 'Aba Branch',
      organizationId: 'org-1',
      createdAt: now,
    );

    await tester.pumpWidget(createWidget(user: memberUser, initialTabIndex: 1));
    await tester.pumpAndSettle();

    // Verify past meetings are displayed with minutes indicators
    expect(find.text('Aba Branch General Meeting'), findsOneWidget);
    expect(find.text('National Convention Assembly'), findsOneWidget);
    expect(find.text('Minutes Ready'), findsNWidgets(2));
    expect(find.text('Doc Attached'), findsOneWidget);
    expect(
      find.text('Resolved that all members shall pay the annual hall renovation levy.'),
      findsOneWidget,
    );

    // Tap on past meeting opens MeetingDetailScreen in read-only mode
    await tester.tap(find.text('Aba Branch General Meeting'));
    await tester.pumpAndSettle();

    expect(find.byType(MeetingDetailScreen), findsOneWidget);
    expect(find.text('Official Meeting Minutes Documented & Verified'), findsOneWidget);
    expect(
      find.text('Resolved that all members shall pay the annual hall renovation levy.'),
      findsOneWidget,
    );
  });

  testWidgets('MeetingListScreen Secretary sees "+ New Meeting" button and can edit', (tester) async {
    final secretaryUser = UserModel(
      uid: 'sec-1',
      email: 'sec@test.com',
      phoneNumber: '08022223333',
      displayName: 'Kalu Secretary',
      role: UserRole.secretary,
      branchId: 'branch-aba',
      branchName: 'Aba Branch',
      organizationId: 'org-1',
      createdAt: now,
    );

    await tester.pumpWidget(createWidget(user: secretaryUser, initialTabIndex: 0));
    await tester.pumpAndSettle();

    // Secretary has "+ New Meeting" FAB and AppBar add action
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('New Meeting'), findsOneWidget);
    expect(find.text('Edit / Document Minutes'), findsOneWidget);
  });

  testWidgets('MeetingListScreen National Secretary in National Scope sees National Meetings title and actions', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final nationalSecUser = UserModel(
      uid: 'nat-sec-1',
      email: 'natsec@test.com',
      phoneNumber: '08033334444',
      displayName: 'Chief Okonkwo',
      role: UserRole.member,
      nationalRole: UserRole.secretary,
      branchId: 'branch-aba',
      branchName: 'Aba Branch',
      organizationId: 'org-1',
      createdAt: now,
    );

    await tester.pumpWidget(
      createWidget(
        user: nationalSecUser,
        scope: ExecutiveScope.national,
        initialTabIndex: 1,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('National Assembly Meetings & Minutes'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('National Convention Assembly'), findsOneWidget);
  });

  testWidgets('MeetingListScreen filters by search query and minutes chip', (tester) async {
    final memberUser = UserModel(
      uid: 'user-1',
      email: 'member@test.com',
      phoneNumber: '08011112222',
      displayName: 'Emeka Okafor',
      role: UserRole.member,
      branchId: 'branch-aba',
      branchName: 'Aba Branch',
      organizationId: 'org-1',
      createdAt: now,
    );

    await tester.pumpWidget(createWidget(user: memberUser, initialTabIndex: 1));
    await tester.pumpAndSettle();

    // Search for "convention"
    await tester.enterText(find.byType(TextField), 'convention');
    await tester.pumpAndSettle();

    expect(find.text('National Convention Assembly'), findsOneWidget);
    expect(find.text('Aba Branch General Meeting'), findsNothing);

    // Clear search
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    expect(find.text('Aba Branch General Meeting'), findsOneWidget);
  });
}
