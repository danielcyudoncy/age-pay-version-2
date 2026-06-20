// features/obligations/screens/treasurer_obligations_screen.dart
import 'package:cls/data/models/obligation_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/obligations/providers/obligation_provider.dart';
import 'package:intl/intl.dart';

class TreasurerObligationsScreen extends ConsumerWidget {
  const TreasurerObligationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obligationsAsync = ref.watch(filteredObligationsProvider);
    final filter = ref.watch(obligationFilterProvider);
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final dateFormat = DateFormat('MMM d, yyyy');

    final statusFilters = <ObligationStatus?, String>{
      null: 'All',
      ObligationStatus.unpaid: 'Unpaid',
      ObligationStatus.partial: 'Partial',
      ObligationStatus.paid: 'Paid',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Obligations'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () =>
                _showFilterSheet(context, ref, filter, statusFilters),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by title or description...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                ref.read(obligationFilterProvider.notifier).state = filter
                    .copyWith(searchQuery: value);
              },
            ),
          ),
          Expanded(
            child: obligationsAsync.when(
              data: (obligations) {
                if (obligations.isEmpty) {
                  return const Center(
                    child: Text(
                      'No obligations match the current filters',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: obligations.length,
                  itemBuilder: (context, index) {
                    final obligation = obligations[index];
                    return _ObligationAdminCard(
                      obligation: obligation,
                      currency: currency,
                      dateFormat: dateFormat,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  'Error: $error',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(
    BuildContext context,
    WidgetRef ref,
    ObligationFilterState currentFilter,
    Map<ObligationStatus?, String> statusFilters,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filter by Status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: statusFilters.entries.map((entry) {
                    final isSelected = currentFilter.statusFilter == entry.key;
                    return ChoiceChip(
                      label: Text(entry.value),
                      selected: isSelected,
                      onSelected: (_) {
                        ref.read(obligationFilterProvider.notifier).state =
                            currentFilter.copyWith(statusFilter: entry.key);
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      ref.read(obligationFilterProvider.notifier).state =
                          const ObligationFilterState();
                      Navigator.pop(context);
                    },
                    child: const Text('Clear Filters'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ObligationAdminCard extends StatelessWidget {
  final ObligationModel obligation;
  final NumberFormat currency;
  final DateFormat dateFormat;

  const _ObligationAdminCard({
    required this.obligation,
    required this.currency,
    required this.dateFormat,
  });

  Color _statusColor(ObligationStatus status) {
    switch (status) {
      case ObligationStatus.paid:
        return Colors.green;
      case ObligationStatus.partial:
        return Colors.orange;
      case ObligationStatus.unpaid:
        return Colors.red;
    }
  }

  String _statusLabel(ObligationStatus status) {
    switch (status) {
      case ObligationStatus.paid:
        return 'Paid';
      case ObligationStatus.partial:
        return 'Partial';
      case ObligationStatus.unpaid:
        return 'Unpaid';
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = obligation.amount > 0
        ? (obligation.paidAmount / obligation.amount).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        obligation.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Member: ${obligation.memberId.substring(0, obligation.memberId.length > 8 ? 8 : obligation.memberId.length)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(
                      obligation.status,
                    ).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusLabel(obligation.status),
                    style: TextStyle(
                      color: _statusColor(obligation.status),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildAmountColumn(
                    'Total',
                    obligation.amount,
                    isBold: true,
                  ),
                ),
                Expanded(
                  child: _buildAmountColumn(
                    'Paid',
                    obligation.paidAmount,
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildAmountColumn(
                    'Outstanding',
                    obligation.outstandingBalance,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                _statusColor(obligation.status),
              ),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Due: ${dateFormat.format(obligation.dueDate)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}% paid',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _statusColor(obligation.status),
                  ),
                ),
              ],
            ),
            if (obligation.status != ObligationStatus.paid) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.payment, size: 16),
                      label: const Text('Record Payment'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Adjust'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAmountColumn(
    String label,
    double value, {
    bool isBold = false,
    Color? color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 2),
        Text(
          NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(value),
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}
