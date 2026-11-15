import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/dashboard/controllers/treasurer_dashboard_provider.dart';
import 'package:cls/features/financial_secretary/controllers/sitting_collection_provider.dart';
import 'package:cls/features/financial_secretary/models/sitting_collection_model.dart';
import 'package:cls/features/financial_secretary/widgets/sitting_readout_sheet.dart';
import 'package:cls/features/financial_secretary/widgets/sitting_tally_card.dart';
import 'package:cls/features/meetings/controllers/meeting_provider.dart';
import 'package:cls/features/meetings/models/meeting_model.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/obligations/controllers/obligation_provider.dart';
import 'package:cls/features/obligations/models/obligation_model.dart';
import 'package:cls/features/payments/models/payment_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final today = DateTime.now();
  final yesterday = today.subtract(const Duration(days: 1));

  final memberA = MemberModel(
    id: 'mem-1',
    organizationId: 'org-1',
    userId: 'user-emeka',
    fullName: 'Chief Emeka Okonkwo',
    email: 'emeka@test.com',
    phoneNumber: '08011111111',
    dateOfBirth: DateTime(1980, 1, 1),
    joinedDate: DateTime(2020, 1, 1),
    branchId: 'branch-aba',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final memberB = MemberModel(
    id: 'mem-2',
    organizationId: 'org-1',
    userId: 'user-ngozi',
    fullName: 'Dr. Ngozi Eze',
    email: 'ngozi@test.com',
    phoneNumber: '08022222222',
    dateOfBirth: DateTime(1985, 5, 5),
    joinedDate: DateTime(2021, 5, 5),
    branchId: 'branch-aba',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final obligationDues = ObligationModel(
    id: 'ob-dues',
    organizationId: 'org-1',
    memberId: 'mem-1',
    levyId: 'levy-dues',
    title: 'Monthly General Dues',
    description: 'Monthly dues collection',
    amount: 15000,
    paidAmount: 15000,
    status: ObligationStatus.paid,
    type: ObligationType.monthlyDue,
    dueDate: today,
    createdAt: today,
  );

  final obligationLevy = ObligationModel(
    id: 'ob-levy',
    organizationId: 'org-1',
    memberId: 'mem-2',
    levyId: 'levy-hall',
    title: 'Civic Hall Renovation Levy',
    description: 'Special renovation project',
    amount: 30000,
    paidAmount: 30000,
    status: ObligationStatus.paid,
    type: ObligationType.specialLevy,
    dueDate: today,
    createdAt: today,
  );

  final paymentTodayCash = PaymentModel(
    id: 'pay-1',
    memberId: 'mem-1',
    memberName: 'Chief Emeka Okonkwo',
    amount: 15000,
    method: PaymentMethod.cash,
    status: PaymentStatus.approved,
    allocations: const [
      PaymentAllocationModel(obligationId: 'ob-dues', amount: 15000),
    ],
    createdAt: DateTime(today.year, today.month, today.day, 13, 30),
  );

  final paymentTodayBank = PaymentModel(
    id: 'pay-2',
    memberId: 'mem-2',
    memberName: 'Dr. Ngozi Eze',
    amount: 30000,
    method: PaymentMethod.bankTransfer,
    status: PaymentStatus.approved,
    allocations: const [
      PaymentAllocationModel(obligationId: 'ob-levy', amount: 30000),
    ],
    createdAt: DateTime(today.year, today.month, today.day, 14, 15),
  );

  final paymentYesterdayCash = PaymentModel(
    id: 'pay-old',
    memberId: 'mem-1',
    memberName: 'Chief Emeka Okonkwo',
    amount: 5000,
    method: PaymentMethod.cash,
    status: PaymentStatus.approved,
    allocations: const [],
    createdAt: DateTime(yesterday.year, yesterday.month, yesterday.day, 10, 0),
  );

  final testMeeting = MeetingModel(
    id: 'meet-today',
    organizationId: 'org-1',
    title: 'November General Sitting',
    venue: 'Civic Centre',
    meetingDate: today,
    createdAt: today,
    updatedAt: today,
    createdBy: 'sec-1',
  );

  group('Sitting Collection Logic & Model Tests', () {
    test('SittingCollectionModel formats secretarial disclosure text properly', () {
      final model = SittingCollectionModel(
        date: today,
        meetingTitle: 'November General Sitting',
        totalCollected: 45000,
        cashCollected: 15000,
        bankCollected: 30000,
        onlineCollected: 0,
        totalTransactions: 2,
        uniqueContributorsCount: 2,
        levyBreakdowns: const [
          SittingLevyBreakdown(title: 'Civic Hall Renovation Levy', amount: 30000, count: 1),
          SittingLevyBreakdown(title: 'Monthly General Dues', amount: 15000, count: 1),
        ],
        contributors: [
          SittingContributor(
            memberId: 'mem-2',
            memberName: 'Dr. Ngozi Eze',
            amount: 30000,
            method: PaymentMethod.bankTransfer,
            time: today,
          ),
          SittingContributor(
            memberId: 'mem-1',
            memberName: 'Chief Emeka Okonkwo',
            amount: 15000,
            method: PaymentMethod.cash,
            time: today,
          ),
        ],
        rawPayments: [paymentTodayCash, paymentTodayBank],
      );

      final text = model.generateMinutesDisclosureText();
      expect(text, contains('FINANCIAL SECRETARY SITTING DISCLOSURE'));
      expect(text, contains('November General Sitting'));
      expect(text, contains('GRAND TOTAL REALIZED: ₦45,000'));
      expect(text, contains('Physical Cash in Hand: ₦15,000'));
      expect(text, contains('Direct Bank Transfers: ₦30,000'));
      expect(text, contains('Civic Hall Renovation Levy: ₦30,000'));
      expect(text, contains('Monthly General Dues: ₦15,000'));
      expect(text, contains('Chief Emeka Okonkwo — ₦15,000 (Cash)'));
      expect(text, contains('Dr. Ngozi Eze — ₦30,000 (Transfer)'));
      expect(text, contains('reconciled for formal handover to the Treasurer'));
    });

    test('sittingCollectionSummaryProvider filters by today sitting date', () async {
      final container = ProviderContainer(
        overrides: [
          allPaymentsStreamProvider.overrideWith(
            (ref) => Stream.value([paymentTodayCash, paymentTodayBank, paymentYesterdayCash]),
          ),
          allObligationsProvider.overrideWith(
            (ref) => Stream.value([obligationDues, obligationLevy]),
          ),
          membersStreamProvider.overrideWith(
            (ref) => Stream.value([memberA, memberB]),
          ),
          meetingsStreamProvider.overrideWith(
            (ref) => Stream.value([testMeeting]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(allPaymentsStreamProvider.future);
      await container.read(allObligationsProvider.future);
      await container.read(membersStreamProvider.future);
      await container.read(meetingsStreamProvider.future);

      final summary = container.read(sittingCollectionSummaryProvider).value!;
      // Today payments: 15,000 (cash) + 30,000 (bank) = 45,000
      // Yesterday's 5,000 should be excluded
      expect(summary.totalCollected, equals(45000.0));
      expect(summary.cashCollected, equals(15000.0));
      expect(summary.bankCollected, equals(30000.0));
      expect(summary.totalTransactions, equals(2));
      expect(summary.uniqueContributorsCount, equals(2));
      expect(summary.meetingTitle, equals('November General Sitting'));
    });

    test('sittingCollectionSummaryProvider filters by custom date when selected', () async {
      final container = ProviderContainer(
        overrides: [
          allPaymentsStreamProvider.overrideWith(
            (ref) => Stream.value([paymentTodayCash, paymentTodayBank, paymentYesterdayCash]),
          ),
          allObligationsProvider.overrideWith(
            (ref) => Stream.value([obligationDues, obligationLevy]),
          ),
          membersStreamProvider.overrideWith(
            (ref) => Stream.value([memberA, memberB]),
          ),
          meetingsStreamProvider.overrideWith(
            (ref) => Stream.value([testMeeting]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(allPaymentsStreamProvider.future);
      await container.read(allObligationsProvider.future);
      await container.read(membersStreamProvider.future);
      await container.read(meetingsStreamProvider.future);

      // Switch to custom date: yesterday
      container.read(sittingScopeModeProvider.notifier).state = SittingScopeMode.customDate;
      container.read(selectedSittingDateProvider.notifier).state = yesterday;

      final summary = container.read(sittingCollectionSummaryProvider).value!;
      // Yesterday payments: only 5,000 cash
      expect(summary.totalCollected, equals(5000.0));
      expect(summary.cashCollected, equals(5000.0));
      expect(summary.bankCollected, equals(0.0));
      expect(summary.totalTransactions, equals(1));
    });
  });

  group('Sitting Widgets Tests', () {
    Widget buildTestWidget({required Widget child}) {
      return ProviderScope(
        overrides: [
          allPaymentsStreamProvider.overrideWith(
            (ref) => Stream.value([paymentTodayCash, paymentTodayBank]),
          ),
          allObligationsProvider.overrideWith(
            (ref) => Stream.value([obligationDues, obligationLevy]),
          ),
          membersStreamProvider.overrideWith(
            (ref) => Stream.value([memberA, memberB]),
          ),
          meetingsStreamProvider.overrideWith(
            (ref) => Stream.value([testMeeting]),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('SittingTallyCard renders sitting totals, cash, bank, and readout trigger',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(child: const SittingTallyCard()));
      await tester.pumpAndSettle();

      expect(find.text("TODAY'S SITTING • November General Sitting"), findsOneWidget);
      expect(find.text('₦45,000'), findsOneWidget);
      expect(find.text('(2 payments)'), findsOneWidget);
      expect(find.text('Cash in Hand: '), findsOneWidget);
      expect(find.text('₦15,000'), findsOneWidget);
      expect(find.text('Bank/Transfer: '), findsOneWidget);
      expect(find.text('₦30,000'), findsOneWidget);
      expect(find.text('Open Readout'), findsOneWidget);
    });

    testWidgets('SittingReadoutSheet displays full breakdown and action buttons',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => SittingReadoutSheet.show(context),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Readout sheet elements
      expect(find.text('Sitting Financial Disclosure'), findsOneWidget);
      expect(find.text('TOTAL REALIZED FOR SITTING'), findsOneWidget);
      expect(find.text('₦45,000'), findsOneWidget);
      expect(find.text('Cash in Hand'), findsOneWidget);
      expect(find.text('₦15,000'), findsWidgets);
      expect(find.text('Bank / Online'), findsOneWidget);
      expect(find.text('₦30,000'), findsWidgets);

      // Levies & Contributors
      expect(find.text('Civic Hall Renovation Levy'), findsOneWidget);
      expect(find.text('Monthly General Dues'), findsOneWidget);
      expect(find.text('Chief Emeka Okonkwo'), findsOneWidget);
      expect(find.text('Dr. Ngozi Eze'), findsOneWidget);

      // Action buttons
      expect(find.text('Copy Summary for Secretary Minutes'), findsOneWidget);
      expect(find.text('Hand Over ₦15,000 Cash to Treasurer'), findsOneWidget);

      // Tap copy button and verify feedback SnackBar
      await tester.tap(find.text('Copy Summary for Secretary Minutes'));
      await tester.pump();
      expect(find.text('Sitting disclosure copied! The General Secretary can paste this into the official minutes.'), findsOneWidget);
    });
  });
}
