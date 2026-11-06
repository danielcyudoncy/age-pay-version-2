import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/notifications/controllers/notification_provider.dart';
import 'package:cls/features/notifications/models/notification_model.dart';
import 'package:cls/features/notifications/views/notifications_screen.dart';
import 'package:cls/features/secretary/controllers/secretary_dashboard_provider.dart';
import 'package:cls/features/secretary/models/announcement_model.dart';
import 'package:cls/features/secretary/views/member_announcements_screen.dart';

class _SimpleAuthNotifier extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  _SimpleAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNotificationNotifier extends StateNotifier<List<NotificationModel>>
    implements NotificationListNotifier {
  _FakeNotificationNotifier(super.state);

  @override
  Future<void> markAsRead(String id) async {
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(read: true) else n,
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testUser = UserModel(
    uid: 'user_1',
    organizationId: 'org_test',
    email: 'member@agepay.org',
    displayName: 'Brother Emmanuel',
    phoneNumber: '08011223344',
    role: UserRole.member,
    branchId: 'branch_aba',
    branchName: 'Aba Branch',
    createdAt: DateTime(2026, 1, 1),
  );

  testWidgets(
    'Tapping an announcement card opens the announcement detail reader dialog with full contents',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testAnnouncement = AnnouncementModel(
        id: 'ann_test_1',
        organizationId: 'org_test',
        title: 'Monthly General Meeting of Aba Branch',
        body: '1. Opening prayers\n2. Financial review\n3. New member introduction\n4. Closing remarks',
        category: AnnouncementCategory.meeting,
        venue: 'St. Michael Hall, Aba',
        announcementDate: DateTime(2026, 11, 15, 10, 0),
        createdBy: 'provost_1',
        targetAudience: 'branch',
        targetBranchId: 'branch_aba',
        targetBranchName: 'Aba Branch',
        createdAt: DateTime(2026, 11, 4),
        updatedAt: DateTime(2026, 11, 4),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _SimpleAuthNotifier(testUser)),
            organizationIdProvider.overrideWith((ref) => 'org_test'),
            announcementsStreamProvider('org_test').overrideWith(
              (ref) => Stream.value([testAnnouncement]),
            ),
          ],
          child: const MaterialApp(
            home: MemberAnnouncementsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify announcement is displayed in the list
      expect(find.text('Monthly General Meeting of Aba Branch'), findsOneWidget);

      // Tap on the announcement card
      await tester.tap(find.text('Monthly General Meeting of Aba Branch'));
      await tester.pumpAndSettle();

      // Verify the announcement detail dialog opened
      expect(find.byType(Dialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Meeting Agenda & Proceedings:'),
        ),
        findsOneWidget,
      );
      expect(find.text('View Meetings & RSVP'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      // Tap Close button
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Verify dialog is dismissed
      expect(find.byType(Dialog), findsNothing);
    },
  );

  testWidgets(
    'Tapping a meeting notification opens the notification reader modal with full details and action buttons',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testNotification = NotificationModel(
        id: 'notif_1',
        organizationId: 'org_test',
        title: 'Monthly Meeting Notice',
        body: 'The monthly meeting for all members will hold at St. Michael Hall this Sunday at 10:00 AM sharp. Please be seated before the commencement.',
        type: 'meeting',
        payload: 'meeting_123',
        receivedAt: DateTime(2026, 11, 4, 18, 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _SimpleAuthNotifier(testUser)),
            notificationListProvider.overrideWith(
              (ref) => _FakeNotificationNotifier([testNotification]),
            ),
          ],
          child: MaterialApp(
            home: NotificationsScreen(currentUser: testUser),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify notification is rendered in the list
      expect(find.text('Monthly Meeting Notice'), findsOneWidget);

      // Tap the notification
      await tester.tap(find.text('Monthly Meeting Notice'));
      await tester.pumpAndSettle();

      // Verify the Notification detail dialog is displayed with full unabridged body
      expect(find.byType(Dialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('MEETING NOTICE'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.textContaining('St. Michael Hall this Sunday at 10:00 AM sharp'),
        ),
        findsOneWidget,
      );
      expect(find.text('View Meeting & RSVP'), findsOneWidget);

      // Tap Close
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
    },
  );
}
