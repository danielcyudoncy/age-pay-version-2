import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/levies/repositories/levy_repository.dart';
import 'package:cls/features/obligations/repositories/obligation_repository.dart';
import 'package:cls/features/levies/views/create_levy_screen.dart';
import 'package:cls/features/levies/controllers/levy_provider.dart';

class _MockLevyRepository implements LevyRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockObligationRepository implements ObligationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CreateLevyScreen', () {
    const testCreatorId = 'treasurer1';
    const testMemberIds = ['member1', 'member2', 'member3'];

    Widget buildScreen() {
      final mockLevyRepo = _MockLevyRepository();
      final mockObligationRepo = _MockObligationRepository();

      return ProviderScope(
        overrides: [
          levyRepositoryProvider.overrideWith((ref) => mockLevyRepo),
          obligationRepositoryProvider.overrideWith(
            (ref) => mockObligationRepo,
          ),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 1200)),
            child: CreateLevyScreen(
              creatorId: testCreatorId,
              memberIds: testMemberIds,
            ),
          ),
        ),
      );
    }

    testWidgets('renders title and form fields', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Create New Levy'), findsOneWidget);
      expect(find.text('Levy Details'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(4));
    });

    testWidgets('shows member count info', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining('3 member(s) will receive'), findsOneWidget);
    });

    testWidgets('validates empty title on submit', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      final submitButton = find.widgetWithText(
        FilledButton,
        'Create Levy & Generate Obligations',
      );
      expect(submitButton, findsOneWidget);
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Title is required'), findsOneWidget);
    });

    testWidgets('validates empty amount on submit', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      final submitButton = find.widgetWithText(
        FilledButton,
        'Create Levy & Generate Obligations',
      );
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Amount is required'), findsOneWidget);
    });

    testWidgets('displays dropdown with obligation types', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(
        find.byType(DropdownButtonFormField<ObligationType>),
        findsOneWidget,
      );
      expect(find.text('Monthly Due'), findsOneWidget);
    });
  });

  group('LevyCreationState', () {
    test('copyWith preserves values', () {
      const state = LevyCreationState(
        isLoading: true,
        error: 'test error',
        isSuccess: false,
      );

      final copy = state.copyWith(isSuccess: true, createdLevyId: 'levy123');

      expect(copy.isLoading, true);
      expect(copy.error, 'test error');
      expect(copy.isSuccess, true);
      expect(copy.createdLevyId, 'levy123');
    });

    test('copyWith can override error', () {
      const state = LevyCreationState(error: 'old error');

      final copy = state.copyWith(error: 'new error');

      expect(copy.error, 'new error');
    });

    test('default state has expected values', () {
      const state = LevyCreationState();

      expect(state.isLoading, false);
      expect(state.error, isNull);
      expect(state.isSuccess, false);
      expect(state.createdLevyId, isNull);
    });
  });
}
