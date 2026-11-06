import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/secretary/controllers/announcement_provider.dart'
    show announcementControllerProvider, AnnouncementController;
import 'package:cls/features/secretary/controllers/secretary_dashboard_provider.dart';
import 'package:cls/features/secretary/models/announcement_model.dart';
import 'package:cls/features/secretary/repositories/announcement_repository.dart';
import 'package:cls/features/secretary/views/announcements_screen.dart';

class _FakeAnnouncementRepository implements AnnouncementRepository {
  AnnouncementModel? lastCreated;
  AnnouncementModel? lastUpdated;
  List<AnnouncementModel> announcements = [];

  _FakeAnnouncementRepository({this.announcements = const []});

  @override
  Stream<List<AnnouncementModel>> getAnnouncements(String organizationId) =>
      Stream.value(announcements);

  @override
  Stream<List<AnnouncementModel>> getAnnouncementsForDate(String organizationId, DateTime date) =>
      Stream.value(announcements);

  @override
  Future<String> createAnnouncement(AnnouncementModel announcement) async {
    lastCreated = announcement;
    return 'ann_new_1';
  }

  @override
  Future<void> updateAnnouncement(AnnouncementModel announcement) async {
    lastUpdated = announcement;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SimpleAuthNotifier extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  _SimpleAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final secUser = UserModel(
    uid: 'sec_1',
    organizationId: 'org_test',
    email: 'sec@agepay.org',
    displayName: 'Chief Secretary',
    phoneNumber: '08012345678',
    role: UserRole.secretary,
    branchId: 'branch_aba',
    branchName: 'Aba Branch',
    createdAt: DateTime(2026, 1, 1),
  );

  testWidgets(
    'Announcement pop-up has columns for Meeting Venue, Meeting Time, and space for Meeting Agenda',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeRepo = _FakeAnnouncementRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _SimpleAuthNotifier(secUser)),
            announcementRepositoryProvider.overrideWithValue(fakeRepo),
            announcementControllerProvider.overrideWithValue(
              AnnouncementController(fakeRepo),
            ),
            announcementsStreamProvider('org_test').overrideWith(
              (ref) => Stream.value([]),
            ),
          ],
          child: const MaterialApp(
            home: AnnouncementsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Add button to open the Announcement pop-up
      final addButton = find.widgetWithText(TextButton, 'Add');
      expect(addButton, findsOneWidget);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // Verify the pop-up dialog is open
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('New Announcement'), findsOneWidget);

      // 1. Verify Venue column is present
      expect(find.text('Meeting Venue *'), findsOneWidget);

      // 2. Verify Time and Date columns are present
      expect(find.text('Meeting Date *'), findsOneWidget);
      expect(find.text('Meeting Time *'), findsOneWidget);

      // 3. Verify space for Agenda (body of the meeting) is present
      expect(find.text('Meeting Agenda & Proceedings (Body) *'), findsOneWidget);

      // Fill in Title, Venue, and Agenda
      await tester.enterText(
        find.widgetWithText(TextField, 'Meeting Title *'),
        'Annual General Assembly & Budget Review',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Meeting Venue *'),
        'Aba Town Hall Civic Center',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Meeting Agenda & Proceedings (Body) *'),
        '1. Opening Prayer\n2. Adoption of 2026 Minutes\n3. Fiscal Budget\n4. A.O.B',
      );
      await tester.pumpAndSettle();

