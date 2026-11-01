// test/features/announcement_overflow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/auth/services/auth_service.dart';
import 'package:cls/features/secretary/controllers/secretary_dashboard_provider.dart';
import 'package:cls/features/secretary/models/announcement_model.dart';
import 'package:cls/features/secretary/repositories/announcement_repository.dart';
import 'package:cls/features/secretary/views/announcements_screen.dart';
import 'package:cls/features/secretary/views/member_announcements_screen.dart';

class _MockAuthService implements AuthService {
  final UserModel? user;
  _MockAuthService(this.user);

  @override
  Future<UserModel?> getCurrentUser() async => user;

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
  Stream<List<AnnouncementModel>> getAnnouncementsForDate(String organizationId, DateTime date) =>
      Stream.value(announcements);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final presidentUser = UserModel(
    uid: 'user_pres_1',
    organizationId: 'org_test_1',
    email: 'president@test.com',
    displayName: 'Chief President',
    phoneNumber: '08012345678',
    role: UserRole.president,
    branchId: 'branch_lagos',
    branchName: 'Lagos Island Branch',
    createdAt: DateTime.now(),
  );

  final testAnnouncements = [
    AnnouncementModel(
      id: 'ann_overflow_1',
      organizationId: 'org_test_1',
      title: 'Urgent Stakeholders Security & Financial Briefing for the Year',
      body: 'All delegates must assemble at the state headquarters for crucial budget ratification.',
      category: AnnouncementCategory.emergency,
      targetAudience: 'branchExecutives',
      targetBranchId: 'branch_lagos',
      targetBranchName: 'Lagos Island Branch',
      isPinned: true,
      announcementDate: DateTime.now(),
      createdBy: 'user_pres_1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    AnnouncementModel(
      id: 'ann_overflow_2',
      organizationId: 'org_test_1',
      title: 'Annual General Assembly Roll Call & Convention Preparation',
      body: 'Detailed instructions on venue access and branch representation guidelines.',
      category: AnnouncementCategory.general,
      targetAudience: 'allExecutives',
      isPinned: false,
      announcementDate: DateTime.now(),
      createdBy: 'user_pres_1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  Widget buildScreen(Widget child) {
    final mockAuth = _MockAuthService(presidentUser);
    final mockRepo = _MockAnnouncementRepo(testAnnouncements);

    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWith((ref) => mockAuth),
        authProvider.overrideWith((ref) {
          final notifier = AuthNotifier(ref.watch(authServiceProvider));
          notifier.state = AsyncValue.data(presidentUser);
          return notifier;
        }),
        organizationIdProvider.overrideWith((ref) => 'org_test_1'),
        announcementsStreamProvider('org_test_1').overrideWith((ref) => Stream.value(testAnnouncements)),
        announcementRepositoryProvider.overrideWith((ref) => mockRepo),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('Announcements Responsive Layout Overflow Tests', () {
    testWidgets('MemberAnnouncementsScreen renders without overflow on 360x800 compact device', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildScreen(const MemberAnnouncementsScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Announcements'), findsOneWidget);
      expect(find.text('EMERGENCY'), findsOneWidget);
    });

    testWidgets('AnnouncementsScreen renders without overflow on 360x800 compact device', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildScreen(const AnnouncementsScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Announcements'), findsOneWidget);
      expect(find.text('All Announcements'), findsOneWidget);
    });
  });
}
