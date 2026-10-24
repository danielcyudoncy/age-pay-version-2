import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/enums.dart';
import '../controllers/reports_provider.dart';
import 'report_kpi_card.dart';

class MemberStatementReportWidget extends StatelessWidget {
  final ReportRequest request;

  const MemberStatementReportWidget({super.key, required this.request});

  static final _currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
  static final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final member = request.member;
    final obligations = request.obligations;
    final payments = request.payments;

    if (member == null) {
      return const Center(child: Text('No member data available'));
    }

    final totalObligations = obligations.fold<double>(0, (s, o) => s + o.amount);
    final paymentsSum = payments
        .where((p) => p.status == PaymentStatus.approved)
        .fold<double>(0, (s, p) => s + p.amount);
    final obligationsPaidSum = obligations.fold<double>(0, (s, o) => s + o.paidAmount);
    final totalPaid = paymentsSum >= obligationsPaidSum ? paymentsSum : obligationsPaidSum;
    final totalOutstanding = obligations.fold<double>(0, (s, o) => s + o.outstandingBalance);

    final paymentRecords = payments.isNotEmpty
        ? payments.map((p) => _DisplayPayment(
              date: p.createdAt,
              amount: p.amount,
              method: p.method.name,
              status: p.status.name,
            )).toList()
        : obligations
            .where((o) => o.paidAmount > 0)
            .map((o) => _DisplayPayment(
                  date: o.settledAt ?? o.createdAt,
                  amount: o.paidAmount,
                  method: 'Direct / Dues',
                  status: o.status.name,
                ))
            .toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Member Info Card
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    member.fullName.isNotEmpty
                        ? member.fullName.substring(0, 1).toUpperCase()
                        : 'M',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.fullName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (member.email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          member.email,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (member.phoneNumber.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          member.phoneNumber,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: member.isActive
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.grey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    member.isActive ? 'Active Member' : 'Inactive Member',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: member.isActive ? Colors.green.shade800 : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // KPIs
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ReportKpiCard(
                  title: 'Total Obligations',
                  value: _currency.format(totalObligations),
                  icon: Icons.assignment_outlined,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ReportKpiCard(
                  title: 'Total Paid',
                  value: _currency.format(totalPaid),
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ReportKpiCard(
                  title: 'Outstanding Balance',
                  value: _currency.format(totalOutstanding),
                  icon: Icons.pending_actions_outlined,
                  color: totalOutstanding > 0 ? Colors.orange : Colors.green,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Obligations Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Obligations (${obligations.length})',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (obligations.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('No obligations recorded for this member.')),
            ),
          )
        else
          ...obligations.map((o) {
            final isFullyPaid = o.outstandingBalance <= 0;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isFullyPaid ? Icons.check_circle : Icons.hourglass_top,
                          color: isFullyPaid ? Colors.green : Colors.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            o.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isFullyPaid ? Colors.green : Colors.orange).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isFullyPaid ? 'Settled' : 'Unpaid',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isFullyPaid ? Colors.green.shade800 : Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        Text(
                          'Total: ${_currency.format(o.amount)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Paid: ${_currency.format(o.paidAmount)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                          ),
                        ),
                        Text(
                          'Balance: ${_currency.format(o.outstandingBalance)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: o.outstandingBalance > 0 ? Colors.red.shade700 : Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Due Date: ${_dateFormat.format(o.dueDate)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 20),

        // Payments History Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Payments (${paymentRecords.length})',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (paymentRecords.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('No payment history recorded.')),
            ),
          )
        else
          ...paymentRecords.map((p) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, color: Colors.blue, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currency.format(p.amount),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Date: ${_dateFormat.format(p.date)}  •  Method: ${p.method}',
                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        p.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
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

class _DisplayPayment {
  final DateTime date;
  final double amount;
  final String method;
  final String status;

  _DisplayPayment({
    required this.date,
    required this.amount,
    required this.method,
    required this.status,
  });
}
