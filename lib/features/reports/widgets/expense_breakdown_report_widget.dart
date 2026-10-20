import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/enums.dart';
import '../../expenses/models/expense_model.dart';
import '../controllers/reports_provider.dart';
import 'report_kpi_card.dart';

class ExpenseBreakdownReportWidget extends StatelessWidget {
  final ReportRequest request;

  const ExpenseBreakdownReportWidget({super.key, required this.request});

  static final _currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
  static final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allExpenses = request.expenses;
    final startDate = request.startDate;
    final endDate = request.endDate;

    final filtered = allExpenses.where((e) {
      if (startDate != null && e.expenseDate.isBefore(startDate)) return false;
      if (endDate != null) {
        final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        if (e.expenseDate.isAfter(end)) return false;
      }
      return true;
    }).toList();

    final grandTotal = filtered.fold<double>(0, (sum, e) => sum + e.amount);

    final categoryMap = <ExpenseCategory, List<ExpenseModel>>{};
    for (final e in filtered) {
      categoryMap.putIfAbsent(e.category, () => []).add(e);
    }

    final dateRangeText = (startDate != null || endDate != null)
        ? '${startDate != null ? _dateFormat.format(startDate) : "Start"}  ➔  ${endDate != null ? _dateFormat.format(endDate) : "Present"}'
        : 'All Time';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Period Banner
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.pie_chart_outline, color: Colors.red, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Expenditure',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _currency.format(grandTotal),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.date_range, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        dateRangeText,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // KPIs
        Row(
          children: [
            Expanded(
              child: ReportKpiCard(
                title: 'Total Spent',
                value: _currency.format(grandTotal),
                icon: Icons.payments_outlined,
                color: Colors.red,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ReportKpiCard(
                title: 'Expenses Count',
                value: '${filtered.length}',
                icon: Icons.receipt_long,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ReportKpiCard(
                title: 'Categories',
                value: '${categoryMap.length}',
                icon: Icons.category_outlined,
                color: Colors.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Category Breakdown Cards
        Text(
          'Breakdown by Category',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (categoryMap.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('No expenses recorded for this period.')),
            ),
          )
        else
          ...categoryMap.entries.map((entry) {
            final categoryTotal = entry.value.fold<double>(0, (s, e) => s + e.amount);
            final pct = grandTotal > 0 ? (categoryTotal / grandTotal) : 0.0;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key.name.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          '${_currency.format(categoryTotal)} (${(pct * 100).toStringAsFixed(1)}%)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${entry.value.length} transaction${entry.value.length == 1 ? "" : "s"}',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade400),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 20),

        // Itemized List
        Text(
          'Expense Transactions (${filtered.length})',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...filtered.map((e) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.arrow_upward, color: Colors.red, size: 20),
              ),
              title: Text(
                e.description.isNotEmpty ? e.description : e.category.name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(
                '${_dateFormat.format(e.expenseDate)}  •  ${e.category.name}',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              ),
              trailing: Text(
                _currency.format(e.amount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.red.shade800,
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
      ],
    );
  }
}
