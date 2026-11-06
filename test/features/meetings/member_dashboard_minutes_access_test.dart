import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/auth/services/auth_service.dart';
import 'package:cls/features/dashboard/views/member_dashboard.dart';
import 'package:cls/features/dashboard/controllers/member_dashboard_provider.dart';
import 'package:cls/features/meetings/controllers/meeting_provider.dart';
import 'package:cls/features/meetings/models/meeting_model.dart';
import 'package:cls/features/meetings/views/meeting_list_screen.dart';
import 'package:cls/features/obligations/controllers/obligation_provider.dart';
import 'package:cls/features/obligations/models/obligation_model.dart';
import 'package:cls/features/obligations/repositories/obligation_repository.dart';
import 'package:cls/features/payments/models/payment_model.dart';
import 'package:cls/features/payments/repositories/payment_repository.dart';

class _MockAuthService implements AuthService {
  final UserModel user;
  _MockAuthService(this.user);

  @override
  Future<UserModel?> getCurrentUser() async => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockPaymentRepo implements PaymentRepository {
  @override
  Stream<List<PaymentModel>> getMemberPayments(String memberId) =>
      Stream.value([]);

  @override
  Stream<List<PaymentModel>> getAllPayments() => Stream.value([]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockObligationRepo implements ObligationRepository {
  @override
  Stream<List<ObligationModel>> getAllObligations() => Stream.value([]);

  @override
  Stream<List<ObligationModel>> getMemberObligations(String memberId) =>
      Stream.value([]);

  @override
  Stream<List<ObligationModel>> getMemberActiveObligations(String memberId) =>
      Stream.value([]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testMember = UserModel(
    uid: 'member-001',
    organizationId: 'org-demo',
    email: 'chidi@example.com',
    displayName: 'Chidi Okonkwo',
    phoneNumber: '08098765432',
    role: UserRole.member,
    branchId: 'branch-enugu',
    createdAt: DateTime.now(),
  );

  Widget createTestWidget({
    required List<MeetingModel> meetings,
  }) {
    final mockAuthService = _MockAuthService(testMember);
    final mockPaymentRepo = _MockPaymentRepo();
    final mockObligationRepo = _MockObligationRepo();

    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWith((ref) => mockAuthService),
        authProvider.overrideWith((ref) {
          final notifier = AuthNotifier(ref.watch(authServiceProvider));
          notifier.state = AsyncValue.data(testMember);
          return notifier;
        }),
        paymentRepositoryProvider.overrideWith((ref) => mockPaymentRepo),
        obligationRepositoryProvider.overrideWith((ref) => mockObligationRepo),
        meetingsStreamProvider.overrideWith((ref) => Stream.value(meetings)),
      ],
      child: const MaterialApp(
        home: MemberDashboard(),
      ),
    );
  }

  testWidgets(
    'Renders Meeting Minutes Archive card when no upcoming meetings exist and navigates on tap',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(meetings: []));
      await tester.pumpAndSettle();

      // Card is displayed
      expect(find.text('Meeting Minutes & Archive'), findsOneWidget);
      expect(
        find.text('Browse recorded proceedings, decisions, and files'),
        findsOneWidget,
      );

      // Tap card
      await tester.tap(find.text('Meeting Minutes & Archive'));
      await tester.pumpAndSettle();

      // Verified navigated to MeetingListScreen with Minutes Archive tab selected
      expect(find.byType(MeetingListScreen), findsOneWidget);
      expect(find.text('Past & Minutes'), findsOneWidget);
    },
  );

  testWidgets(
    'Quick Action "Meeting Minutes" button is visible and navigates to MeetingListScreen',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(meetings: []));
      await tester.pumpAndSettle();

      final quickActionFinder = find.text('Meeting Minutes');
      expect(quickActionFinder, findsOneWidget);

      await tester.tap(quickActionFinder);
      await tester.pumpAndSettle();

      expect(find.byType(MeetingListScreen), findsOneWidget);
    },
  );

  testWidgets(
    'When upcoming meeting exists, Minutes Archive footer link is visible and navigates to archive',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final futureMeeting = MeetingModel(
        id: 'meet-future-1',
        organizationId: 'org-demo',
        title: 'Enugu General Branch Monthly Meeting',
        venue: 'Enugu Civic Centre',
        meetingDate: DateTime.now().add(const Duration(days: 5)),
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
        createdBy: 'sec-1',
        scope: 'branch',
        branchId: 'branch-enugu',
        targetAudience: 'all',
      );

      await tester.pumpWidget(createTestWidget(meetings: [futureMeeting]));
      await tester.pumpAndSettle();

      // Meeting card is visible
      expect(find.text('Enugu General Branch Monthly Meeting'), findsOneWidget);

      // Footer link to Minutes Archive is visible
      final minutesArchiveLink = find.text('Minutes Archive');
      expect(minutesArchiveLink, findsOneWidget);

      await tester.tap(minutesArchiveLink);
      await tester.pumpAndSettle();

      // Verified navigated to MeetingListScreen
      expect(find.byType(MeetingListScreen), findsOneWidget);
    },
  );
}
