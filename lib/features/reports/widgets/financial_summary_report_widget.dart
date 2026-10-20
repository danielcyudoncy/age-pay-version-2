import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/enums.dart';
import '../controllers/reports_provider.dart';
import 'report_kpi_card.dart';

class FinancialSummaryReportWidget extends StatelessWidget {
  final ReportRequest request;

  const FinancialSummaryReportWidget({super.key, required this.request});

  static final _currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
  static final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payments = request.payments;
    final expenses = request.expenses;
    final members = request.members;
    final obligations = request.obligations;
    final startDate = request.startDate;
    final endDate = request.endDate;

    final approvedPayments = payments.where((p) => p.status == PaymentStatus.approved);
    final filteredPayments = approvedPayments.where((p) {
      if (startDate != null && p.createdAt.isBefore(startDate)) return false;
      if (endDate != null) {
        final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        if (p.createdAt.isAfter(end)) return false;
      }
      return true;
    });

    final filteredObligations = obligations.where((o) {
      final date = o.settledAt ?? o.createdAt;
      if (startDate != null && date.isBefore(startDate)) return false;
      if (endDate != null) {
        final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        if (date.isAfter(end)) return false;
      }
      return true;
    });

    final filteredExpenses = expenses.where((e) {
      if (startDate != null && e.expenseDate.isBefore(startDate)) return false;
      if (endDate != null) {
        final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        if (e.expenseDate.isAfter(end)) return false;
      }
      return true;
    });

    final paymentsCollections = filteredPayments.fold<double>(0, (s, p) => s + p.amount);
    final obligationsCollections = filteredObligations.fold<double>(0, (s, o) => s + o.paidAmount);

    double onlineTotal = filteredPayments
        .where((p) => p.method == PaymentMethod.online)
        .fold<double>(0, (s, p) => s + p.amount);
    double cashTotal = filteredPayments
        .where((p) => p.method == PaymentMethod.cash)
        .fold<double>(0, (s, p) => s + p.amount);
    double bankTotal = filteredPayments
        .where((p) => p.method == PaymentMethod.bankTransfer)
        .fold<double>(0, (s, p) => s + p.amount);

    double totalCollections = paymentsCollections;
    if (obligationsCollections > paymentsCollections) {
      totalCollections = obligationsCollections;
      cashTotal += (obligationsCollections - paymentsCollections);
    }

    final totalExpenses = filteredExpenses.fold<double>(0, (s, e) => s + e.amount);
    final netPosition = totalCollections - totalExpenses;
    final totalOutstanding = obligations.fold<double>(0, (s, o) => s + o.outstandingBalance);

    final totalMembersCount = members.length;
    final activeMembersCount = members.where((m) => m.isActive).length;

    final expensesByCategory = <ExpenseCategory, double>{};
    for (final e in filteredExpenses) {
      expensesByCategory[e.category] = (expensesByCategory[e.category] ?? 0.0) + e.amount;
    }

    final dateRangeText = (startDate != null || endDate != null)
        ? '${startDate != null ? _dateFormat.format(startDate) : "Start"}  ➔  ${endDate != null ? _dateFormat.format(endDate) : "Present"}'
        : 'All Time';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Executive Summary Card
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Executive Financial Summary',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        dateRangeText,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Net Position', style: theme.textTheme.bodySmall),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _currency.format(netPosition),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: netPosition >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Membership', style: theme.textTheme.bodySmall),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '$activeMembersCount Active / $totalMembersCount',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
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
                title: 'Collections',
                value: _currency.format(totalCollections),
                icon: Icons.account_balance_wallet_outlined,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ReportKpiCard(
                title: 'Expenses',
                value: _currency.format(totalExpenses),
                icon: Icons.shopping_bag_outlined,
                color: Colors.red,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ReportKpiCard(
                title: 'Unpaid Dues',
                value: _currency.format(totalOutstanding),
                icon: Icons.warning_amber_rounded,
                color: totalOutstanding > 0 ? Colors.orange : Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Collections by Channel
        Text(
          'Collections by Payment Channel',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                _buildChannelRow('Online (Paystack)', onlineTotal, totalCollections, Colors.blue),
                const Divider(height: 16),
                _buildChannelRow('Cash / Direct Dues', cashTotal, totalCollections, Colors.green),
                const Divider(height: 16),
                _buildChannelRow('Bank Transfer', bankTotal, totalCollections, Colors.purple),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Expenses by Category
        Text(
          'Expenditure by Category',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (expensesByCategory.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('No expenses recorded for this period.')),
            ),
          )
        else
          ...expensesByCategory.entries.map((entry) {
            final pct = totalExpenses > 0 ? (entry.value / totalExpenses) : 0.0;
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
                title: Text(
                  entry.key.name.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                subtitle: Text('${(pct * 100).toStringAsFixed(1)}% of total expenses'),
                trailing: Text(
                  _currency.format(entry.value),
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

  Widget _buildChannelRow(String name, double amount, double total, Color color) {
    final pct = total > 0 ? (amount / total) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_currency.format(amount)} (${(pct * 100).toStringAsFixed(1)}%)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: Colors.grey.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
