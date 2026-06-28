import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/data/models/obligation_model.dart';
import 'package:cls/data/repositories/obligation_repository.dart';
import 'package:cls/features/obligations/screens/member_obligations_screen.dart';
import 'package:cls/features/obligations/screens/treasurer_obligations_screen.dart';
import 'package:cls/features/obligations/providers/obligation_provider.dart';

class _MockObligationRepository implements ObligationRepository {
  List<ObligationModel> _obligations = [];

  void setObligations(List<ObligationModel> obligations) {
    _obligations = obligations;
  }

  @override
  Stream<List<ObligationModel>> getAllObligations() {
    return Stream.value(List.unmodifiable(_obligations));
  }

  @override
  Stream<List<ObligationModel>> getMemberObligations(String memberId) {
    return Stream.value(
      _obligations.where((o) => o.memberId == memberId).toList(),
    );
  }

  @override
  Stream<List<ObligationModel>> getMemberActiveObligations(String memberId) {
    return Stream.value(
      _obligations
          .where(
            (o) =>
                o.memberId == memberId &&
                (o.status == ObligationStatus.unpaid ||
                    o.status == ObligationStatus.partial),
          )
          .toList(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDate = DateTime(2026, 6, 30);

  final testObligations = [
    ObligationModel(
      id: 'obl1',
      memberId: 'member1',
      levyId: 'levy1',
      type: ObligationType.monthlyDue,
      title: 'June Monthly Due',
      description: 'Monthly contribution for June',
      amount: 5000,
      paidAmount: 0,
      outstandingBalance: 5000,
      status: ObligationStatus.unpaid,
      dueDate: testDate,
      createdAt: DateTime.now(),
    ),
    ObligationModel(
      id: 'obl2',
      memberId: 'member1',
      levyId: 'levy2',
      type: ObligationType.specialLevy,
      title: 'Project Fund',
      description: 'Community hall project contribution',
      amount: 10000,
      paidAmount: 5000,
      outstandingBalance: 5000,
      status: ObligationStatus.partial,
      dueDate: testDate.add(const Duration(days: 15)),
      createdAt: DateTime.now(),
    ),
    ObligationModel(
      id: 'obl3',
      memberId: 'member1',
      levyId: 'levy3',
      type: ObligationType.emergencyContribution,
      title: 'Emergency Relief',
      description: 'Flood relief fund',
      amount: 3000,
      paidAmount: 3000,
      outstandingBalance: 0,
      status: ObligationStatus.paid,
      dueDate: testDate.add(const Duration(days: -5)),
      createdAt: DateTime.now(),
      settledAt: DateTime.now(),
    ),
    ObligationModel(
      id: 'obl4',
      memberId: 'member2',
      levyId: 'levy1',
      type: ObligationType.monthlyDue,
      title: 'June Monthly Due',
      description: 'Monthly contribution for June',
      amount: 5000,
      paidAmount: 0,
      outstandingBalance: 5000,
      status: ObligationStatus.unpaid,
      dueDate: testDate,
      createdAt: DateTime.now(),
    ),
  ];

  group('MemberObligationsScreen', () {
    Widget buildScreen(List<ObligationModel> obligations) {
      final mockRepo = _MockObligationRepository();
      mockRepo.setObligations(obligations);

      return ProviderScope(
        overrides: [
          obligationRepositoryProvider.overrideWith((ref) => mockRepo),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 1200)),
            child: MemberObligationsScreen(memberId: 'member1'),
          ),
        ),
      );
    }

    testWidgets('renders title and empty state', (tester) async {
      await tester.pumpWidget(buildScreen([]));
      await tester.pumpAndSettle();

      expect(find.text('My Obligations'), findsOneWidget);
      expect(find.text('No obligations found'), findsOneWidget);
      expect(find.text('You are all caught up!'), findsOneWidget);
    });

    testWidgets('displays obligation with unpaid status chip', (tester) async {
      final singleObligation = [testObligations[0]];
      await tester.pumpWidget(buildScreen(singleObligation));
      await tester.pumpAndSettle();

      expect(find.text('June Monthly Due'), findsOneWidget);
      expect(find.textContaining('Monthly contribution'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Unpaid'), findsOneWidget);
    });

    testWidgets('displays obligation with partial status chip', (tester) async {
      final singleObligation = [testObligations[1]];
      await tester.pumpWidget(buildScreen(singleObligation));
      await tester.pumpAndSettle();

      expect(find.text('Project Fund'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Partial'), findsOneWidget);
      expect(find.text('50% paid'), findsOneWidget);
    });

    testWidgets('shows obligation with paid status chip', (tester) async {
      final singleObligation = [testObligations[2]];
      await tester.pumpWidget(buildScreen(singleObligation));
      await tester.pumpAndSettle();

      expect(find.text('Emergency Relief'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Paid'), findsOneWidget);
      expect(find.text('100% paid'), findsOneWidget);
    });

    testWidgets('shows summary card for multiple obligations', (tester) async {
      final member1Obligations = testObligations
          .where((o) => o.memberId == 'member1')
          .toList();
      await tester.pumpWidget(buildScreen(member1Obligations));
      await tester.pumpAndSettle();

      expect(find.text('Summary'), findsOneWidget);
      expect(find.textContaining('Total Outstanding'), findsOneWidget);
    });

    testWidgets('shows amounts in Naira format', (tester) async {
      await tester.pumpWidget(buildScreen([testObligations[0]]));
      await tester.pumpAndSettle();

      expect(find.textContaining('₦5,000'), findsWidgets);
    });

    testWidgets('progress indicator is visible', (tester) async {
      await tester.pumpWidget(buildScreen([testObligations[1]]));
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('TreasurerObligationsScreen', () {
    Widget buildScreen(List<ObligationModel> obligations) {
      final mockRepo = _MockObligationRepository();
      mockRepo.setObligations(obligations);

      return ProviderScope(
        overrides: [
          obligationRepositoryProvider.overrideWith((ref) => mockRepo),
        ],
        child: MaterialApp(home: TreasurerObligationsScreen()),
      );
    }

    testWidgets('renders title and search field', (tester) async {
      await tester.pumpWidget(buildScreen(testObligations));
      await tester.pumpAndSettle();

      expect(find.text('All Obligations'), findsOneWidget);
      expect(find.byIcon(Icons.filter_list), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('displays all obligations for treasurer', (tester) async {
      await tester.pumpWidget(buildScreen(testObligations));
      await tester.pumpAndSettle();

      expect(find.text('June Monthly Due'), findsOneWidget);
      expect(find.text('Project Fund'), findsOneWidget);
      expect(find.text('Emergency Relief'), findsOneWidget);
    });

    testWidgets('filters obligations by status', (tester) async {
      await tester.pumpWidget(buildScreen(testObligations));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();

      expect(find.text('Filter by Status'), findsOneWidget);

      await tester.tap(find.text('Filter by Status'));
      await tester.pump();

      final paidChoice = find.descendant(
        of: find.byType(SafeArea),
        matching: find.widgetWithText(ChoiceChip, 'Paid'),
      );
      await tester.tap(paidChoice);
      await tester.pumpAndSettle();

      expect(find.text('Emergency Relief'), findsOneWidget);
      expect(find.text('Project Fund'), findsNothing);
    });

    testWidgets('search filters by title', (tester) async {
      await tester.pumpWidget(buildScreen(testObligations));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Project');
      await tester.pumpAndSettle();

      expect(find.text('Project Fund'), findsOneWidget);
      expect(find.text('Emergency Relief'), findsNothing);
    });

    testWidgets('shows action buttons for unpaid obligations', (tester) async {
      await tester.pumpWidget(buildScreen([testObligations[0]]));
      await tester.pumpAndSettle();

      expect(find.text('Record Payment'), findsOneWidget);
      expect(find.text('Adjust'), findsOneWidget);
    });

    testWidgets('hides action buttons for paid obligations', (tester) async {
      await tester.pumpWidget(buildScreen([testObligations[2]]));
      await tester.pumpAndSettle();

      expect(find.text('Record Payment'), findsNothing);
      expect(find.text('Adjust'), findsNothing);
    });
  });
}
