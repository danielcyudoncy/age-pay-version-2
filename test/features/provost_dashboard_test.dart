import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/auth/services/auth_service.dart';
import 'package:cls/features/meetings/models/meeting_model.dart';
import 'package:cls/features/provost/controllers/provost_provider.dart';
import 'package:cls/features/provost/models/penalty_waiver_model.dart';
import 'package:cls/features/provost/widgets/active_meeting_decorum_card.dart';
import 'package:cls/features/provost/widgets/penalty_waiver_approval_queue_card.dart';
import 'package:cls/features/provost/views/waiver_audit_ledger_screen.dart';

class _MockAuthService implements AuthService {
  final UserModel? user;
  _MockAuthService(this.user);

  @override
  Future<UserModel?> getCurrentUser() async => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Provost Widgets & Views Tests', () {
    testWidgets('ActiveMeetingDecorumCard renders calm banner when no active meeting', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeMeetingProvider('org-1').overrideWithValue(null),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ActiveMeetingDecorumCard(
                organizationId: 'org-1',
                provostName: 'Chief Provost',
              ),
            ),
          ),
        ),
      );

      expect(find.text('No Active Meeting in Session'), findsOneWidget);
      expect(find.byIcon(Icons.event_available_outlined), findsOneWidget);
    });

    testWidgets('ActiveMeetingDecorumCard renders live decorum session when meeting is active', (tester) async {
      final now = DateTime.now();
      final mockMeeting = MeetingModel(
        id: 'meet-1',
        organizationId: 'org-1',
        title: 'Monthly General Meeting',
        venue: 'Town Hall Auditorium',
        meetingDate: now,
        createdAt: now,
        updatedAt: now,
        createdBy: 'Secretary',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeMeetingProvider('org-1').overrideWithValue(mockMeeting),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ActiveMeetingDecorumCard(
                organizationId: 'org-1',
                provostName: 'Chief Provost',
              ),
            ),
          ),
        ),
      );

      expect(find.text('ACTIVE MEETING DECORUM'), findsOneWidget);
      expect(find.text('Monthly General Meeting'), findsOneWidget);
      expect(find.text('Town Hall Auditorium'), findsOneWidget);
      expect(find.text('Decorum Roll-Call'), findsOneWidget);
      expect(find.text('Sanction Member'), findsOneWidget);
    });

    testWidgets('PenaltyWaiverApprovalQueueCard renders pending waivers for President countersignature', (tester) async {
      final now = DateTime.now();
      final testWaiver = PenaltyWaiverModel(
        id: 'w-1',
        organizationId: 'org-1',
        obligationId: 'o-1',
        memberId: 'm-1',
        memberName: 'Samuel Jackson',
        penaltyTitle: 'Late Coming',
        amount: 1000.0,
        infractionType: PenaltyInfractionType.lateComing,
        reason: 'Presented medical certificate for hospital emergency',
        requestedBy: 'Chief Provost',
        requestedAt: now,
        status: PenaltyWaiverStatus.pendingApproval,
      );

      final mockUser = UserModel(
        uid: 'pres-1',
        organizationId: 'org-1',
        displayName: 'President Adeleke',
        email: 'pres@agepay.org',
        phoneNumber: '+2348011223344',
        role: UserRole.president,
        createdAt: now,
      );

      final mockAuth = _MockAuthService(mockUser);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pendingWaiversStreamProvider('org-1')
                .overrideWith((ref) => Stream.value([testWaiver])),
            authServiceProvider.overrideWith((ref) => mockAuth),
            authProvider.overrideWith((ref) {
              final notifier = AuthNotifier(ref.watch(authServiceProvider));
              notifier.state = AsyncValue.data(mockUser);
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PenaltyWaiverApprovalQueueCard(organizationId: 'org-1'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Penalty Pardon Requests'), findsOneWidget);
      expect(find.textContaining('Samuel Jackson'), findsOneWidget);
      expect(find.text('Late Coming'), findsOneWidget);
      expect(find.text('Countersign Pardon'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
    });

    testWidgets('WaiverAuditLedgerScreen displays approved and rejected records with audit details', (tester) async {
      final now = DateTime.now();
      final approvedWaiver = PenaltyWaiverModel(
        id: 'w-2',
        organizationId: 'org-1',
        obligationId: 'o-2',
        memberId: 'm-2',
        memberName: 'Grace Hopper',
        penaltyTitle: 'Unexcused Absence',
        amount: 2000.0,
        infractionType: PenaltyInfractionType.unexcusedAbsence,
        reason: 'Approved sick leave documentation submitted',
        requestedBy: 'Chief Provost',
        requestedAt: now,
        status: PenaltyWaiverStatus.approved,
        reviewedBy: 'President Adeleke',
        reviewedAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            provostWaiversStreamProvider('org-1')
                .overrideWith((ref) => Stream.value([approvedWaiver])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: WaiverAuditLedgerScreen(organizationId: 'org-1'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Pardon & Waiver Audit Ledger'), findsOneWidget);
      expect(find.text('Grace Hopper'), findsOneWidget);
      expect(find.text('Approved / Pardoned'), findsOneWidget);
      expect(find.textContaining('Reviewed by President Adeleke'), findsOneWidget);
    });
  });
}
