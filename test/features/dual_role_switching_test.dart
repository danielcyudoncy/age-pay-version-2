// test/features/dual_role_switching_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/auth/services/auth_service.dart';
import 'package:cls/features/dashboard/views/home_router.dart';
import 'package:cls/features/dashboard/views/pro_dashboard.dart';
import 'package:cls/features/provost/views/provost_dashboard.dart';
import 'package:cls/features/national/controllers/national_provider.dart';
import 'package:cls/features/dashboard/widgets/dual_role_switcher_card.dart';
import 'package:cls/features/admin/models/organization_model.dart';
import 'package:cls/features/admin/controllers/admin_provider.dart';
import 'package:cls/features/secretary/controllers/calendar_event_provider.dart';
import 'package:cls/features/secretary/controllers/secretary_dashboard_provider.dart';
import 'package:cls/features/dashboard/controllers/member_dashboard_provider.dart';
import 'package:cls/features/obligations/controllers/obligation_provider.dart';
import 'package:cls/features/pro/controllers/pro_communication_provider.dart';
import 'package:cls/features/pro/services/pro_communication_service.dart';
import 'package:cls/features/secretary/models/announcement_model.dart';
import 'package:cls/features/secretary/models/calendar_event_model.dart';
import 'package:cls/features/secretary/models/document_model.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/secretary/repositories/announcement_repository.dart';
import 'package:cls/features/secretary/repositories/calendar_event_repository.dart';
import 'package:cls/features/secretary/repositories/document_repository.dart';
import 'package:cls/features/members/repositories/member_repository.dart';
import 'package:cls/features/payments/repositories/payment_repository.dart';
import 'package:cls/features/obligations/repositories/obligation_repository.dart';
import 'package:cls/features/payments/models/payment_model.dart';
import 'package:cls/features/obligations/models/obligation_model.dart';
import 'package:cls/features/notifications/controllers/notification_provider.dart';
import 'package:cls/features/provost/controllers/provost_provider.dart';

class _MockAuthService implements AuthService {
  final UserModel? user;
  _MockAuthService(this.user);

