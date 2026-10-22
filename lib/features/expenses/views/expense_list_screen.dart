import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/enums.dart';
import '../models/expense_model.dart';
import '../controllers/expense_provider.dart';
import '../widgets/expense_approval_queue_card.dart';
import 'expense_form_screen.dart';

class ExpenseListScreen extends ConsumerWidget {
  final String currentUserId;
  final bool isExecutive;
  final String? organizationId;

  const ExpenseListScreen({
    super.key,
    required this.currentUserId,
    this.isExecutive = true,
    this.organizationId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final canManage = isExecutive;
    final expensesAsync = ref.watch(expensesStreamProvider);
    final approvedTotal = ref.watch(expenseTotalProvider);
    final pendingTotal = ref.watch(pendingExpenseTotalProvider);
    final selectedFilter = ref.watch(expenseFilterProvider);
    final orgId = organizationId ?? '';

    final currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Chip(
                    avatar: const Icon(Icons.check_circle, size: 16, color: Colors.green),
                    label: Text(
                      'Total: ${currencyFormat.format(approvedTotal)} (Approved)',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),
                    backgroundColor: Colors.green.shade50,
                    side: BorderSide(color: Colors.green.shade200),
                  ),
                  if (pendingTotal > 0) ...[
                    const SizedBox(width: 8),
                    Chip(
                      avatar: const Icon(Icons.hourglass_top, size: 16, color: Colors.amber),
                      label: Text(
                        'Pending Sign-off: ${currencyFormat.format(pendingTotal)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                      backgroundColor: Colors.amber.shade50,
                      side: BorderSide(color: Colors.amber.shade200),
                    ),
                  ],
                ],
              ),
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

                  final hasQueue = canManage && orgId.isNotEmpty;

                  if (filtered.isEmpty) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (hasQueue) ...[
                                ExpenseApprovalQueueCard(organizationId: orgId),
                                const SizedBox(height: 12),
                              ],
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight - (hasQueue ? 120 : 0),
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
                            ],
                          ),
                        );
                      },
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length + (hasQueue ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (hasQueue && index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ExpenseApprovalQueueCard(organizationId: orgId),
                        );
                      }
                      final expense = filtered[hasQueue ? index - 1 : index];
                      return _ExpenseCard(
                        expense: expense,
                        onTap: () {
                          if (canManage) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ExpenseFormScreen(
                                  currentUserId: currentUserId,
                                  expense: expense,
                                ),
                              ),
                            );
                          } else {
                            _showExpenseDetails(context, expense);
                          }
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
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              heroTag: 'fab_add_expense',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ExpenseFormScreen(currentUserId: currentUserId),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Expense'),
            )
          : null,
    );
  }

  void _showExpenseDetails(BuildContext context, ExpenseModel expense) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final dateFormat = DateFormat('EEE, dd MMM yyyy');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Chip(
                      label: Text(_categoryLabel(expense.category)),
                      backgroundColor: theme.colorScheme.primaryContainer,
                    ),
                    Text(
                      currencyFormat.format(expense.amount),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  expense.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateFormat.format(expense.expenseDate),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Description',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  expense.description.isNotEmpty
                      ? expense.description
                      : 'No description provided.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (expense.receiptUrl != null &&
                    expense.receiptUrl!.isNotEmpty) ...[
                  Text(
                    'Receipt / Proof of Payment',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      expense.receiptUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox(
                          height: 160,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 100,
                        color: Colors.grey.shade100,
                        alignment: Alignment.center,
                        child: const Text('Failed to load receipt image'),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
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

    final isApproved = expense.status == ExpenseStatus.approved;
    final isRejected = expense.status == ExpenseStatus.rejected;
    final isPending = expense.status == ExpenseStatus.pendingApproval;

    final statusColor = isApproved
        ? Colors.green.shade700
        : (isRejected ? Colors.red.shade700 : Colors.amber.shade800);
    final statusBg = isApproved
        ? Colors.green.shade50
        : (isRejected ? Colors.red.shade50 : Colors.amber.shade50);
    final statusLabel = isApproved
        ? 'APPROVED'
        : (isRejected ? 'REJECTED' : 'PENDING (${expense.approvedCount}/3)');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isPending ? 1 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPending ? Colors.amber.shade300 : Colors.grey.shade300,
          width: isPending ? 1.2 : 0.8,
        ),
      ),
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
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (expense.receiptUrl != null &&
                      expense.receiptUrl!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.receipt, size: 18, color: Colors.green),
                  ],
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
              const SizedBox(height: 10),
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
                      color: isApproved ? Colors.red.shade700 : Colors.grey.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Executive Signatures row
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _signatoryIndicator('President', expense.isPresidentApproved),
                  _signatoryIndicator(
                    'Fin. Sec',
                    expense.isFinancialSecretaryApproved,
                  ),
                  _signatoryIndicator('Secretary', expense.isSecretaryApproved),
                  Text(
                    dateFormat.format(expense.expenseDate),
                    style:
                        theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
              if (isRejected && expense.rejectionReason != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Reason: ${expense.rejectionReason}',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _signatoryIndicator(String title, bool signed) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: signed ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: signed ? Colors.green.shade300 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            signed ? Icons.check_circle : Icons.schedule,
            size: 11,
            color: signed ? Colors.green.shade700 : Colors.grey.shade600,
          ),
          const SizedBox(width: 3),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: signed ? FontWeight.bold : FontWeight.normal,
              color: signed ? Colors.green.shade900 : Colors.grey.shade700,
            ),
          ),
        ],
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
