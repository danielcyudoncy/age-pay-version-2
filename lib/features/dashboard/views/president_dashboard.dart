import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/expenses/models/expense_model.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/dashboard/controllers/president_dashboard_provider.dart';
import 'package:cls/features/obligations/controllers/obligation_provider.dart';
import 'package:cls/features/levies/controllers/levy_provider.dart'
    hide obligationRepositoryProvider;
import 'package:cls/features/dashboard/views/member_dashboard.dart';
import 'package:cls/features/reports/views/reports_screen.dart';
import 'package:cls/features/auth/views/login_screen.dart';

class PresidentDashboard extends ConsumerWidget {
  const PresidentDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('President Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'My Personal Dues',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MemberDashboard()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
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
    final dashboardAsync = ref.watch(presidentDashboardProvider);
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return dashboardAsync.when(
      data: (data) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(presidentAllPaymentsStreamProvider);
          ref.invalidate(allObligationsProvider);
          ref.invalidate(activeLeviesProvider);
          ref.invalidate(presidentExpensesStreamProvider);
          ref.invalidate(presidentMembersStreamProvider);
          ref.invalidate(presidentDashboardProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Welcome, ${ref.read(authProvider).valueOrNull?.displayName ?? 'President'}',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _OverviewCards(data: data, currency: currency),
            const SizedBox(height: 20),
            _MonthlyCollectionsChart(data: data),
            const SizedBox(height: 20),
            _CollectionsByMethodChart(data: data),
            const SizedBox(height: 20),
            _ActiveLeviesSection(
              levies: data.activeLeviesSummary,
              currency: currency,
            ),
            const SizedBox(height: 20),
            _RecentExpensesSection(
              expenses: data.recentExpenses,
              currency: currency,
              dateFormat: dateFormat,
            ),
            const SizedBox(height: 20),
            _ReportsAccessSection(),
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
              onPressed: () => ref.invalidate(presidentDashboardProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewCards extends StatelessWidget {
  final PresidentDashboardData data;
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
            label: 'Total Members',
            value: data.totalMembers.toString(),
            icon: Icons.people,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          _OverviewCard(
            label: 'Total Collections',
            value: currency.format(data.totalCollections),
            icon: Icons.paid,
            color: Colors.green,
          ),
          const SizedBox(width: 12),
          _OverviewCard(
            label: 'Total Outstanding',
            value: currency.format(data.totalOutstandingLevies),
            icon: Icons.pending,
            color: Colors.redAccent,
          ),
          const SizedBox(width: 12),
          _OverviewCard(
            label: 'Net Position',
            value: currency.format(data.netPosition),
            icon: Icons.account_balance,
            color: theme.colorScheme.tertiary,
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
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthlyCollectionsChart extends StatelessWidget {
  final PresidentDashboardData data;

  const _MonthlyCollectionsChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final summaries = data.memberCollectionSummary;
    final hasData = summaries.any((s) => s.totalAmount > 0);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Collections (Last 12 Months)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (!hasData)
              SizedBox(
                height: 200,
                child: Center(
                  child: Text(
                    'No collection data available',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: summaries.length,
                  itemBuilder: (context, index) {
                    final summary = summaries[index];
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  summary.fullName,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              Text(
                                currency.format(summary.totalAmount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (index < summaries.length - 1)
                          Divider(height: 1, color: Colors.grey.shade300),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CollectionsByMethodChart extends StatelessWidget {
  final PresidentDashboardData data;

  const _CollectionsByMethodChart({required this.data});

  Color _methodColor(PaymentMethod method, ThemeData theme) {
    switch (method) {
      case PaymentMethod.cash:
        return theme.colorScheme.primary;
      case PaymentMethod.online:
        return Colors.green;
      case PaymentMethod.bankTransfer:
        return Colors.orange;
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
    final theme = Theme.of(context);
    final methodData = data.collectionsByMethod;
    final hasData = methodData.values.any((v) => v > 0);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Collections by Method',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (!hasData)
              SizedBox(
                height: 200,
                child: Center(
                  child: Text(
                    'No collection data available',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              SizedBox(
                height: 220,
                child: Row(
                  children: [
                    Expanded(
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 36,
                          sections: PaymentMethod.values.map((method) {
                            final value = methodData[method] ?? 0.0;
                            return PieChartSectionData(
                              value: value,
                              title: value > 0 ? '₦${value.toInt()}' : '',
                              color: _methodColor(method, theme),
                              radius: 60,
                              titleStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: PaymentMethod.values.map((method) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _methodColor(method, theme),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _methodLabel(method),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActiveLeviesSection extends StatelessWidget {
  final List<ActiveLevySummary> levies;
  final NumberFormat currency;

  const _ActiveLeviesSection({required this.levies, required this.currency});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Levies',
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
                        '${currency.format(l.totalCollected)} / ${currency.format(l.totalTarget)}',
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

class _RecentExpensesSection extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final NumberFormat currency;
  final DateFormat dateFormat;

  const _RecentExpensesSection({
    required this.expenses,
    required this.currency,
    required this.dateFormat,
  });

  IconData _expenseIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.welfare:
        return Icons.favorite;
      case ExpenseCategory.projects:
        return Icons.build;
      case ExpenseCategory.events:
        return Icons.event;
      case ExpenseCategory.administration:
        return Icons.admin_panel_settings;
      case ExpenseCategory.miscellaneous:
        return Icons.category;
    }
  }

  Color _expenseColor(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.welfare:
        return Colors.pink;
      case ExpenseCategory.projects:
        return Colors.blue;
      case ExpenseCategory.events:
        return Colors.purple;
      case ExpenseCategory.administration:
        return Colors.teal;
      case ExpenseCategory.miscellaneous:
        return Colors.grey;
    }
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Expenses',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (expenses.isEmpty)
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
                    'No recent expenses',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: expenses.map((expense) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _expenseColor(
                      expense.category,
                    ).withValues(alpha: 0.15),
                    child: Icon(
                      _expenseIcon(expense.category),
                      color: _expenseColor(expense.category),
                      size: 18,
                    ),
                  ),
                  title: Text(expense.title),
                  subtitle: Text(
                    '${_categoryLabel(expense.category)} \u2022 ${dateFormat.format(expense.expenseDate)}',
                  ),
                  trailing: Text(
                    currency.format(expense.amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _ReportsAccessSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reports',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 2,
          child: ListTile(
            leading: Icon(
              Icons.insert_chart_outlined,
              color: theme.colorScheme.primary,
            ),
            title: const Text('View Reports'),
            subtitle: const Text('Access detailed financial reports'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ReportsScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
