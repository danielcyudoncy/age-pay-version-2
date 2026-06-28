import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/enums.dart';
import '../../../data/models/expense_model.dart';
import '../providers/expense_provider.dart';
import 'expense_form_screen.dart';

class ExpenseListScreen extends ConsumerWidget {
  final String currentUserId;

  const ExpenseListScreen({super.key, required this.currentUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final expensesAsync = ref.watch(expensesStreamProvider);
    final total = ref.watch(expenseTotalProvider);
    final selectedFilter = ref.watch(expenseFilterProvider);

    final currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Chip(
                  avatar: const Icon(Icons.account_balance_wallet, size: 18),
                  label: Text(
                    'Total: ${currencyFormat.format(total)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: theme.colorScheme.primaryContainer,
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Category filter chips
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    context,
                    label: 'All',
                    selected: selectedFilter == null,
                    onSelected: (_) {
                      ref.read(expenseFilterProvider.notifier).state = null;
                    },
                  ),
                  ...ExpenseCategory.values.map((category) {
                    return _buildFilterChip(
                      context,
                      label: _categoryLabel(category),
                      selected: selectedFilter == category,
                      onSelected: (_) {
                        ref.read(expenseFilterProvider.notifier).state =
                            category;
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // Expenses list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(expensesStreamProvider);
              },
              child: expensesAsync.when(
                data: (expenses) {
                  final filtered = selectedFilter == null
                      ? expenses
                      : expenses
                            .where((e) => e.category == selectedFilter)
                            .toList();

                  if (filtered.isEmpty) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.receipt_long,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No expenses recorded',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final expense = filtered[index];
                      return _ExpenseCard(
                        expense: expense,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ExpenseFormScreen(
                                currentUserId: currentUserId,
                                expense: expense,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load expenses',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => ref.invalidate(expensesStreamProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ExpenseFormScreen(currentUserId: currentUserId),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: onSelected,
      ),
    );
  }

  String _categoryLabel(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.welfare:
        return 'Welfare';
      case ExpenseCategory.projects:
        return 'Projects';
      case ExpenseCategory.events:
        return 'Events';
      case ExpenseCategory.administration:
        return 'Administration';
      case ExpenseCategory.miscellaneous:
        return 'Miscellaneous';
    }
  }
}

class _ExpenseCard extends StatelessWidget {
  final ExpenseModel expense;
  final VoidCallback onTap;

  const _ExpenseCard({required this.expense, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      expense.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (expense.receiptUrl != null &&
                      expense.receiptUrl!.isNotEmpty)
                    const Icon(Icons.receipt, size: 20, color: Colors.green),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                expense.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Chip(
                    label: Text(
                      _categoryLabel(expense.category),
                      style: const TextStyle(fontSize: 12),
                    ),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  Text(
                    currencyFormat.format(expense.amount),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                dateFormat.format(expense.expenseDate),
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _categoryLabel(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.welfare:
        return 'Welfare';
      case ExpenseCategory.projects:
        return 'Projects';
      case ExpenseCategory.events:
        return 'Events';
      case ExpenseCategory.administration:
        return 'Administration';
      case ExpenseCategory.miscellaneous:
        return 'Miscellaneous';
    }
  }
}