      // Tap Create
      final createButton = find.widgetWithText(ElevatedButton, 'Create');
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      // Verify repository received the new announcement with Venue, Time, and Agenda
      expect(fakeRepo.lastCreated, isNotNull);
      final created = fakeRepo.lastCreated!;
      expect(created.title, 'Annual General Assembly & Budget Review');
      expect(created.venue, 'Aba Town Hall Civic Center');
      expect(created.category, AnnouncementCategory.meeting);
      expect(
        created.body,
        '1. Opening Prayer\n2. Adoption of 2026 Minutes\n3. Fiscal Budget\n4. A.O.B',
      );
      expect(created.announcementDate, isNotNull);
      // Verify time has hour and minute set
      expect(created.formattedTime, isNotNull);
    },
  );

  testWidgets(
    'Announcement card renders Meeting Venue, Time, and Agenda header',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final meetingAnnouncement = AnnouncementModel(
        id: 'ann_m1',
        organizationId: 'org_test',
        title: 'Emergency General Assembly',
        body: '1. Security Report\n2. Road Levy Assessment\n3. Resolutions',
        category: AnnouncementCategory.meeting,
        venue: 'Aba Civic Hall',
        announcementDate: DateTime(2026, 6, 20, 10, 30),
        targetAudience: 'branch',
        targetBranchId: 'branch_aba',
        targetBranchName: 'Aba Branch',
        createdBy: 'sec_1',
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      );

      final fakeRepo = _FakeAnnouncementRepository(
        announcements: [meetingAnnouncement],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _SimpleAuthNotifier(secUser)),
            announcementRepositoryProvider.overrideWithValue(fakeRepo),
            announcementsStreamProvider('org_test').overrideWith(
              (ref) => Stream.value([meetingAnnouncement]),
            ),
          ],
          child: const MaterialApp(
            home: AnnouncementsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Card displays the Title
      expect(find.text('Emergency General Assembly'), findsWidgets);

      // Card displays Venue with location pin
      expect(find.text('Aba Civic Hall'), findsWidgets);

      // Card displays Time alongside date
      expect(find.textContaining('10:30 AM'), findsWidgets);

      // Card displays Meeting Agenda header
      expect(find.text('Meeting Agenda & Proceedings:'), findsWidgets);
    },
  );

  testWidgets(
    'Edit Announcement pop-up pre-populates Venue, Time, and Agenda, and saves modifications',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final existing = AnnouncementModel(
        id: 'ann_edit_1',
        organizationId: 'org_test',
        title: 'Q3 Executive Review',
        body: '1. Opening remarks\n2. Q3 Financials\n3. Next Steps',
        category: AnnouncementCategory.meeting,
        venue: 'Main Executive Boardroom',
        announcementDate: DateTime(2026, 9, 15, 14, 0),
        targetAudience: 'branch',
        targetBranchId: 'branch_aba',
        targetBranchName: 'Aba Branch',
        createdBy: 'sec_1',
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      );

      final fakeRepo = _FakeAnnouncementRepository(
        announcements: [existing],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _SimpleAuthNotifier(secUser)),
            announcementRepositoryProvider.overrideWithValue(fakeRepo),
            announcementControllerProvider.overrideWithValue(
              AnnouncementController(fakeRepo),
            ),
            announcementsStreamProvider('org_test').overrideWith(
              (ref) => Stream.value([existing]),
            ),
          ],
          child: const MaterialApp(
            home: AnnouncementsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Edit button on announcement card
      final editButton = find.byTooltip('Edit announcement').first;
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      // Verify the edit dialog opened with existing values
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Edit Announcement'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Main Executive Boardroom'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('1. Opening remarks\n2. Q3 Financials\n3. Next Steps'),
        ),
        findsOneWidget,
      );
      expect(find.text('Meeting Time *'), findsOneWidget);

      // Modify venue and agenda
      await tester.enterText(
        find.widgetWithText(TextField, 'Meeting Venue *'),
        'Updated Civic Conference Center',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Meeting Agenda & Proceedings (Body) *'),
        '1. Welcome\n2. Revised Agenda\n3. Adjournment',
      );
      await tester.pumpAndSettle();

      // Tap Save
      final saveButton = find.widgetWithText(ElevatedButton, 'Save');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify repository updated
      expect(fakeRepo.lastUpdated, isNotNull);
      final updated = fakeRepo.lastUpdated!;
      expect(updated.venue, 'Updated Civic Conference Center');
      expect(updated.body, '1. Welcome\n2. Revised Agenda\n3. Adjournment');
    },
  );
}
