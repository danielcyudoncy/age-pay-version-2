// features/members/screens/treasurer_member_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/data/models/member_model.dart';
import 'package:cls/features/dashboard/providers/treasurer_dashboard_provider.dart';
import 'package:cls/features/obligations/providers/obligation_provider.dart';
import 'package:cls/core/constants/enums.dart';

class TreasurerMemberDetailScreen extends ConsumerWidget {
  final String memberId;

  const TreasurerMemberDetailScreen({super.key, required this.memberId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersStreamProvider);
    final obligationsAsync = ref.watch(memberObligationsProvider(memberId));
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final dateFormat = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Member Details'),
        centerTitle: true,
      ),
      body: membersAsync.when(
        data: (members) {
          final member = members.firstWhere(
            (m) => m.userId == memberId || m.id == memberId,
            orElse: () => MemberModel(
              id: memberId,
              userId: memberId,
              fullName: 'Unknown Member',
              email: '',
              phoneNumber: '',
              dateOfBirth: DateTime(2000),
              joinedDate: DateTime(2000),
              createdAt: DateTime(2000),
              updatedAt: DateTime(2000),
            ),
          );

          return obligationsAsync.when(
            data: (obligations) {
              final owed = obligations.fold<double>(
                0.0,
                (sum, o) => sum + o.outstandingBalance,
              );
              final paid = obligations.fold<double>(
                0.0,
                (sum, o) => sum + o.paidAmount,
              );

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _MemberInfoCard(member: member, dateFormat: dateFormat),
                  const SizedBox(height: 16),
                  _LevySummaryCard(
                    label: 'Levies Owed',
                    amount: owed,
                    color: Colors.redAccent,
                    currency: currency,
                  ),
                  const SizedBox(height: 12),
                  _LevySummaryCard(
                    label: 'Levies Paid',
                    amount: paid,
                    color: Colors.green,
                    currency: currency,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Obligations',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (obligations.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.assignment_turned_in_outlined,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No obligations',
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      children: obligations.map((o) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
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
                                        o.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    _StatusChip(status: o.status),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildAmountColumn(
                                        'Total',
                                        o.amount,
                                        isBold: true,
                                        currency: currency,
                                        context: context,
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildAmountColumn(
                                        'Paid',
                                        o.paidAmount,
                                        color: Colors.green,
                                        currency: currency,
                                        context: context,
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildAmountColumn(
                                        'Owing',
                                        o.outstandingBalance,
                                        color: Colors.redAccent,
                                        currency: currency,
                                        context: context,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Due: ${dateFormat.format(o.dueDate)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text(
                'Error: $error',
                style: const TextStyle(color: Colors.red),
              ),
            ),
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
    );
  }

  Widget _buildAmountColumn(
    String label,
    double value, {
    bool isBold = false,
    Color? color,
    required NumberFormat currency,
    required BuildContext context,
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
          currency.format(value),
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: color ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _MemberInfoCard extends StatelessWidget {
  final MemberModel member;
  final DateFormat dateFormat;

  const _MemberInfoCard({required this.member, required this.dateFormat});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  child: Text(
                    member.fullName.isNotEmpty ? member.fullName[0] : '?',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 16),
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
                      const SizedBox(height: 4),
                      Text(
                        member.email,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.phone,
              label: 'Phone',
              value: member.phoneNumber,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.cake,
              label: 'Date of Birth',
              value: dateFormat.format(member.dateOfBirth),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.calendar_today,
              label: 'Joined',
              value: dateFormat.format(member.joinedDate),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.info_outline,
              label: 'Status',
              value: member.isActive ? 'Active' : 'Inactive',
              valueColor: member.isActive ? Colors.green : Colors.orange,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: valueColor ?? Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _LevySummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final NumberFormat currency;

  const _LevySummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            Text(
              currency.format(amount),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ObligationStatus status;

  const _StatusChip({required this.status});

  Color _color() {
    switch (status) {
      case ObligationStatus.paid:
        return Colors.green;
      case ObligationStatus.partial:
        return Colors.orange;
      case ObligationStatus.unpaid:
        return Colors.redAccent;
    }
  }

  String _label() {
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color().withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _label(),
        style: TextStyle(
          color: _color(),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
