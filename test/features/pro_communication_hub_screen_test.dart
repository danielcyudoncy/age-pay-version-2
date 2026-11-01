// test/features/pro_communication_hub_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/auth/services/auth_service.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/members/repositories/member_repository.dart';
import 'package:cls/features/pro/controllers/pro_communication_provider.dart';
import 'package:cls/features/pro/services/pro_communication_service.dart';
import 'package:cls/features/pro/views/pro_communication_hub_screen.dart';
import 'package:cls/features/secretary/controllers/secretary_dashboard_provider.dart';
import 'package:cls/features/secretary/repositories/announcement_repository.dart';

class _MockAuthService implements AuthService {
  final UserModel? user;
  _MockAuthService(this.user);

  @override
  Future<UserModel?> getCurrentUser() async => user;

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

class _MockAnnouncementRepo implements AnnouncementRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final proUser = UserModel(
    uid: 'user-pro-compact',
    organizationId: 'org-test',
    email: 'pro@agepay.org',
    displayName: 'Comrade PRO',
    phoneNumber: '+2348011223344',
    role: UserRole.publicRelationsOfficer,
    branchName: 'Lagos Branch',
    createdAt: DateTime(2026, 1, 1),
  );

  final List<MemberModel> testMembers = [
    MemberModel(
      id: 'm-1',
      userId: 'u1',
      fullName: 'Chief John Doe',
      email: 'john@test.com',
      phoneNumber: '+2348012345678',
      dateOfBirth: DateTime(1990, 1, 1),
      joinedDate: DateTime(2026, 1, 1),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    MemberModel(
      id: 'm-2',
      userId: 'u2',
      fullName: 'Barrister Jane Smith',
      email: 'jane@test.com',
      phoneNumber: '+2348087654321',
      dateOfBirth: DateTime(1992, 2, 2),
      joinedDate: DateTime(2026, 1, 1),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  Widget buildTestWidget({CommunicationChannel initialChannel = CommunicationChannel.omnichannel}) {
    final mockAuth = _MockAuthService(proUser);
    final mockMemberRepo = _MockMemberRepo(testMembers);
    final mockAnnouncementRepo = _MockAnnouncementRepo();
    final mockProService = ProCommunicationService(announcementRepo: mockAnnouncementRepo);

    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWith((ref) => mockAuth),
        authProvider.overrideWith((ref) {
          final notifier = AuthNotifier(ref.watch(authServiceProvider));
          notifier.state = AsyncValue.data(proUser);
          return notifier;
        }),
        memberRepositoryProvider.overrideWith((ref) => mockMemberRepo),
        membersStreamProvider.overrideWith((ref) => Stream.value(testMembers)),
        proCommunicationServiceProvider.overrideWithValue(mockProService),
      ],
      child: MaterialApp(
        home: ProCommunicationHubScreen(initialChannel: initialChannel),
      ),
    );
  }

  group('ProCommunicationHubScreen Responsive Layout Tests', () {
    testWidgets('renders on compact 360x800 screen without any RenderFlex overflow', (tester) async {
      // Simulate compact mobile phone (e.g. itel C671L with 360 logical width)
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Ensure no exceptions or overflows were thrown during rendering
      expect(tester.takeException(), isNull);

      // Verify main screen components
      expect(find.text('PRO Communication Hub'), findsOneWidget);
      expect(find.text('Select Dispatch Channel'), findsOneWidget);
      expect(find.text('Omnichannel'), findsOneWidget);
      expect(find.text('All Members'), findsOneWidget);
      expect(find.text('Normal Notice'), findsOneWidget);

      // Verify dropdowns are full-width and not cramped
      expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
    });

    testWidgets('switching between channels does not trigger overflows', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Switch to WhatsApp
      await tester.tap(find.text('WhatsApp'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Pick Member'), findsOneWidget);

      // Switch to SMS Text
      await tester.tap(find.text('SMS Text'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Switch back to In-App Broadcast
      await tester.tap(find.text('In-App Broadcast'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('All Members'), findsOneWidget);
      expect(find.text('Normal Notice'), findsOneWidget);
    });

    testWidgets('filling in announcement form displays preview without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final titleFinder = find.widgetWithText(TextFormField, 'Announcement Title *');
      final bodyFinder = find.widgetWithText(TextFormField, 'Message Body *');
      final scrollableFinder = find.byType(Scrollable).first;

      await tester.scrollUntilVisible(titleFinder, 100, scrollable: scrollableFinder);
      await tester.pumpAndSettle();
      await tester.enterText(titleFinder, 'Emergency Stakeholders Meeting');

      await tester.scrollUntilVisible(bodyFinder, 100, scrollable: scrollableFinder);
      await tester.pumpAndSettle();
      await tester.enterText(
        bodyFinder,
        'All branch executives must attend the urgent consultation slated for Sunday at 4pm prompt.',
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Emergency Stakeholders Meeting'), findsWidgets);
    });
  });
}
