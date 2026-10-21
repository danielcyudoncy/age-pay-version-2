import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/enums.dart';
import '../controllers/reports_provider.dart';
import 'report_kpi_card.dart';

class LevyReportWidget extends StatelessWidget {
  final ReportRequest request;

  const LevyReportWidget({super.key, required this.request});

  static final _currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
  static final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final levy = request.levy;
    final obligations = request.obligations;
    final payments = request.payments;

    if (levy == null) {
      return const Center(child: Text('No levy data available'));
    }

    final members = request.members;
    final memberNameMap = <String, String>{};
    for (final m in members) {
      if (m.fullName.isNotEmpty) {
        memberNameMap[m.id] = m.fullName;
        if (m.userId.isNotEmpty) {
          memberNameMap[m.userId] = m.fullName;
        }
      }
    }

    final totalMembers = obligations.isNotEmpty
        ? obligations.length
        : (request.totalMembers ?? 1);
    final obligationsTarget =
        obligations.fold<double>(0, (s, o) => s + o.amount);
    final computedTarget = levy.amountPerMember * totalMembers;
    final totalTarget =
        obligationsTarget > 0 ? obligationsTarget : computedTarget;

    final totalCollectedObligations = obligations.fold<double>(0, (s, o) => s + o.paidAmount);
    final totalCollectedPayments = payments
        .where((p) => p.status == PaymentStatus.approved)
        .fold<double>(0, (s, p) => s + p.amount);
    final totalCollected = totalCollectedPayments >= totalCollectedObligations
        ? totalCollectedPayments
        : totalCollectedObligations;

    final totalOutstanding = obligations.fold<double>(0, (s, o) => s + o.outstandingBalance);
    final collectionPct = totalTarget > 0 ? (totalCollected / totalTarget).clamp(0.0, 1.0) : 0.0;
    final ratePerMember = levy.amountPerMember > 0
        ? levy.amountPerMember
        : (obligations.isNotEmpty ? obligations.first.amount : 0.0);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Overview Card with Progress
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        color: theme.colorScheme.onPrimaryContainer,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            levy.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Rate: ${_currency.format(ratePerMember)} per member  •  $totalMembers members',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Collection Progress',
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${(collectionPct * 100).toStringAsFixed(1)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: collectionPct,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      collectionPct >= 1.0 ? Colors.green : theme.colorScheme.primary,
                    ),
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
                title: 'Total Target',
                value: _currency.format(totalTarget),
                icon: Icons.track_changes,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ReportKpiCard(
                title: 'Collected',
                value: _currency.format(totalCollected),
                icon: Icons.check_circle_outline,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ReportKpiCard(
                title: 'Outstanding',
                value: _currency.format(totalOutstanding),
                icon: Icons.pending_actions_outlined,
                color: totalOutstanding > 0 ? Colors.orange : Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Obligations Ledger
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Member Obligations (${obligations.length})',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (obligations.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('No obligation records linked to this levy.')),
            ),
          )
        else
          ...obligations.map((o) {
            final isFullyPaid = o.outstandingBalance <= 0;
            final memberName = memberNameMap[o.memberId];
            final displayName =
                (memberName != null && memberName.trim().isNotEmpty)
                    ? memberName
                    : (o.title.isNotEmpty ? o.title : 'Member Dues');
            final subtitleText =
                (memberName != null && o.title.isNotEmpty && o.title != displayName)
                    ? o.title
                    : null;
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
                          size: 16,
                          color: isFullyPaid ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              if (subtitleText != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subtitleText,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
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
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Paid: ${_currency.format(o.paidAmount)}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade700),
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
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
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
