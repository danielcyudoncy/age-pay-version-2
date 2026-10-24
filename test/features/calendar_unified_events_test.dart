// test/features/calendar_unified_events_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/auth/services/auth_service.dart';
import 'package:cls/features/dashboard/views/pro_dashboard.dart';
import 'package:cls/features/secretary/views/calendar_screen.dart';
import 'package:cls/features/secretary/views/announcements_screen.dart';
import 'package:cls/features/secretary/controllers/calendar_event_provider.dart';
import 'package:cls/features/secretary/controllers/secretary_dashboard_provider.dart';
import 'package:cls/features/secretary/models/calendar_event_model.dart';
import 'package:cls/features/secretary/models/announcement_model.dart';
import 'package:cls/features/secretary/repositories/announcement_repository.dart';
import 'package:cls/features/secretary/repositories/calendar_event_repository.dart';
import 'package:cls/features/secretary/repositories/document_repository.dart';
import 'package:cls/features/secretary/models/document_model.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/members/repositories/member_repository.dart';
import 'package:cls/features/meetings/models/meeting_model.dart';
import 'package:cls/features/meetings/repositories/meeting_repository.dart';
import 'package:cls/features/meetings/controllers/meeting_provider.dart';
import 'package:cls/features/notifications/controllers/notification_provider.dart';
import 'package:cls/features/payments/repositories/payment_repository.dart';
import 'package:cls/features/obligations/repositories/obligation_repository.dart';
import 'package:cls/features/payments/models/payment_model.dart';
import 'package:cls/features/obligations/models/obligation_model.dart';
import 'package:cls/features/obligations/controllers/obligation_provider.dart';
import 'package:cls/features/dashboard/controllers/member_dashboard_provider.dart';

class _MockAuthService implements AuthService {
  final UserModel? user;
  _MockAuthService(this.user);

