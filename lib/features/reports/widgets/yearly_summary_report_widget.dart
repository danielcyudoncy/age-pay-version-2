import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/enums.dart';
import '../controllers/reports_provider.dart';
import 'report_kpi_card.dart';

class YearlySummaryReportWidget extends StatelessWidget {
  final ReportRequest request;

  const YearlySummaryReportWidget({super.key, required this.request});

  static final _currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final year = request.year ?? DateTime.now().year;
    final payments = request.payments;
    final expenses = request.expenses;
    final obligations = request.obligations;

    // Monthly Income
    final monthlyIncome = <int, double>{};
    for (var i = 1; i <= 12; i++) {
      monthlyIncome[i] = 0.0;
    }
    for (final p in payments.where((p) => p.status == PaymentStatus.approved)) {
      if (p.createdAt.year == year) {
        final m = p.createdAt.month;
        monthlyIncome[m] = (monthlyIncome[m] ?? 0.0) + p.amount;
      }
    }

    final monthlyObligations = <int, double>{};
    for (var i = 1; i <= 12; i++) {
      monthlyObligations[i] = 0.0;
    }
    for (final o in obligations.where((o) => o.paidAmount > 0)) {
      final d = o.settledAt ?? o.createdAt;
      if (d.year == year) {
        monthlyObligations[d.month] = (monthlyObligations[d.month] ?? 0.0) + o.paidAmount;
      }
    }

    final paymentsSum = monthlyIncome.values.fold<double>(0, (s, v) => s + v);
    final obligationsSum = monthlyObligations.values.fold<double>(0, (s, v) => s + v);
    if (obligationsSum > paymentsSum) {
      for (var i = 1; i <= 12; i++) {
        monthlyIncome[i] = monthlyObligations[i] ?? 0.0;
      }
    }

    // Monthly Expenses
    final monthlyExpenses = <int, double>{};
    for (var i = 1; i <= 12; i++) {
      monthlyExpenses[i] = 0.0;
    }
    for (final e in expenses) {
      if (e.expenseDate.year == year) {
        final m = e.expenseDate.month;
        monthlyExpenses[m] = (monthlyExpenses[m] ?? 0.0) + e.amount;
      }
    }

    final totalIncome = monthlyIncome.values.fold<double>(0, (s, v) => s + v);
    final totalExpenses = monthlyExpenses.values.fold<double>(0, (s, v) => s + v);
    final netBalance = totalIncome - totalExpenses;
    final outstandingTotal = obligations.fold<double>(0, (s, o) => s + o.outstandingBalance);

    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Year Banner & Net Balance
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
                    color: (netBalance >= 0 ? Colors.green : Colors.red).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    netBalance >= 0 ? Icons.trending_up : Icons.trending_down,
                    color: netBalance >= 0 ? Colors.green : Colors.red,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Annual Financial Performance',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Year $year',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Net Balance',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      _currency.format(netBalance),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: netBalance >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                  ],
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
                title: 'Total Income',
                value: _currency.format(totalIncome),
                icon: Icons.south_west,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ReportKpiCard(
                title: 'Total Expenses',
                value: _currency.format(totalExpenses),
                icon: Icons.north_east,
                color: Colors.red,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ReportKpiCard(
                title: 'Unpaid Dues',
                value: _currency.format(outstandingTotal),
                icon: Icons.schedule,
                color: outstandingTotal > 0 ? Colors.orange : Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 12-Month Matrix
        Text(
          '12-Month Cashflow Breakdown',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        ...List.generate(12, (index) {
          final mIndex = index + 1;
          final mName = monthNames[index];
          final mIncome = monthlyIncome[mIndex] ?? 0.0;
          final mExpense = monthlyExpenses[mIndex] ?? 0.0;
          final mNet = mIncome - mExpense;
          final hasActivity = mIncome > 0 || mExpense > 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: hasActivity
                          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.6)
                          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      mName.substring(0, 3).toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: hasActivity
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'In: ${_currency.format(mIncome)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: mIncome > 0 ? Colors.green.shade700 : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Out: ${_currency.format(mExpense)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: mExpense > 0 ? Colors.red.shade700 : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Net',
                        style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                      ),
                      Text(
                        _currency.format(mNet),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: mNet > 0
                              ? Colors.green.shade800
                              : (mNet < 0 ? Colors.red.shade800 : Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
      ],
    );
  }
}
