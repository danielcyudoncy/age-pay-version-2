import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/core/widgets/quick_action_button.dart';
import 'package:cls/features/auth/providers/auth_provider.dart';
import 'package:cls/features/dashboard/providers/treasurer_dashboard_provider.dart';
import 'package:cls/features/obligations/providers/obligation_provider.dart';
import 'package:cls/features/levies/providers/levy_provider.dart' hide obligationRepositoryProvider;
import 'package:cls/features/levies/screens/create_levy_screen.dart';
import 'package:cls/features/expenses/providers/expense_provider.dart';

class TreasurerDashboard extends ConsumerWidget {
  const TreasurerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Treasurer Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      body: authState.when(
        data: (u) {
          if (u == null) {
            return const Center(child: Text('Please sign in'));
          }
          return _buildDashboard(context, ref);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('Error: $error', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(authProvider.notifier).refreshUser(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(treasurerDashboardProvider);
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final dateFormat = DateFormat('MMM dd, yyyy \u2022 HH:mm');

    return dashboardAsync.when(
      data: (data) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allPaymentsStreamProvider);
          ref.invalidate(allObligationsProvider);
          ref.invalidate(activeLeviesProvider);
          ref.invalidate(expensesStreamProvider);
          ref.invalidate(membersStreamProvider);
          ref.invalidate(treasurerDashboardProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Welcome, ${ref.read(authProvider).valueOrNull?.displayName ?? 'Treasurer'}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),
            _OverviewCards(data: data, currency: currency),
            const SizedBox(height: 20),
            _MemberArrearsSection(
              arrears: data.memberArrears,
              currency: currency,
            ),
            const SizedBox(height: 20),
            _LevyCollectionSection(
              levies: data.levyCollection,
              currency: currency,
            ),
            const SizedBox(height: 20),
            _RecentActivitySection(
              items: data.recentPayments,
              currency: currency,
              dateFormat: dateFormat,
            ),
            const SizedBox(height: 20),
            const _QuickActionsRow(),
            const SizedBox(height: 24),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('Error: $error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(treasurerDashboardProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewCards extends StatelessWidget {
  final TreasurerDashboardData data;
  final NumberFormat currency;

  const _OverviewCards({required this.data, required this.currency});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _OverviewCard(
            label: 'Total Collected',
            value: currency.format(data.totalCollected),
            icon: Icons.paid,
            color: Colors.green,
          ),
          const SizedBox(width: 12),
          _OverviewCard(
            label: 'Total Outstanding',
            value: currency.format(data.totalOutstanding),
            icon: Icons.pending,
            color: Colors.redAccent,
          ),
          const SizedBox(width: 12),
          _OverviewCard(
            label: 'Pending Payments',
            value: currency.format(data.totalPending),
            icon: Icons.hourglass_top,
            color: Colors.orange,
          ),
          const SizedBox(width: 12),
          _OverviewCard(
            label: 'Net Position',
            value: currency.format(data.netPosition),
            icon: Icons.account_balance,
            color: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _OverviewCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberArrearsSection extends StatelessWidget {
  final List<MemberArrears> arrears;
  final NumberFormat currency;

  const _MemberArrearsSection({required this.arrears, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Members in Arrears',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('See All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (arrears.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No members in arrears',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: arrears.take(5).map((a) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      a.memberName.isNotEmpty ? a.memberName[0] : '?',
                    ),
                  ),
                  title: Text(a.memberName),
                  subtitle: Text(
                    '${a.unpaidCount} unpaid obligation${a.unpaidCount == 1 ? '' : 's'}',
                  ),
                  trailing: Text(
                    currency.format(a.totalOutstanding),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                  onTap: () {},
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _LevyCollectionSection extends StatelessWidget {
  final List<LevyCollectionSummary> levies;
  final NumberFormat currency;

  const _LevyCollectionSection({required this.levies, required this.currency});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Levy Collection',
          style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        if (levies.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No active levies',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: levies.map((l) {
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
                              l.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Text(
                            '${(l.percentage * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${currency.format(l.collected)} / ${currency.format(l.target)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${l.memberCount} member${l.memberCount == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: l.percentage,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary,
                          ),
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
  }
}

class _RecentActivitySection extends StatelessWidget {
  final List<RecentPaymentItem> items;
  final NumberFormat currency;
  final DateFormat dateFormat;

  const _RecentActivitySection({
    required this.items,
    required this.currency,
    required this.dateFormat,
  });

  Color _statusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.approved:
        return Colors.green;
      case PaymentStatus.pending:
        return Colors.orange;
      case PaymentStatus.rejected:
        return Colors.red;
    }
  }

  String _statusLabel(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.approved:
        return 'Approved';
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.rejected:
        return 'Rejected';
    }
  }

  String _methodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.online:
        return 'Online';
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No recent activity',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: items.map((item) {
              final p = item.payment;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _statusColor(p.status)
                            .withValues(alpha: 0.15),
                        child: Icon(
                          Icons.payment,
                          color: _statusColor(p.status),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currency.format(p.amount),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.memberName} \u2022 ${_methodLabel(p.method)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _statusLabel(p.status),
                              style: TextStyle(
                                fontSize: 12,
                                color: _statusColor(p.status),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        dateFormat.format(p.createdAt),
                        style: TextStyle(
                          fontSize: 11,
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
  }
}

class _QuickActionsRow extends ConsumerWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final membersAsync = ref.watch(membersStreamProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            QuickActionButton(
              icon: Icons.add,
              label: 'Record Cash Payment',
              isPrimary: true,
              onPressed: () {},
            ),
            QuickActionButton(
              icon: Icons.verified,
              label: 'Verify Payments',
              onPressed: () {},
            ),
            QuickActionButton(
              icon: Icons.assignment,
              label: 'Create Levy',
              onPressed: () {
                final currentUser = authState.valueOrNull;
                final memberIds = membersAsync.valueOrNull?.map((m) => m.userId).toList() ?? [];
                if (currentUser != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateLevyScreen(
                        creatorId: currentUser.uid,
                        memberIds: memberIds,
                      ),
                    ),
                  );
                }
              },
            ),
            QuickActionButton(
              icon: Icons.money_off,
              label: 'Add Expense',
              onPressed: () {},
            ),
          ],
        ),
      ],
    );
  }
}
