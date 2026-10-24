// features/dashboard/views/treasurer_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/core/theme/app_theme.dart';
import 'package:cls/core/widgets/quick_action_button.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/dashboard/widgets/dashboard_app_bar_actions.dart';
import 'package:cls/features/dashboard/widgets/dashboard_tab_pop_scope.dart';
import 'package:cls/features/dashboard/controllers/treasurer_dashboard_provider.dart';
import 'package:cls/features/dashboard/controllers/member_dashboard_provider.dart'
    show memberTotalOutstandingProvider, memberObligationReconciliationProvider;
import 'package:cls/features/obligations/controllers/obligation_provider.dart';
import 'package:cls/features/levies/controllers/levy_provider.dart'
    hide obligationRepositoryProvider;
import 'package:cls/features/levies/views/create_levy_screen.dart';
import 'package:cls/features/members/views/treasurer_member_detail_screen.dart';
import 'package:cls/features/expenses/controllers/expense_provider.dart';
import 'package:cls/features/expenses/views/expense_form_screen.dart';
import 'package:cls/features/expenses/views/expense_list_screen.dart';
import 'package:cls/features/reports/views/reports_screen.dart';
import 'package:cls/features/dashboard/views/member_dashboard.dart';
import 'package:cls/features/admin/widgets/receiving_account_details_dialog.dart';
import 'package:cls/features/payments/views/cash_payment_screen.dart';
import 'package:cls/features/payments/views/payment_verification_screen.dart';
import 'package:cls/features/payments/views/make_payment_screen.dart';
import 'package:cls/features/payments/models/payment_model.dart';

class TreasurerDashboard extends ConsumerStatefulWidget {
  const TreasurerDashboard({super.key});

  @override
  ConsumerState<TreasurerDashboard> createState() => _TreasurerDashboardState();
}

class _TreasurerDashboardState extends ConsumerState<TreasurerDashboard> {
  int _selectedIndex = 0;

  void _onNavigate(int index) {
    setState(() => _selectedIndex = index);
  }

  String _appBarTitle(int index) {
    switch (index) {
      case 0:
        return 'Treasurer Dashboard';
      case 1:
        return 'Expenses & Disbursements';
      case 2:
        return 'Collections & Verifications';
      case 3:
        return 'Members & Debtors';
      case 4:
        return 'My Account';
      default:
        return 'Treasurer Dashboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(body: Center(child: Text('Please sign in')));
        }

        final pages = <Widget>[
          _HomeTab(user: user, onNavigate: _onNavigate),
          ExpenseListScreen(
            currentUserId: user.uid,
            isExecutive: true,
            organizationId: user.organizationId,
          ),
          _TreasurerCollectionsTab(user: user),
          _TreasurerMembersTab(user: user),
          const MemberDashboard(),
        ];

        return DashboardTabPopScope(
          selectedIndex: _selectedIndex,
          onSelectTab: (index) => setState(() => _selectedIndex = index),
          child: Scaffold(
            appBar: (_selectedIndex == 1 || _selectedIndex == 4)
                ? null
                : AppBar(
                    title: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(_appBarTitle(_selectedIndex)),
                    ),
                    actions: [
                      DashboardAppBarActions(
                        user: user,
                        extraActions: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.assessment_outlined,
                              color: AppTheme.brandGreen,
                            ),
                            tooltip: 'Financial Reports',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ReportsScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                        onRefresh: () async {
                          ref.invalidate(allPaymentsStreamProvider);
                          ref.invalidate(allObligationsProvider);
                          ref.invalidate(activeLeviesProvider);
                          ref.invalidate(expensesStreamProvider);
                          ref.invalidate(membersStreamProvider);
                          ref.invalidate(treasurerDashboardProvider);
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
                icon: Icon(Icons.verified_outlined),
                activeIcon: Icon(Icons.verified),
                label: 'Collections',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.people_outline),
                activeIcon: Icon(Icons.people),
                label: 'Members',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet_outlined),
                activeIcon: Icon(Icons.account_balance_wallet),
                label: 'My Account',
              ),
            ],
          ),
        ),
      );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: Center(
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
}

