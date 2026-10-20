// features/dashboard/views/president_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/core/widgets/quick_action_button.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/auth/views/login_screen.dart';
import 'package:cls/features/dashboard/controllers/president_dashboard_provider.dart';
import 'package:cls/features/dashboard/views/member_dashboard.dart';
import 'package:cls/features/expenses/controllers/expense_provider.dart';
import 'package:cls/features/expenses/models/expense_model.dart';
import 'package:cls/features/expenses/views/expense_list_screen.dart';
import 'package:cls/features/levies/controllers/levy_provider.dart'
    hide obligationRepositoryProvider;
import 'package:cls/features/meetings/controllers/meeting_provider.dart';
import 'package:cls/features/meetings/views/meeting_detail_screen.dart';
import 'package:cls/features/members/views/treasurer_member_detail_screen.dart';
import 'package:cls/features/obligations/controllers/obligation_provider.dart';
import 'package:cls/features/reports/views/reports_screen.dart';
import 'package:cls/features/secretary/views/announcements_screen.dart';
import 'package:cls/features/secretary/views/attendance_screen.dart';
import 'package:cls/features/secretary/views/calendar_screen.dart';
import 'package:cls/features/secretary/views/documents_screen.dart';
import 'package:cls/features/settings/views/settings_screen.dart';
import 'package:cls/features/dashboard/widgets/executive_approval_queue_card.dart';
import 'package:cls/features/notifications/controllers/notification_provider.dart';
import 'package:cls/features/notifications/views/notifications_screen.dart';

class PresidentDashboard extends ConsumerStatefulWidget {
  const PresidentDashboard({super.key});

  @override
  ConsumerState<PresidentDashboard> createState() => _PresidentDashboardState();
}

class _PresidentDashboardState extends ConsumerState<PresidentDashboard> {
  int _selectedIndex = 0;

  void _onNavigate(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please sign in')));
    }

    final pages = <Widget>[
      _HomeTab(user: user, onNavigate: _onNavigate),
      ExpenseListScreen(currentUserId: user.uid),
      const _PresidentMeetingsTab(),
      const _PresidentMembersTab(),
      const MemberDashboard(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle(_selectedIndex)),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: ref.watch(unreadCountProvider) > 0,
              label: Text('${ref.watch(unreadCountProvider)}'),
              child: const Icon(Icons.notifications_outlined),
            ),
            tooltip: 'Notifications',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NotificationsScreen(currentUser: user),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(presidentAllPaymentsStreamProvider);
              ref.invalidate(allObligationsProvider);
              ref.invalidate(activeLeviesProvider);
              ref.invalidate(presidentExpensesStreamProvider);
              ref.invalidate(presidentMembersStreamProvider);
              ref.invalidate(presidentDashboardProvider);
              ref.invalidate(meetingsStreamProvider);
              ref.invalidate(expensesStreamProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
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
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Expenses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_outlined),
            activeIcon: Icon(Icons.event),
            label: 'Meetings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Members',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'My Dues',
          ),
        ],
      ),
    );
  }

  String _appBarTitle(int index) {
    switch (index) {
      case 0:
        return 'President Dashboard';
      case 1:
        return 'Expenses & Requisitions';
      case 2:
        return 'Meetings & Governance';
      case 3:
        return 'Members Directory';
      case 4:
        return 'My Personal Dues';
      default:
        return 'President';
    }
  }
}

// ============================================================================
// TAB 1: EXECUTIVE HOME / OVERVIEW
// ============================================================================
class _HomeTab extends ConsumerWidget {
  final UserModel user;
  final ValueChanged<int> onNavigate;

  const _HomeTab({required this.user, required this.onNavigate});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(presidentDashboardProvider);
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final dateFormat = DateFormat('MMM dd, yyyy');
    final theme = Theme.of(context);

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
            // Welcome Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primaryContainer,
                    theme.colorScheme.surfaceContainerHighest,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: theme.colorScheme.primary,
                    child: const Icon(
                      Icons.shield,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_greeting()}, ${user.displayName.isNotEmpty ? user.displayName : 'President'}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Chief Executive',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('EEEE, MMM d').format(DateTime.now()),
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Pending Member Registration Approvals
            ExecutiveApprovalQueueCard(organizationId: user.organizationId),