  @override
  Future<UserModel?> getCurrentUser() async => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockPaymentRepo implements PaymentRepository {
  @override
  Stream<List<PaymentModel>> getMemberPayments(String memberId) => Stream.value([]);
  @override
  Stream<List<PaymentModel>> getAllPayments() => Stream.value([]);
  @override
  Stream<List<PaymentModel>> getPendingPayments() => Stream.value([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockObligationRepo implements ObligationRepository {
  @override
  Stream<List<ObligationModel>> getMemberActiveObligations(String memberId) => Stream.value([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockAnnouncementRepo implements AnnouncementRepository {
  final List<AnnouncementModel> announcements;
  _MockAnnouncementRepo(this.announcements);

  @override
  Stream<List<AnnouncementModel>> getAnnouncements(String organizationId) =>
      Stream.value(announcements);

  @override
  Stream<List<AnnouncementModel>> getAnnouncementsForDate(String organizationId, DateTime date) {
    final filtered = announcements.where((a) =>
      a.announcementDate != null &&
      a.announcementDate!.year == date.year &&
      a.announcementDate!.month == date.month &&
      a.announcementDate!.day == date.day
    ).toList();
    return Stream.value(filtered);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockCalendarRepo implements CalendarEventRepository {
  final List<CalendarEventModel> events;
  _MockCalendarRepo(this.events);

  @override
  Stream<List<CalendarEventModel>> getEvents(String organizationId) =>
      Stream.value(events);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockMeetingRepo implements MeetingRepository {
  final List<MeetingModel> meetings;
  _MockMeetingRepo(this.meetings);

  @override
  Stream<List<MeetingModel>> getMeetings() => Stream.value(meetings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockDocumentRepo implements DocumentRepository {
  final List<DocumentModel> docs;
  _MockDocumentRepo(this.docs);

  @override
  Stream<List<DocumentModel>> getDocuments(String organizationId) =>
      Stream.value(docs);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockMemberRepo implements MemberRepository {
  final List<MemberModel> members;
  _MockMemberRepo(this.members);

  @override
  Stream<List<MemberModel>> getMembers() => Stream.value(members);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const orgId = 'org-pro-test';
  final proUser = UserModel(
    uid: 'user-pro-1',
    organizationId: orgId,
    email: 'pro@agepay.org',
    displayName: 'Chief Emeka PRO',
    phoneNumber: '+2348011223344',
    role: UserRole.publicRelationsOfficer,
    createdAt: DateTime(2026, 1, 1),
  );

  // A meeting announcement scheduled for tomorrow (upcoming)
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  final meetingAnnouncement = AnnouncementModel(
    id: 'ann_meeting_1',
    organizationId: orgId,
    title: 'Emergency General Meeting',
    body: 'Discussion regarding constitution amendments',
    category: AnnouncementCategory.meeting,
    announcementDate: tomorrow,
    createdBy: 'user-pro-1',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  Widget createTestWidget({
    required Widget child,
    List<AnnouncementModel> announcements = const [],
    List<CalendarEventModel> events = const [],
    List<MeetingModel> meetings = const [],
  }) {
    final mockAuth = _MockAuthService(proUser);
    final mockPayments = _MockPaymentRepo();
    final mockObligationRepo = _MockObligationRepo();
    final mockAnnouncementRepo = _MockAnnouncementRepo(announcements);
    final mockCalendarRepo = _MockCalendarRepo(events);
    final mockMeetingRepo = _MockMeetingRepo(meetings);
    final mockDocumentRepo = _MockDocumentRepo(const []);
    final mockMemberRepo = _MockMemberRepo(const []);

    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWith((ref) => mockAuth),
        authProvider.overrideWith((ref) {
          final notifier = AuthNotifier(ref.watch(authServiceProvider));
          notifier.state = AsyncValue.data(proUser);
          return notifier;
        }),
        unreadCountProvider.overrideWith((ref) => 0),
        announcementRepositoryProvider.overrideWith((ref) => mockAnnouncementRepo),
        calendarEventRepositoryProvider.overrideWith((ref) => mockCalendarRepo),
        meetingRepositoryProvider.overrideWith((ref) => mockMeetingRepo),
        documentRepositoryProvider.overrideWith((ref) => mockDocumentRepo),
        memberRepositoryProvider.overrideWith((ref) => mockMemberRepo),
        paymentRepositoryProvider.overrideWith((ref) => mockPayments),
        obligationRepositoryProvider.overrideWith((ref) => mockObligationRepo),
      ],
      child: MaterialApp(home: child),
    );
  }

  testWidgets('allCalendarEventsProvider captures broadcast announcements and displays in CalendarScreen upcoming list', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      createTestWidget(
        child: const CalendarScreen(),
        announcements: [meetingAnnouncement],
        events: const [], // 0 calendar_events
      ),
    );

    await tester.pumpAndSettle();

    // Verify CalendarScreen is displayed
    expect(find.text('Calendar'), findsOneWidget);

    // Verify the upcoming meeting announcement is captured and displayed
    expect(find.text('Emergency General Meeting'), findsWidgets);
    expect(find.textContaining('BROADCAST'), findsWidgets);
    expect(find.text('No upcoming events'), findsNothing);

    // Tap on the event card to open event details popup dialog
    await tester.tap(find.text('Emergency General Meeting').first);
    await tester.pumpAndSettle();

    // Verify centered AlertDialog opens with event details
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Broadcast Announcement'), findsOneWidget);
    expect(find.text('Discussion regarding constitution amendments'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    // Tap close to dismiss dialog
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('ProDashboard Mobilization & Events captures upcoming broadcast meeting announcement', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      createTestWidget(
        child: const ProDashboard(),
        announcements: [meetingAnnouncement],
        events: const [], // 0 calendar_events
      ),
    );

    await tester.pumpAndSettle();

    // The KPI metric card should show 1 event (not 0)
    expect(find.text('Calendar Events'), findsOneWidget);
    expect(find.text('1'), findsWidgets);

    // Mobilization & Events and Recent Broadcasts should both list the emergency general meeting
    expect(find.text('Mobilization & Events'), findsOneWidget);
    expect(find.text('Recent Broadcasts'), findsOneWidget);
    expect(find.text('Emergency General Meeting'), findsWidgets);
    expect(find.text('No upcoming events scheduled'), findsNothing);
  });

  testWidgets('AnnouncementsScreen renders calendar even when announcements list is empty', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      createTestWidget(
        child: const AnnouncementsScreen(),
        announcements: const [],
      ),
    );

    await tester.pumpAndSettle();

    // Verify Announcements title is displayed
    expect(find.text('Announcements'), findsOneWidget);

    // Verify calendar days 'M', 'T', 'W' are still rendered
    expect(find.text('M'), findsOneWidget);
    expect(find.text('T'), findsNWidgets(2)); // Tuesday and Thursday
    expect(find.text('No announcements yet'), findsOneWidget);
  });
}
