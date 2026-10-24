// test/features/pro_dashboard_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/core/widgets/quick_action_button.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/auth/services/auth_service.dart';
import 'package:cls/features/dashboard/controllers/member_dashboard_provider.dart';
import 'package:cls/features/dashboard/views/pro_dashboard.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/members/repositories/member_repository.dart';
import 'package:cls/features/notifications/controllers/notification_provider.dart';
import 'package:cls/features/obligations/controllers/obligation_provider.dart';
import 'package:cls/features/secretary/controllers/calendar_event_provider.dart';
import 'package:cls/features/secretary/controllers/secretary_dashboard_provider.dart';
import 'package:cls/features/secretary/models/announcement_model.dart';
import 'package:cls/features/secretary/models/calendar_event_model.dart';
import 'package:cls/features/secretary/models/document_model.dart';
import 'package:cls/features/secretary/repositories/announcement_repository.dart';
import 'package:cls/features/secretary/repositories/calendar_event_repository.dart';
import 'package:cls/features/secretary/repositories/document_repository.dart';
import 'package:cls/features/secretary/views/search_screen.dart';
import 'package:cls/features/payments/repositories/payment_repository.dart';
import 'package:cls/features/obligations/repositories/obligation_repository.dart';
import 'package:cls/features/payments/models/payment_model.dart';
import 'package:cls/features/obligations/models/obligation_model.dart';

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

  final testAnnouncements = [
    AnnouncementModel(
      id: 'ann-1',
      organizationId: orgId,
      title: 'Annual General Cultural Festival',
      body: 'All members and branch delegates should mobilize in full regalia.',
      category: AnnouncementCategory.event,
      targetAudience: 'all',
      createdBy: 'user-pro-1',
      createdAt: DateTime(2026, 6, 10),
      updatedAt: DateTime(2026, 6, 10),
    ),
    AnnouncementModel(
      id: 'ann-2',
      organizationId: orgId,
      title: 'Community Clean-up Mobilization',
      body: 'Youth wing and all branches assemble Saturday 7am.',
      category: AnnouncementCategory.general,
      targetAudience: 'all',
      createdBy: 'user-pro-1',
      createdAt: DateTime(2026, 6, 12),
      updatedAt: DateTime(2026, 6, 12),
    ),
  ];

  final testEvents = [
    CalendarEventModel(
      id: 'evt-1',
      organizationId: orgId,
      title: 'Town Hall Meeting & Press Briefing',
      description: 'Quarterly review with media correspondents.',
      type: CalendarEventType.meeting,
      startDate: DateTime.now().add(const Duration(days: 3)),
      endDate: DateTime.now().add(const Duration(days: 3, hours: 2)),
      createdBy: 'user-pro-1',
      location: 'Civic Center Hall A',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  final testDocs = [
    DocumentModel(
      id: 'doc-1',
      organizationId: orgId,
      title: 'Press_Release_Q2.pdf',
      description: 'Quarterly press release',
      category: DocumentCategory.reports,
      fileUrl: 'https://example.com/press.pdf',
      fileName: 'Press_Release_Q2.pdf',
      fileSize: 1024,
      mimeType: 'application/pdf',
      uploadedBy: 'user-pro-1',
      uploadedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    DocumentModel(
      id: 'doc-2',
      organizationId: orgId,
      title: 'Constitution_Extract.pdf',
      description: 'Rules and constitution',
      category: DocumentCategory.constitution,
      fileUrl: 'https://example.com/const.pdf',
      fileName: 'Constitution.pdf',
      fileSize: 2048,
      mimeType: 'application/pdf',
      uploadedBy: 'user-pro-1',
      uploadedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    DocumentModel(
      id: 'doc-3',
      organizationId: orgId,
      title: 'Mobilization_Schedule.pdf',
      description: 'Mobilization dates',
      category: DocumentCategory.reports,
      fileUrl: 'https://example.com/schedule.pdf',
      fileName: 'Schedule.pdf',
      fileSize: 512,
      mimeType: 'application/pdf',
      uploadedBy: 'user-pro-1',
      uploadedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  final testMembers = [
    MemberModel(
      id: 'm1',
      userId: 'u1',
      fullName: 'Member One',
      email: 'm1@test.com',
      phoneNumber: '08011111111',
      dateOfBirth: DateTime(1990, 1, 1),
      joinedDate: DateTime(2020, 1, 1),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    MemberModel(
      id: 'm2',
      userId: 'u2',
      fullName: 'Member Two',
      email: 'm2@test.com',
      phoneNumber: '08022222222',
      dateOfBirth: DateTime(1992, 2, 2),
      joinedDate: DateTime(2021, 1, 1),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    MemberModel(
      id: 'm3',
      userId: 'u3',
      fullName: 'Member Three',
      email: 'm3@test.com',
      phoneNumber: '08033333333',
      dateOfBirth: DateTime(1993, 3, 3),
      joinedDate: DateTime(2022, 1, 1),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    MemberModel(
      id: 'm4',
      userId: 'u4',
      fullName: 'Member Four',
      email: 'm4@test.com',
      phoneNumber: '08044444444',
      dateOfBirth: DateTime(1994, 4, 4),
      joinedDate: DateTime(2023, 1, 1),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  Widget buildProDashboard({
    UserModel? user,
    List<AnnouncementModel> announcements = const [],
    List<CalendarEventModel> events = const [],
    List<DocumentModel> docs = const [],
    List<MemberModel> members = const [],
    int unreadNotifications = 0,
  }) {
    final mockAuth = _MockAuthService(user);
    final mockPayments = _MockPaymentRepo();
    final mockObligationRepo = _MockObligationRepo();
    final mockAnnouncementRepo = _MockAnnouncementRepo(announcements);
    final mockCalendarRepo = _MockCalendarRepo(events);
    final mockDocumentRepo = _MockDocumentRepo(docs);
    final mockMemberRepo = _MockMemberRepo(members);

    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWith((ref) => mockAuth),
        authProvider.overrideWith((ref) {
          final notifier = AuthNotifier(ref.watch(authServiceProvider));
          if (user != null) {
            notifier.state = AsyncValue.data(user);
          } else {
            notifier.state = const AsyncValue.data(null);
          }
          return notifier;
        }),
        unreadCountProvider.overrideWith((ref) => unreadNotifications),
        announcementRepositoryProvider.overrideWith((ref) => mockAnnouncementRepo),
        calendarEventRepositoryProvider.overrideWith((ref) => mockCalendarRepo),
        documentRepositoryProvider.overrideWith((ref) => mockDocumentRepo),
        memberRepositoryProvider.overrideWith((ref) => mockMemberRepo),
        paymentRepositoryProvider.overrideWith((ref) => mockPayments),
        obligationRepositoryProvider.overrideWith((ref) => mockObligationRepo),
      ],
      child: const MaterialApp(
        home: ProDashboard(),
      ),
    );
  }

  group('ProDashboard Widget Tests', () {
    testWidgets('renders Please sign in when user is unauthenticated', (tester) async {
      await tester.pumpWidget(buildProDashboard(user: null));
      await tester.pumpAndSettle();

      expect(find.text('Please sign in'), findsOneWidget);
    });

    testWidgets('renders PRO header, badge, metric cards, and titles', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildProDashboard(
          user: proUser,
          announcements: testAnnouncements,
          events: testEvents,
          docs: testDocs,
          members: testMembers,
          unreadNotifications: 7,
        ),
      );
      await tester.pumpAndSettle();

      // App bar & Header
      expect(find.text('Public Relations (PRO)'), findsOneWidget);
      expect(find.text('Chief Emeka PRO'), findsOneWidget);
      expect(find.text('PRO'), findsOneWidget);
      expect(
        find.text('Publicity, Member Mobilization & External Relations'),
        findsOneWidget,
      );

      // Notification badge
      expect(find.text('7'), findsOneWidget);

      // Metric Cards
      expect(find.text('Announcements'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // 2 announcements

      expect(find.text('Calendar Events'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // 1 event

      expect(find.text('Media & Docs'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // 3 docs

      expect(find.text('Roster Members'), findsOneWidget);
      expect(find.text('4'), findsOneWidget); // 4 members

      // Quick Actions
      expect(find.text('New Broadcast'), findsOneWidget);
      expect(find.text('New Event'), findsOneWidget);
      expect(find.text('Upload Media'), findsOneWidget);
      expect(find.text('Search Roster'), findsOneWidget);
      expect(find.text('Pay My Dues'), findsOneWidget);

      // Sections
      expect(find.text('Recent Broadcasts'), findsOneWidget);
      expect(find.text('Annual General Cultural Festival'), findsOneWidget);
      expect(find.text('Community Clean-up Mobilization'), findsOneWidget);

      expect(find.text('Mobilization & Events'), findsOneWidget);
      expect(find.text('Town Hall Meeting & Press Briefing'), findsOneWidget);
    });

    testWidgets('shows empty state cards when announcements and events are empty', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildProDashboard(
          user: proUser,
          announcements: [],
          events: [],
          docs: [],
          members: [],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No announcements broadcasted yet'), findsOneWidget);
      expect(find.text('Post New Broadcast'), findsOneWidget);
      expect(find.text('No upcoming events scheduled'), findsOneWidget);
    });

    testWidgets('bottom navigation switches destinations and updates view', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildProDashboard(
          user: proUser,
          announcements: testAnnouncements,
          events: testEvents,
          docs: testDocs,
          members: testMembers,
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial tab is Overview
      expect(find.text('Chief Emeka PRO'), findsOneWidget);

      // Switch to Broadcasts
      await tester.tap(find.text('Broadcasts'));
      await tester.pumpAndSettle();

      // Switch to Calendar
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();

      // Switch to Media Hub
      await tester.tap(find.text('Media Hub'));
      await tester.pumpAndSettle();

      // Switch to My Dues
      await tester.tap(find.text('My Dues'));
      await tester.pumpAndSettle();

      // Switch back to Overview
      await tester.tap(find.text('Overview'));
      await tester.pumpAndSettle();
      expect(find.text('Chief Emeka PRO'), findsOneWidget);
    });

    testWidgets('quick actions navigate to correct tabs', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildProDashboard(
          user: proUser,
          announcements: testAnnouncements,
          events: testEvents,
          docs: testDocs,
          members: testMembers,
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'New Broadcast' quick action
      final newBroadcastBtn = find.widgetWithText(QuickActionButton, 'New Broadcast');
      expect(newBroadcastBtn, findsOneWidget);
      await tester.tap(newBroadcastBtn);
      await tester.pumpAndSettle();

      // Return to overview
      await tester.tap(find.text('Overview'));
      await tester.pumpAndSettle();

      // Tap 'New Event' quick action
      final newEventBtn = find.widgetWithText(QuickActionButton, 'New Event');
      expect(newEventBtn, findsOneWidget);
      await tester.tap(newEventBtn);
      await tester.pumpAndSettle();

      // Return to overview
      await tester.tap(find.text('Overview'));
      await tester.pumpAndSettle();

      // Tap 'Pay My Dues' quick action
      final payDuesBtn = find.widgetWithText(QuickActionButton, 'Pay My Dues');
      expect(payDuesBtn, findsOneWidget);
      await tester.tap(payDuesBtn);
      await tester.pumpAndSettle();
    });

    testWidgets('metric cards are clickable and trigger navigation', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildProDashboard(
          user: proUser,
          announcements: testAnnouncements,
          events: testEvents,
          docs: testDocs,
          members: testMembers,
        ),
      );
      await tester.pumpAndSettle();

      // Tap Announcements metric card
      await tester.tap(find.text('Announcements'));
      await tester.pumpAndSettle();

      // Return to overview
      await tester.tap(find.text('Overview'));
      await tester.pumpAndSettle();

      // Tap Calendar Events metric card
      await tester.tap(find.text('Calendar Events'));
      await tester.pumpAndSettle();

      // Return to overview
      await tester.tap(find.text('Overview'));
      await tester.pumpAndSettle();

      // Tap Media & Docs metric card
      await tester.tap(find.text('Media & Docs'));
      await tester.pumpAndSettle();

      // Return to overview
      await tester.tap(find.text('Overview'));
      await tester.pumpAndSettle();

      // Tap Roster Members metric card (opens SearchScreen)
      await tester.tap(find.text('Roster Members'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen), findsOneWidget);
    });
  });
}