// ---------------------------------------------------------------------------
// 1. Overview / Home Tab
// ---------------------------------------------------------------------------
class _HomeTab extends ConsumerWidget {
  final UserModel user;
  final void Function(int) onNavigate;

  const _HomeTab({required this.user, required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(treasurerDashboardProvider);
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final dateFormat = DateFormat('MMM dd, yyyy \u2022 HH:mm');
    final theme = Theme.of(context);

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
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          children: [
            // Welcome Header
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.15,
                    ),
                    child: Icon(Icons.shield, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, ${user.displayName.isNotEmpty ? user.displayName : 'Treasurer'}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Treasurer',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      DateFormat('MMM yyyy').format(DateTime.now()),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Personal Member Status Card (Every member is a member!)
            _PersonalMemberStatusBanner(
              user: user,
              currency: currency,
              onNavigateToMyAccount: () => onNavigate(4),
            ),
            const SizedBox(height: 16),

            // Pending Payments Alert (if any require verification)
            if (data.totalPending > 0) ...[
              _PendingVerificationsBanner(
                totalPending: data.totalPending,
                currency: currency,
                onVerify: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PaymentVerificationScreen(verifiedBy: user.uid),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],

            // KPI Overview Cards
            _OverviewCards(
              data: data,
              currency: currency,
              user: user,
              onNavigate: onNavigate,
            ),
            const SizedBox(height: 20),

            // Members in Arrears
            _MemberArrearsSection(
              arrears: data.memberArrears,
              currency: currency,
              onSeeAll: () => onNavigate(3),
            ),
            const SizedBox(height: 20),

            // Levy Collection Progress
            _LevyCollectionSection(
              levies: data.levyCollection,
              currency: currency,
            ),
            const SizedBox(height: 20),

            // Recent Payment Activity
            _RecentActivitySection(
              items: data.recentPayments,
              currency: currency,
              dateFormat: dateFormat,
              onViewAll: () => onNavigate(2),
            ),
            const SizedBox(height: 20),

            // Quick Actions Row
            _QuickActionsRow(user: user, onNavigate: onNavigate),
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

// ---------------------------------------------------------------------------
// Personal Member Status Banner
// ---------------------------------------------------------------------------
class _PersonalMemberStatusBanner extends ConsumerWidget {
  final UserModel user;
  final NumberFormat currency;
  final VoidCallback onNavigateToMyAccount;

  const _PersonalMemberStatusBanner({
    required this.user,
    required this.currency,
    required this.onNavigateToMyAccount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(memberObligationReconciliationProvider(user.uid));
    final outstandingAsync = ref.watch(
      memberTotalOutstandingProvider(user.uid),
    );
    final theme = Theme.of(context);

    return outstandingAsync.when(
      data: (outstanding) {
        final owes = outstanding > 0;
        final cardColor = owes
            ? Colors.amber.shade50.withValues(alpha: 0.8)
            : Colors.green.shade50.withValues(alpha: 0.7);
        final borderColor = owes
            ? Colors.amber.shade300
            : Colors.green.shade200;
        final iconColor = owes ? Colors.amber.shade900 : Colors.green.shade800;

        return Card(
          elevation: 0,
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor, width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: owes
                            ? Colors.amber.shade100
                            : Colors.green.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person, color: iconColor, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Personal Member Status',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: iconColor,
                            ),
                          ),
                          Text(
                            owes
                                ? 'You have unpaid personal dues / levies'
                                : 'All personal obligations are up to date',
                            style: TextStyle(
                              fontSize: 11,
                              color: owes
                                  ? Colors.amber.shade900
                                  : Colors.green.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: owes
                            ? Colors.amber.shade800
                            : Colors.green.shade700,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        owes ? 'OWING' : 'CLEARED',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final duesInfo = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Your Outstanding Dues',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          currency.format(outstanding),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: owes
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                          ),
                        ),
                      ],
                    );

                    final buttonGroup = Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: onNavigateToMyAccount,
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          child: const Text(
                            'My Account',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        if (owes) ...[
                          OutlinedButton.icon(
                            onPressed: () =>
                                _showClearPastDuesDialog(context, ref),
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 14,
                            ),
                            label: const Text(
                              'Paid Offline',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: Colors.green.shade800,
                              side: BorderSide(color: Colors.green.shade600),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MakePaymentScreen(
                                    memberId: user.uid,
                                    memberEmail: user.email,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.payment, size: 14),
                            label: const Text(
                              'Pay Dues',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );

                    if (constraints.maxWidth < 360) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          duesInfo,
                          const SizedBox(height: 8),
                          buttonGroup,
                        ],
                      );
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: duesInfo),
                        buttonGroup,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Future<void> _showClearPastDuesDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified, color: Colors.green),
            SizedBox(width: 8),
            Expanded(child: Text('Clear Historical Dues?')),
          ],
        ),
        content: const Text(
          'If you are an existing member who already paid all past dues and levies offline, '
          'confirming will mark your existing obligations as cleared (₦0.00 outstanding balance).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Confirm Cleared',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repo = ref.read(obligationRepositoryProvider);
        await repo.clearMemberHistoricalObligations(user.uid);
        ref.invalidate(memberTotalOutstandingProvider(user.uid));
        ref.invalidate(memberObligationReconciliationProvider(user.uid));
        ref.invalidate(allObligationsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green.shade700,
              content: const Text(
                'Historical obligations successfully marked as cleared (₦0.00 outstanding).',
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade700,
              content: Text('Failed to clear obligations: $e'),
            ),
          );
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Pending Verifications Banner
// ---------------------------------------------------------------------------
class _PendingVerificationsBanner extends StatelessWidget {
  final double totalPending;
  final NumberFormat currency;
  final VoidCallback onVerify;

  const _PendingVerificationsBanner({
    required this.totalPending,
    required this.currency,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade300, width: 1.2),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.hourglass_top,
              color: Colors.orange.shade900,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pending Verifications',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.orange.shade900,
                  ),
                ),
                Text(
                  '${currency.format(totalPending)} awaiting your confirmation',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onVerify,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('Verify Now', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overview KPI Cards
// ---------------------------------------------------------------------------
class _OverviewCards extends StatelessWidget {
  final TreasurerDashboardData data;
  final NumberFormat currency;
  final UserModel user;
  final void Function(int) onNavigate;

  const _OverviewCards({
    required this.data,
    required this.currency,
    required this.user,
    required this.onNavigate,
  });

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
            onTap: () => onNavigate(2),
          ),
          const SizedBox(width: 12),
          _OverviewCard(
            label: 'Total Expenses',
            value: currency.format(data.expenseTotal),
            icon: Icons.receipt_long,
            color: Colors.purple,
            onTap: () => onNavigate(1),
          ),
          const SizedBox(width: 12),
          _OverviewCard(
            label: 'Net Position',
            value: currency.format(data.netPosition),
            icon: Icons.account_balance,
            color: theme.colorScheme.primary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportsScreen()),
              );
            },
          ),
          const SizedBox(width: 12),
          _OverviewCard(
            label: 'Total Outstanding',
            value: currency.format(data.totalOutstanding),
            icon: Icons.pending,
            color: Colors.redAccent,
            onTap: () => onNavigate(3),
          ),
          const SizedBox(width: 12),
          _OverviewCard(
            label: 'Pending Payments',
            value: currency.format(data.totalPending),
            icon: Icons.hourglass_top,
            color: Colors.orange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PaymentVerificationScreen(verifiedBy: user.uid),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          _OverviewCard(
            label: 'Total Registered Members',
            value: data.totalMembers.toString(),
            icon: Icons.people,
            color: Colors.blue,
            onTap: () => onNavigate(3),
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
  final VoidCallback? onTap;

  const _OverviewCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final card = SizedBox(
      width: 180,
      child: Card(
        color: color.withValues(alpha: 0.06),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(10),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 14),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: card,
    );
  }
}

// ---------------------------------------------------------------------------
// Members in Arrears Section
// ---------------------------------------------------------------------------
class _MemberArrearsSection extends StatelessWidget {
  final List<MemberArrears> arrears;
  final NumberFormat currency;
  final VoidCallback onSeeAll;

  const _MemberArrearsSection({
    required this.arrears,
    required this.currency,
    required this.onSeeAll,
  });

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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton(onPressed: onSeeAll, child: const Text('See All')),
          ],
        ),
        const SizedBox(height: 8),
        if (arrears.isEmpty)
          Card(
            color: Colors.grey.shade50,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 8),
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
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        child: Text(
                          a.memberName.isNotEmpty ? a.memberName[0] : '?',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.memberName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${a.unpaidCount} unpaid obligation${a.unpaidCount == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Text(
                          currency.format(a.totalOutstanding),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
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

// ---------------------------------------------------------------------------
// Levy Collection Section
// ---------------------------------------------------------------------------
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
            color: Colors.grey.shade50,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 8),
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

// ---------------------------------------------------------------------------
// Recent Activity Section
// ---------------------------------------------------------------------------
class _RecentActivitySection extends StatelessWidget {
  final List<RecentPaymentItem> items;
  final NumberFormat currency;
  final DateFormat dateFormat;
  final VoidCallback onViewAll;

  const _RecentActivitySection({
    required this.items,
    required this.currency,
    required this.dateFormat,
    required this.onViewAll,
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton(onPressed: onViewAll, child: const Text('View All')),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Card(
            color: Colors.grey.shade50,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 8),
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
                        backgroundColor: _statusColor(
                          p.status,
                        ).withValues(alpha: 0.15),
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
                            Container(
                              decoration: BoxDecoration(
                                color: _statusColor(
                                  p.status,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              child: Text(
                                _statusLabel(p.status),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _statusColor(p.status),
                                ),
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

// ---------------------------------------------------------------------------
// Quick Actions Row
// ---------------------------------------------------------------------------
class _QuickActionsRow extends ConsumerWidget {
  final UserModel user;
  final void Function(int) onNavigate;

  const _QuickActionsRow({required this.user, required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersStreamProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CashPaymentScreen(
                      recordedBy: user.displayName.isNotEmpty
                          ? user.displayName
                          : 'Treasurer',
                    ),
                  ),
                );
              },
            ),
            QuickActionButton(
              icon: Icons.verified,
              label: 'Verify Payments',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PaymentVerificationScreen(verifiedBy: user.uid),
                  ),
                );
              },
            ),
            QuickActionButton(
              icon: Icons.assignment,
              label: 'Create Levy',
              onPressed: () {
                final memberIds =
                    membersAsync.valueOrNull?.map((m) => m.id).toList() ?? [];
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateLevyScreen(
                      creatorId: user.uid,
                      memberIds: memberIds,
                    ),
                  ),
                );
              },
            ),
            QuickActionButton(
              icon: Icons.money_off,
              label: 'Add Expense',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExpenseFormScreen(
                      currentUserId: user.uid,
                      organizationId: user.organizationId,
                    ),
                  ),
                );
              },
            ),
            QuickActionButton(
              icon: Icons.receipt_long,
              label: 'View Expenses',
              onPressed: () => onNavigate(1),
            ),
            QuickActionButton(
              icon: Icons.assessment_outlined,
              label: 'Financial Reports',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportsScreen()),
                );
              },
            ),
            QuickActionButton(
              icon: Icons.account_balance,
              label: 'Receiving Account',
              onPressed: () {
                ReceivingAccountDetailsDialog.show(context);
              },
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Collections & Verification Tab
// ---------------------------------------------------------------------------
class _TreasurerCollectionsTab extends ConsumerStatefulWidget {
  final UserModel user;
  const _TreasurerCollectionsTab({required this.user});

  @override
  ConsumerState<_TreasurerCollectionsTab> createState() =>
      _TreasurerCollectionsTabState();
}

class _TreasurerCollectionsTabState
    extends ConsumerState<_TreasurerCollectionsTab> {
  String _filter = 'All';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _methodColor(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.online:
        return Colors.blue;
      case PaymentMethod.cash:
        return Colors.green;
      case PaymentMethod.bankTransfer:
        return Colors.deepPurple;
    }
  }

  IconData _methodIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.online:
        return Icons.credit_card;
      case PaymentMethod.cash:
        return Icons.money;
      case PaymentMethod.bankTransfer:
        return Icons.account_balance;
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
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final paymentsAsync = ref.watch(allPaymentsStreamProvider);
    final membersAsync = ref.watch(membersStreamProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'treasurer_collections_fab',
        icon: const Icon(Icons.add),
        label: const Text('Record Cash'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CashPaymentScreen(
                recordedBy: widget.user.displayName.isNotEmpty
                    ? widget.user.displayName
                    : 'Treasurer',
              ),
            ),
          );
        },
      ),
      body: paymentsAsync.when(
        data: (payments) {
          final members = membersAsync.valueOrNull ?? [];
          final memberMap = <String, String>{};
          for (final m in members) {
            memberMap[m.id] = m.fullName;
            if (m.userId.isNotEmpty) {
              memberMap[m.userId] = m.fullName;
            }
          }

          var filtered = payments;
          if (_filter == 'Pending') {
            filtered = filtered
                .where((p) => p.status == PaymentStatus.pending)
                .toList();
          } else if (_filter == 'Bank') {
            filtered = filtered
                .where((p) => p.method == PaymentMethod.bankTransfer)
                .toList();
          } else if (_filter == 'Cash') {
            filtered = filtered
                .where((p) => p.method == PaymentMethod.cash)
                .toList();
          } else if (_filter == 'Online') {
            filtered = filtered
                .where((p) => p.method == PaymentMethod.online)
                .toList();
          }

          final query = _searchController.text.trim().toLowerCase();
          if (query.isNotEmpty) {
            filtered = filtered.where((p) {
              final name = (memberMap[p.memberId] ?? p.memberName ?? '')
                  .toLowerCase();
              return name.contains(query) || p.id.toLowerCase().contains(query);
            }).toList();
          }

          final sortedPayments = List<PaymentModel>.from(filtered)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          final pendingCount = payments
              .where((p) => p.status == PaymentStatus.pending)
              .length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by member name or payment ID...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    for (final filter in [
                      'All',
                      'Pending',
                      'Bank',
                      'Cash',
                      'Online',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(
                            filter == 'Pending' && pendingCount > 0
                                ? 'Pending ($pendingCount)'
                                : filter,
                          ),
                          selected: _filter == filter,
                          selectedColor: filter == 'Pending'
                              ? Colors.orange.shade100
                              : null,
                          onSelected: (_) => setState(() => _filter = filter),
                        ),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.verified, size: 16),
                      label: const Text('Verify Queue'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PaymentVerificationScreen(
                              verifiedBy: widget.user.uid,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const Divider(height: 16),

              Expanded(
                child: sortedPayments.isEmpty
                    ? const Center(child: Text('No payments found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        itemCount: sortedPayments.length,
                        itemBuilder: (ctx, index) {
                          final payment = sortedPayments[index];
                          final memberName =
                              memberMap[payment.memberId] ??
                              (payment.memberName != null &&
                                      payment.memberName!.isNotEmpty
                                  ? payment.memberName!
                                  : 'Unknown Member');

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: _methodColor(
                                  payment.method,
                                ).withValues(alpha: 0.15),
                                child: Icon(
                                  _methodIcon(payment.method),
                                  color: _methodColor(payment.method),
                                ),
                              ),
                              title: Text(
                                memberName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_methodLabel(payment.method)} • ${DateFormat('MMM dd, yyyy • hh:mm a').format(payment.createdAt)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  if (payment.notes != null &&
                                      payment.notes!.isNotEmpty)
                                    Text(
                                      'Note: ${payment.notes}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    currency.format(payment.amount),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _StatusBadge(status: payment.status),
                                ],
                              ),
                              onTap: () {
                                if (payment.status == PaymentStatus.pending) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PaymentVerificationScreen(
                                        verifiedBy: widget.user.uid,
                                      ),
                                    ),
                                  );
                                } else {
                                  _showPaymentDetailsDialog(
                                    context,
                                    payment,
                                    memberName,
                                    currency,
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showPaymentDetailsDialog(
    BuildContext context,
    PaymentModel payment,
    String memberName,
    NumberFormat currency,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Payment Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Member'),
              subtitle: Text(
                memberName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Amount'),
              subtitle: Text(
                currency.format(payment.amount),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Method'),
              subtitle: Text(_methodLabel(payment.method)),
            ),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(
                DateFormat('MMM dd, yyyy • hh:mm a').format(payment.createdAt),
              ),
            ),
            if (payment.paystackReference != null &&
                payment.paystackReference!.isNotEmpty)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Reference'),
                subtitle: Text(payment.paystackReference!),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Members & Debtors Tab
// ---------------------------------------------------------------------------
class _TreasurerMembersTab extends ConsumerStatefulWidget {
  final UserModel user;
  const _TreasurerMembersTab({required this.user});

  @override
  ConsumerState<_TreasurerMembersTab> createState() =>
      _TreasurerMembersTabState();
}

class _TreasurerMembersTabState extends ConsumerState<_TreasurerMembersTab> {
  final TextEditingController _searchController = TextEditingController();
  bool _owingOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final membersAsync = ref.watch(membersStreamProvider);
    final dashboardAsync = ref.watch(treasurerDashboardProvider);

    final totalOutstanding =
        dashboardAsync.valueOrNull?.totalOutstanding ?? 0.0;
    final arrearsList = dashboardAsync.valueOrNull?.memberArrears ?? [];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search member by name or email...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),

        // Summary bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${arrearsList.length} in arrears \u2022 Total: ${currency.format(totalOutstanding)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                    fontSize: 13,
                  ),
                ),
              ),
              FilterChip(
                label: const Text(
                  'Debtors Only',
                  style: TextStyle(fontSize: 12),
                ),
                selected: _owingOnly,
                onSelected: (val) => setState(() => _owingOnly = val),
              ),
            ],
          ),
        ),

        Expanded(
          child: membersAsync.when(
            data: (members) {
              final query = _searchController.text.trim().toLowerCase();

              // Build map of member arrears for fast lookup
              final arrearsMap = <String, MemberArrears>{};
              for (final a in arrearsList) {
                arrearsMap[a.memberId] = a;
              }

              var filtered = members.where((m) {
                final matchQuery =
                    query.isEmpty ||
                    m.fullName.toLowerCase().contains(query) ||
                    m.email.toLowerCase().contains(query);
                if (!matchQuery) return false;

                if (_owingOnly) {
                  return arrearsMap.containsKey(m.id) ||
                      arrearsMap.containsKey(m.userId);
                }
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Text(
                    'No members found',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final member = filtered[index];
                  final arrears =
                      arrearsMap[member.id] ?? arrearsMap[member.userId];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          member.fullName.isNotEmpty ? member.fullName[0] : '?',
                        ),
                      ),
                      title: Text(
                        member.fullName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        member.email.isNotEmpty
                            ? member.email
                            : 'Joined member',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (arrears != null && arrears.totalOutstanding > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Owes ${currency.format(arrears.totalOutstanding)}',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else
                            _MemberOwingBadge(
                              memberId: member.userId.isNotEmpty
                                  ? member.userId
                                  : member.id,
                              currency: currency,
                            ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, size: 20),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TreasurerMemberDetailScreen(
                              memberId: member.userId.isNotEmpty
                                  ? member.userId
                                  : member.id,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
class _MemberOwingBadge extends ConsumerWidget {
  final String memberId;
  final NumberFormat currency;

  const _MemberOwingBadge({required this.memberId, required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obligationsAsync = ref.watch(
      memberActiveObligationsProvider(memberId),
    );
    return obligationsAsync.when(
      data: (obligations) {
        final totalOwed = obligations.fold<double>(
          0.0,
          (sum, o) => sum + o.outstandingBalance,
        );
        if (totalOwed <= 0) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'No Dues',
              style: TextStyle(
                color: Colors.green,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Owes ${currency.format(totalOwed)}',
            style: const TextStyle(
              color: Colors.red,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final PaymentStatus status;
  const _StatusBadge({required this.status});

  Color _color() {
    switch (status) {
      case PaymentStatus.approved:
        return Colors.green;
      case PaymentStatus.pending:
        return Colors.orange;
      case PaymentStatus.rejected:
        return Colors.red;
    }
  }

  String _label() {
    switch (status) {
      case PaymentStatus.approved:
        return 'Approved';
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.rejected:
        return 'Rejected';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _label(),
        style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
