import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/meetings/controllers/meeting_provider.dart';
import 'package:cls/features/meetings/models/meeting_model.dart';
import 'package:cls/features/meetings/repositories/meeting_repository.dart';
import 'package:cls/features/meetings/views/meeting_detail_screen.dart';
import 'package:cls/features/national/controllers/national_provider.dart';
import 'package:cls/features/notifications/controllers/notification_provider.dart';
import 'package:cls/features/notifications/models/notification_model.dart';
import 'package:cls/features/notifications/repositories/notification_repository.dart';
import 'package:cls/features/secretary/controllers/secretary_dashboard_provider.dart';
import 'package:cls/features/secretary/models/announcement_model.dart';
import 'package:cls/features/secretary/repositories/announcement_repository.dart';

class _SimpleAuthNotifier extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  _SimpleAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMeetingRepository implements MeetingRepository {
  MeetingModel? lastUpdatedMeeting;

  @override
  Future<void> updateMeeting(MeetingModel meeting) async {
    lastUpdatedMeeting = meeting;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAnnouncementRepository implements AnnouncementRepository {
  AnnouncementModel? lastCreatedAnnouncement;

  @override
  Future<String> createAnnouncement(AnnouncementModel announcement) async {
    lastCreatedAnnouncement = announcement;
    return 'ann-123';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNotificationRepository implements NotificationRepository {
  NotificationModel? lastSentNotification;

  @override
  Future<void> sendNotification(NotificationModel notification) async {
    lastSentNotification = notification;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime.now();

  final existingBranchMeeting = MeetingModel(
    id: 'meet-101',
    organizationId: 'org-1',
    title: 'Aba Quarterly General Assembly',
    venue: 'Aba Town Hall',
    meetingDate: now.subtract(const Duration(days: 3)),
    createdAt: now.subtract(const Duration(days: 10)),
    updatedAt: now.subtract(const Duration(days: 3)),
    createdBy: 'sec-1',
    scope: 'branch',
    branchId: 'branch-aba',
    targetAudience: 'all',
  );

  final existingNationalMeeting = MeetingModel(
    id: 'meet-202',
    organizationId: 'org-1',
    title: 'National Executive Caucus',
    venue: 'National Conference Hall, Abuja',
    meetingDate: now.subtract(const Duration(days: 5)),
    createdAt: now.subtract(const Duration(days: 15)),
    updatedAt: now.subtract(const Duration(days: 5)),
    createdBy: 'nat-sec-1',
    scope: 'national',
    branchId: 'national',
    targetAudience: 'executives',
  );

  testWidgets('Branch Secretary publishes minutes and triggers announcement & notification', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final branchSec = UserModel(
      uid: 'sec-1',
      email: 'sec@test.com',
      phoneNumber: '08012345678',
      displayName: 'Branch Secretary Kalu',
      role: UserRole.secretary,
      branchId: 'branch-aba',
      branchName: 'Aba Branch',
      organizationId: 'org-1',
      createdAt: now,
    );

    final fakeMeetingRepo = _FakeMeetingRepository();
    final fakeAnnRepo = _FakeAnnouncementRepository();
    final fakeNotifRepo = _FakeNotificationRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _SimpleAuthNotifier(branchSec)),
          activeExecutiveScopeProvider.overrideWith((ref) => ExecutiveScope.branch),
          meetingRepositoryProvider.overrideWithValue(fakeMeetingRepo),
          announcementRepositoryProvider.overrideWithValue(fakeAnnRepo),
          notificationRepositoryProvider.overrideWithValue(fakeNotifRepo),
        ],
        child: MaterialApp(
          home: MeetingDetailScreen(meeting: existingBranchMeeting, readOnly: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify both "Publish Minutes & Notify Members" and "Save Details" buttons are present
    expect(find.text('Publish Minutes & Notify Members'), findsOneWidget);
    expect(find.text('Save Details (Without Notifying)'), findsOneWidget);

    // Enter minutes into text field
    final minutesField = find.byKey(const Key('meeting_minutes_field'));
    await tester.ensureVisible(minutesField);
    await tester.enterText(
      minutesField,
      'Deliberated on road maintenance. Passed resolution to levy ₦5,000 per member.',
    );
    await tester.pumpAndSettle();

    // Tap "Publish Minutes & Notify Members"
    final publishButton = find.text('Publish Minutes & Notify Members');
    await tester.ensureVisible(publishButton);
    await tester.tap(publishButton);
    await tester.pumpAndSettle();

    // Verify Meeting was updated in repository
    expect(fakeMeetingRepo.lastUpdatedMeeting, isNotNull);
    expect(
      fakeMeetingRepo.lastUpdatedMeeting!.minutesText,
      'Deliberated on road maintenance. Passed resolution to levy ₦5,000 per member.',
    );

    // Verify Announcement was created and properly scoped to Branch
    expect(fakeAnnRepo.lastCreatedAnnouncement, isNotNull);
    final ann = fakeAnnRepo.lastCreatedAnnouncement!;
    expect(ann.title, '📝 Meeting Minutes Published: Aba Quarterly General Assembly');
    expect(ann.category, AnnouncementCategory.meeting);
    expect(ann.targetAudience, 'branch');
    expect(ann.targetBranchId, 'branch-aba');

    // Verify Notification was dispatched
    expect(fakeNotifRepo.lastSentNotification, isNotNull);
    final notif = fakeNotifRepo.lastSentNotification!;
    expect(notif.title, 'Meeting Minutes Published: Aba Quarterly General Assembly');
    expect(notif.targetBranchId, 'branch-aba');
    expect(notif.payload, 'meet-101');
  });

  testWidgets('National Secretary publishes minutes with National scoping', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final natSec = UserModel(
      uid: 'nat-sec-1',
      email: 'natsec@test.com',
      phoneNumber: '08099998888',
      displayName: 'National Gen Secretary',
      role: UserRole.member,
      nationalRole: UserRole.secretary,
      branchId: 'branch-aba',
      branchName: 'Aba Branch',
      organizationId: 'org-1',
      createdAt: now,
    );

    final fakeMeetingRepo = _FakeMeetingRepository();
    final fakeAnnRepo = _FakeAnnouncementRepository();
    final fakeNotifRepo = _FakeNotificationRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _SimpleAuthNotifier(natSec)),
          activeExecutiveScopeProvider.overrideWith((ref) => ExecutiveScope.national),
          meetingRepositoryProvider.overrideWithValue(fakeMeetingRepo),
          announcementRepositoryProvider.overrideWithValue(fakeAnnRepo),
          notificationRepositoryProvider.overrideWithValue(fakeNotifRepo),
        ],
        child: MaterialApp(
          home: MeetingDetailScreen(meeting: existingNationalMeeting, readOnly: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Enter minutes
    final minutesField = find.byKey(const Key('meeting_minutes_field'));
    await tester.ensureVisible(minutesField);
    await tester.enterText(
      minutesField,
      'National executive caucus approved 2027 fiscal budget and national conference date.',
    );
    await tester.pumpAndSettle();

    // Publish
    final publishButton = find.text('Publish Minutes & Notify Members');
    await tester.ensureVisible(publishButton);
    await tester.tap(publishButton);
    await tester.pumpAndSettle();

    // Verify Announcement is scoped to national executives
    expect(fakeAnnRepo.lastCreatedAnnouncement, isNotNull);
    final ann = fakeAnnRepo.lastCreatedAnnouncement!;
    expect(ann.title, '🏛️ Executive Minutes Published: National Executive Caucus');
    expect(ann.targetAudience, 'nationalexecutives');
    expect(ann.targetBranchId, isNull);

    // Verify Notification is scoped to executives
    expect(fakeNotifRepo.lastSentNotification, isNotNull);
    final notif = fakeNotifRepo.lastSentNotification!;
    expect(notif.targetRole, 'executives');
    expect(notif.targetBranchId, isNull);
  });

  testWidgets('Validation prevents publishing empty minutes', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final branchSec = UserModel(
      uid: 'sec-1',
      email: 'sec@test.com',
      phoneNumber: '08012345678',
      displayName: 'Branch Secretary Kalu',
      role: UserRole.secretary,
      branchId: 'branch-aba',
      organizationId: 'org-1',
      createdAt: now,
    );

    final fakeMeetingRepo = _FakeMeetingRepository();
    final fakeAnnRepo = _FakeAnnouncementRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _SimpleAuthNotifier(branchSec)),
          activeExecutiveScopeProvider.overrideWith((ref) => ExecutiveScope.branch),
          meetingRepositoryProvider.overrideWithValue(fakeMeetingRepo),
          announcementRepositoryProvider.overrideWithValue(fakeAnnRepo),
        ],
        child: MaterialApp(
          home: MeetingDetailScreen(meeting: existingBranchMeeting, readOnly: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap "Publish Minutes & Notify Members" with empty minutes
    final publishButton = find.text('Publish Minutes & Notify Members');
    await tester.ensureVisible(publishButton);
    await tester.tap(publishButton);
    await tester.pumpAndSettle();

    // Error is shown and no announcement was dispatched
    expect(
      find.text('Please enter minutes or attach a file before publishing to members.'),
      findsOneWidget,
    );
    expect(fakeAnnRepo.lastCreatedAnnouncement, isNull);
  });
}
