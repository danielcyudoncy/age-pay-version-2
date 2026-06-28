import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/data/models/expense_model.dart';
import 'package:cls/data/repositories/expense_repository.dart';
import 'package:cls/features/expenses/providers/expense_provider.dart';
import 'package:cls/features/expenses/screens/expense_list_screen.dart';
import 'package:cls/features/expenses/screens/expense_form_screen.dart';

class _MockExpenseRepo implements ExpenseRepository {
  bool createCalled = false;
  bool updateCalled = false;
  ExpenseModel? lastCreated;
  ExpenseModel? lastUpdated;

  @override
  Future<String> createExpense(ExpenseModel expense) async {
    createCalled = true;
    lastCreated = expense;
    return 'new-expense-id';
  }

  @override
  Future<void> updateExpense(ExpenseModel expense) async {
    updateCalled = true;
    lastUpdated = expense;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testExpenses = [
    ExpenseModel(
      id: 'exp1',
      title: 'Office Rent',
      description: 'Monthly office rent payment',
      amount: 50000,
      category: ExpenseCategory.administration,
      receiptUrl: 'https://example.com/receipt1.pdf',
      createdBy: 'treasurer1',
      expenseDate: DateTime(2026, 6, 1),
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
    ),
    ExpenseModel(
      id: 'exp2',
      title: 'Community Project',
      description: 'Building materials for community hall',
      amount: 250000,
      category: ExpenseCategory.projects,
      receiptUrl: null,
      createdBy: 'treasurer1',
      expenseDate: DateTime(2026, 6, 10),
      createdAt: DateTime(2026, 6, 10),
      updatedAt: DateTime(2026, 6, 10),
    ),
    ExpenseModel(
      id: 'exp3',
      title: 'Welfare Package',
      description: 'Food items for elderly members',
      amount: 75000,
      category: ExpenseCategory.welfare,
      receiptUrl: 'https://example.com/receipt3.pdf',
      createdBy: 'treasurer1',
      expenseDate: DateTime(2026, 6, 15),
      createdAt: DateTime(2026, 6, 15),
      updatedAt: DateTime(2026, 6, 15),
    ),
  ];

  group('ExpenseListScreen', () {
    Widget buildScreen({
      List<ExpenseModel> expenses = const [],
      Object? error,
      bool loading = false,
    }) {
      return ProviderScope(
        overrides: [
          expensesStreamProvider.overrideWith((ref) {
            if (error != null) {
              return Stream.error(error);
            }
            return Stream.value(expenses);
          }),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 1200)),
            child: ExpenseListScreen(currentUserId: 'treasurer1'),
          ),
        ),
      );
    }

    testWidgets('renders title and total summary', (tester) async {
      await tester.pumpWidget(buildScreen(expenses: testExpenses));
      await tester.pumpAndSettle();

      expect(find.text('Expenses'), findsOneWidget);
      expect(find.textContaining('Total:'), findsOneWidget);
      expect(find.textContaining('₦'), findsWidgets);
    });

    testWidgets('displays expense cards with title, amount, category chip', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen(expenses: testExpenses));
      await tester.pumpAndSettle();

      expect(find.text('Office Rent'), findsOneWidget);
      expect(find.text('Community Project'), findsOneWidget);
      expect(find.text('Welfare Package'), findsOneWidget);
      expect(find.textContaining('₦50,000'), findsOneWidget);
      expect(find.textContaining('₦250,000'), findsOneWidget);
      expect(find.textContaining('₦75,000'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Administration'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Projects'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Welfare'), findsOneWidget);
    });

    testWidgets('shows receipt icon only when receiptUrl exists', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen(expenses: testExpenses));
      await tester.pumpAndSettle();