  @override
  Future<UserModel?> getCurrentUser() async => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockAnnouncementRepo implements AnnouncementRepository {
  @override
  Stream<List<AnnouncementModel>> getAnnouncements(String organizationId) =>
      Stream.value([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockCalendarRepo implements CalendarEventRepository {
  @override
  Stream<List<CalendarEventModel>> getEvents(String organizationId) =>
      Stream.value([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockDocumentRepo implements DocumentRepository {
  @override
  Stream<List<DocumentModel>> getDocuments(String organizationId) =>
      Stream.value([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockMemberRepo implements MemberRepository {
  @override
  Stream<List<MemberModel>> getMembers() => Stream.value([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockPaymentRepo implements PaymentRepository {
  @override
  Stream<List<PaymentModel>> getMemberPayments(String memberId) => Stream.value([]);
  @override
  Stream<List<PaymentModel>> getAllPayments() => Stream.value([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockObligationRepo implements ObligationRepository {
  @override
  Stream<List<ObligationModel>> getMemberActiveObligations(String memberId) => Stream.value([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const orgId = 'org-dual-role-test';
  final now = DateTime.now();

  final dualRoleUser = UserModel(
    uid: 'user-dual-1',
    organizationId: orgId,
    email: 'dual@agepay.org',
    displayName: 'Chief Emeka',
    phoneNumber: '+2348011223344',
    role: UserRole.publicRelationsOfficer, // Branch role: PRO
    branchId: 'branch-lagos',
    branchName: 'Lagos Branch',
    nationalRole: UserRole.provost, // National role: Provost
    isEnrolledInNational: true,
    createdAt: now,
  );

  final testOrg = OrganizationModel(
    id: orgId,
    name: 'Umuahia Age Grade Association',
    slug: 'umuahia-age-grade',
    openForJoin: true,
    verificationStatus: 'verified',
    createdAt: now,
    updatedAt: now,
  );

  Widget createTestApp({
    ExecutiveScope initialScope = ExecutiveScope.branch,
  }) {
    final mockAuth = _MockAuthService(dualRoleUser);
    final mockAnnouncementRepo = _MockAnnouncementRepo();

    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWith((ref) => mockAuth),
        authProvider.overrideWith((ref) {
          final notifier = AuthNotifier(ref.watch(authServiceProvider));
          notifier.state = AsyncValue.data(dualRoleUser);
          return notifier;
        }),
        currentOrganizationProvider.overrideWith((ref) => Stream.value(testOrg)),
        activeExecutiveScopeProvider.overrideWith((ref) => initialScope),
        announcementRepositoryProvider.overrideWith((ref) => mockAnnouncementRepo),
        calendarEventRepositoryProvider.overrideWith((ref) => _MockCalendarRepo()),
        documentRepositoryProvider.overrideWith((ref) => _MockDocumentRepo()),
        memberRepositoryProvider.overrideWith((ref) => _MockMemberRepo()),
        paymentRepositoryProvider.overrideWith((ref) => _MockPaymentRepo()),
        obligationRepositoryProvider.overrideWith((ref) => _MockObligationRepo()),
        unreadCountProvider.overrideWith((ref) => 0),
        activeMeetingProvider(orgId).overrideWithValue(null),
        provostPenaltiesStreamProvider(orgId).overrideWith((ref) => Stream.value([])),
        provostWaiversStreamProvider(orgId).overrideWith((ref) => Stream.value([])),
        pendingWaiversStreamProvider(orgId).overrideWith((ref) => Stream.value([])),
        proCommunicationServiceProvider.overrideWith((ref) => ProCommunicationService(
          announcementRepo: mockAnnouncementRepo,
        )),
      ],
      child: const MaterialApp(
        home: HomeRouter(),
      ),
    );
  }

  group('Dual Role (Branch PRO + National Provost) Switching Tests', () {
    testWidgets('initial branch scope routes to ProDashboard and displays DualRoleSwitcherCard', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(initialScope: ExecutiveScope.branch));
      await tester.pumpAndSettle();

      // Should be on ProDashboard
      expect(find.byType(ProDashboard), findsOneWidget);
      expect(find.text('Public Relations Officer'), findsOneWidget);

      // Should display DualRoleSwitcherCard for national promotion
      expect(find.byType(DualRoleSwitcherCard), findsOneWidget);
      expect(find.text('Viewing: Lagos Branch'), findsOneWidget);
      expect(
        find.text('You also hold office as Provost in the National Body.'),
        findsOneWidget,
      );
      expect(find.text('Go to National'), findsOneWidget);
    });

    testWidgets('national scope routes to ProvostDashboard and displays DualRoleSwitcherCard with branch return button', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(initialScope: ExecutiveScope.national));
      await tester.pumpAndSettle();

      // Should be on ProvostDashboard
      expect(find.byType(ProvostDashboard), findsOneWidget);
      expect(find.text('Provost Disciplinary Officer'), findsOneWidget);

      // Should display DualRoleSwitcherCard with branch info
      expect(find.byType(DualRoleSwitcherCard), findsOneWidget);
      expect(find.text('Viewing: National Body'), findsOneWidget);
      expect(
        find.text('You also hold office as Public Relations Officer in Lagos Branch.'),
        findsOneWidget,
      );
      expect(find.text('Go to Lagos Branch'), findsOneWidget);
    });

    testWidgets('tapping Go to National switches to ProvostDashboard and tapping Go to Lagos Branch switches back to ProDashboard', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(initialScope: ExecutiveScope.branch));
      await tester.pumpAndSettle();

      // 1. Initially on ProDashboard (Branch view)
      expect(find.byType(ProDashboard), findsOneWidget);

      // 2. Tap "Go to National"
      await tester.tap(find.text('Go to National'));
      await tester.pumpAndSettle();

      // 3. Now on ProvostDashboard (National view)
      expect(find.byType(ProvostDashboard), findsOneWidget);
      expect(find.text('Go to Lagos Branch'), findsOneWidget);

      // 4. Tap "Go to Lagos Branch"
      await tester.tap(find.text('Go to Lagos Branch'));
      await tester.pumpAndSettle();

      // 5. Back on ProDashboard (Branch view)
      expect(find.byType(ProDashboard), findsOneWidget);
      expect(find.text('Go to National'), findsOneWidget);
    });
  });
}