            // Executive Quick Actions
            Text(
              'Executive Quick Actions',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: QuickActionButton(
                    icon: Icons.receipt_long,
                    label: 'Expenses',
                    iconSize: 16,
                    fontSize: 11,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                    onPressed: () => onNavigate(1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: QuickActionButton(
                    icon: Icons.event,
                    label: 'Meetings',
                    iconSize: 16,
                    fontSize: 11,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                    onPressed: () => onNavigate(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: QuickActionButton(
                    icon: Icons.people,
                    label: 'Members',
                    iconSize: 16,
                    fontSize: 11,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                    onPressed: () => onNavigate(3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: QuickActionButton(
                    icon: Icons.insert_chart_outlined,
                    label: 'Reports',
                    iconSize: 16,
                    fontSize: 11,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ReportsScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: QuickActionButton(
                    icon: Icons.fact_check_outlined,
                    label: 'Attendance',
                    iconSize: 16,
                    fontSize: 11,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AttendanceScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: QuickActionButton(
                    icon: Icons.campaign_outlined,
                    label: 'Notices',
                    iconSize: 16,
                    fontSize: 11,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AnnouncementsScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Treasury Overview Cards
            Text(
              'Treasury & Membership Health',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _ExecutiveOverviewCards(data: data, currency: currency),
            const SizedBox(height: 24),

            // Active Levies & Projects Section
            _ActiveLeviesSection(
              levies: data.activeLeviesSummary,
              currency: currency,
            ),
            const SizedBox(height: 24),

            // Revenue Channels Chart
            _CollectionsByMethodChart(data: data),
            const SizedBox(height: 24),

            // Recent Expenses Section
            _RecentExpensesSection(
              expenses: data.recentExpenses,
              currency: currency,
              dateFormat: dateFormat,
              onViewAll: () => onNavigate(1),
            ),
            const SizedBox(height: 24),

            // Governance & Secretariat Section
            _GovernanceSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Failed to load dashboard: $error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(presidentDashboardProvider),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// EXECUTIVE OVERVIEW CARDS (Grid)
// ----------------------------------------------------------------------------
class _ExecutiveOverviewCards extends StatelessWidget {
  final PresidentDashboardData data;
  final NumberFormat currency;

  const _ExecutiveOverviewCards({required this.data, required this.currency});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.22,
      children: [
        _MetricCard(
          label: 'Total Collections',
          value: currency.format(data.totalCollections),
          icon: Icons.payments,
          color: Colors.green,
        ),
        _MetricCard(
          label: 'Total Disbursed',
          value: currency.format(data.totalExpenses),
          icon: Icons.receipt_long,
          color: Colors.redAccent,
        ),
        _MetricCard(
          label: 'Net Balance',
          value: currency.format(data.netPosition),
          icon: Icons.account_balance,
          color: theme.colorScheme.primary,
        ),
        _MetricCard(
          label: 'Total Members',
          value: data.totalMembers.toString(),
          icon: Icons.people,
          color: Colors.deepPurple,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// ACTIVE LEVIES & PROJECTS SECTION
// ----------------------------------------------------------------------------
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Active Levies & Projects',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${levies.length} Active',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (levies.isEmpty)
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 40,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No active levies or special projects',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Column(
            children: levies.map((l) {
              final pct = (l.percentage * 100).toInt();
              return Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.35,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.only(bottom: 10),
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$pct%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Collected: ${currency.format(l.totalCollected)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                          Text(
                            'Target: ${currency.format(l.totalTarget)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
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

// ----------------------------------------------------------------------------
// REVENUE CHANNELS (PIE CHART)
// ----------------------------------------------------------------------------
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
        return 'Online (Paystack)';
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
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revenue by Payment Method',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (!hasData)
              const SizedBox(
                height: 140,
                child: Center(
                  child: Text(
                    'No payment collection records yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Row(
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 28,
                        sections: PaymentMethod.values.map((method) {
                          final value = methodData[method] ?? 0.0;
                          return PieChartSectionData(
                            value: value,
                            showTitle: false,
                            color: _methodColor(method, theme),
                            radius: 36,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: PaymentMethod.values.map((method) {
                        final val = methodData[method] ?? 0.0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _methodColor(method, theme),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _methodLabel(method),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Text(
                                currency.format(val),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// RECENT EXPENSES PREVIEW
// ----------------------------------------------------------------------------
class _RecentExpensesSection extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final NumberFormat currency;
  final DateFormat dateFormat;
  final VoidCallback onViewAll;

  const _RecentExpensesSection({
    required this.expenses,
    required this.currency,
    required this.dateFormat,
    required this.onViewAll,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = expenses.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Disbursed Expenses',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: onViewAll,
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (preview.isEmpty)
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No expenses recorded yet',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          )
        else
          Column(
            children: preview.map((expense) {
              return Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.35,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
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
                  title: Text(
                    expense.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    dateFormat.format(expense.expenseDate),
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Text(
                    currency.format(expense.amount),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.red.shade700,
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

// ----------------------------------------------------------------------------
// GOVERNANCE & TOOLS SECTION
// ----------------------------------------------------------------------------
class _GovernanceSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Executive Governance & Documents',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  Icons.folder_special_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Official Documents & Constitution'),
                subtitle: const Text('By-laws, resolutions, and archive files'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DocumentsScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(
                  Icons.calendar_month_outlined,
                  color: Colors.blue,
                ),
                title: const Text('Organizational Calendar'),
                subtitle: const Text('Scheduled dates, deadlines, and events'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CalendarScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(
                  Icons.settings_outlined,
                  color: Colors.blueGrey,
                ),
                title: const Text('Executive Settings'),
                subtitle: const Text('Preferences and app settings'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// TAB 3: MEETINGS & GOVERNANCE
// ============================================================================
class _PresidentMeetingsTab extends ConsumerWidget {
  const _PresidentMeetingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetingsAsync = ref.watch(meetingsStreamProvider);
    final dateFormat = DateFormat('EEEE, MMM dd, yyyy \u2022 hh:mm a');
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_call_meeting',
        icon: const Icon(Icons.add),
        label: const Text('Call Meeting'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const MeetingDetailScreen(),
            ),
          );
        },
      ),
      body: meetingsAsync.when(
        data: (meetings) {
          final withMinutes = meetings.where((m) => m.hasMinutes).length;

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(meetingsStreamProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MeetingSummaryCard(
                        title: 'Total Meetings',
                        value: meetings.length.toString(),
                        icon: Icons.event,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MeetingSummaryCard(
                        title: 'Recorded Minutes',
                        value: withMinutes.toString(),
                        icon: Icons.description,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Meeting Sessions & Minutes',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                if (meetings.isEmpty)
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.35,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_busy_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No meetings scheduled yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Tap "Call Meeting" below to summon members for a new session.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: meetings.map((meeting) {
                      return Card(
                        elevation: 0,
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    MeetingDetailScreen(meeting: meeting),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        meeting.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: meeting.hasMinutes
                                            ? Colors.green.withValues(alpha: 0.15)
                                            : Colors.orange.withValues(
                                                alpha: 0.15,
                                              ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        meeting.hasMinutes
                                            ? 'Minutes Available'
                                            : 'No Minutes Yet',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: meeting.hasMinutes
                                              ? Colors.green.shade800
                                              : Colors.orange.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 14,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      dateFormat.format(meeting.meetingDate),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                if (meeting.venue.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on_outlined,
                                        size: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          meeting.venue,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Review Meeting Details',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 12,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 60),
              ],
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
}

class _MeetingSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MeetingSummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TAB 4: MEMBERS DIRECTORY
// ============================================================================
class _PresidentMembersTab extends ConsumerStatefulWidget {
  const _PresidentMembersTab();

  @override
  ConsumerState<_PresidentMembersTab> createState() =>
      _PresidentMembersTabState();
}

class _PresidentMembersTabState extends ConsumerState<_PresidentMembersTab> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(presidentMembersStreamProvider);
    final dateFormat = DateFormat('MMM d, yyyy');
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search members by name or email...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (val) {
                setState(() => _query = val.trim().toLowerCase());
              },
            ),
          ),
          Expanded(
            child: membersAsync.when(
              data: (members) {
                final filtered = _query.isEmpty
                    ? members
                    : members.where((m) {
                        return m.fullName.toLowerCase().contains(_query) ||
                            m.email.toLowerCase().contains(_query);
                      }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No members matching your search',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(presidentMembersStreamProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final member = filtered[index];
                      return Card(
                        elevation: 0,
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Text(
                              member.fullName.isNotEmpty
                                  ? member.fullName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          title: Text(
                            member.fullName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Joined ${dateFormat.format(member.joinedDate)} \u2022 ${member.phoneNumber.isNotEmpty ? member.phoneNumber : member.email}',
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TreasurerMemberDetailScreen(
                                  memberId: member.userId,
                                  isReadOnly: true,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  'Error loading members: $error',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