      // exp1 and exp3 have receiptUrl, exp2 does not
      // There should be exactly 2 receipt icons
      expect(find.byIcon(Icons.receipt), findsNWidgets(2));
    });

    testWidgets('filter chips show and filter by category', (tester) async {
      await tester.pumpWidget(buildScreen(expenses: testExpenses));
      await tester.pumpAndSettle();

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Welfare'), findsWidgets);
      expect(find.text('Projects'), findsWidgets);
      expect(find.text('Events'), findsWidgets);
      expect(find.text('Administration'), findsWidgets);
      expect(find.text('Miscellaneous'), findsWidgets);

      // Tap Projects filter
      await tester.tap(find.widgetWithText(ChoiceChip, 'Projects'));
      await tester.pumpAndSettle();

      expect(find.text('Community Project'), findsOneWidget);
      expect(find.text('Office Rent'), findsNothing);
      expect(find.text('Welfare Package'), findsNothing);

      // Tap Welfare filter
      await tester.tap(find.widgetWithText(ChoiceChip, 'Welfare'));
      await tester.pumpAndSettle();

      expect(find.text('Welfare Package'), findsOneWidget);
      expect(find.text('Community Project'), findsNothing);
    });

    testWidgets('FAB triggers navigation', (tester) async {
      await tester.pumpWidget(buildScreen(expenses: testExpenses));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Add Expense'), findsOneWidget);
    });

    testWidgets('empty state shows icon and message', (tester) async {
      await tester.pumpWidget(buildScreen(expenses: const []));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.receipt_long), findsOneWidget);
      expect(find.text('No expenses recorded'), findsOneWidget);
    });

    testWidgets('error state shows retry button', (tester) async {
      await tester.pumpWidget(buildScreen(error: 'Connection failed'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load expenses'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
    });
  });

  group('ExpenseFormScreen', () {
    Widget buildCreateScreen({ExpenseModel? expense}) {
      final mockRepo = _MockExpenseRepo();

      return ProviderScope(
        overrides: [expenseRepositoryProvider.overrideWith((ref) => mockRepo)],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 1200)),
            child: ExpenseFormScreen(
              currentUserId: 'treasurer1',
              expense: expense,
            ),
          ),
        ),
      );
    }

    testWidgets('create mode renders form fields', (tester) async {
      await tester.pumpWidget(buildCreateScreen());
      await tester.pumpAndSettle();

      expect(find.text('Add Expense'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(
        find.byType(DropdownButtonFormField<ExpenseCategory>),
        findsOneWidget,
      );
      expect(find.text('Save Expense'), findsOneWidget);
      expect(find.text('No receipt uploaded'), findsOneWidget);
    });

    testWidgets('form validation rejects empty fields', (tester) async {
      await tester.pumpWidget(buildCreateScreen());
      await tester.pumpAndSettle();

      final saveButton = find.widgetWithText(FilledButton, 'Save Expense');
      expect(saveButton, findsOneWidget);
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('Title is required'), findsOneWidget);
      expect(find.text('Description is required'), findsOneWidget);
      expect(find.text('Amount is required'), findsOneWidget);
    });

    testWidgets('edit mode pre-fills data', (tester) async {
      final expense = testExpenses[0];
      await tester.pumpWidget(buildCreateScreen(expense: expense));
      await tester.pumpAndSettle();

      expect(find.text('Edit Expense'), findsOneWidget);

      final titleField = find.byType(TextFormField).at(0);
      expect(
        tester.widget<TextFormField>(titleField).controller?.text,
        expense.title,
      );

      final amountField = find.byType(TextFormField).at(2);
      expect(
        tester.widget<TextFormField>(amountField).controller?.text,
        expense.amount.toString(),
      );

      // Receipt uploaded should be shown for existing receiptUrl
      expect(find.text('Receipt uploaded'), findsOneWidget);
    });

    testWidgets('save button calls create on valid form', (tester) async {
      final mockRepo = _MockExpenseRepo();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            expenseRepositoryProvider.overrideWith((ref) => mockRepo),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(size: Size(800, 1200)),
              child: ExpenseFormScreen(currentUserId: 'treasurer1'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Fill title
      await tester.enterText(find.byType(TextFormField).at(0), 'New Expense');
      // Fill description
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Test description',
      );
      // Fill amount
      await tester.enterText(find.byType(TextFormField).at(2), '10000');

      // Save
      final saveButton = find.widgetWithText(FilledButton, 'Save Expense');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(mockRepo.createCalled, isTrue);
      expect(mockRepo.lastCreated?.title, 'New Expense');
      expect(mockRepo.lastCreated?.description, 'Test description');
      expect(mockRepo.lastCreated?.amount, 10000);
      expect(mockRepo.lastCreated?.category, ExpenseCategory.miscellaneous);
      expect(mockRepo.lastCreated?.createdBy, 'treasurer1');
    });

    testWidgets('save button calls update in edit mode', (tester) async {
      final mockRepo = _MockExpenseRepo();
      final expense = testExpenses[0];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            expenseRepositoryProvider.overrideWith((ref) => mockRepo),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(size: Size(800, 1200)),
              child: ExpenseFormScreen(
                currentUserId: 'treasurer1',
                expense: expense,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Modify title
      await tester.enterText(find.byType(TextFormField).at(0), 'Updated Rent');

      // Save
      final saveButton = find.widgetWithText(FilledButton, 'Update Expense');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(mockRepo.updateCalled, isTrue);
      expect(mockRepo.lastUpdated?.id, expense.id);
      expect(mockRepo.lastUpdated?.title, 'Updated Rent');
    });
  });
}
