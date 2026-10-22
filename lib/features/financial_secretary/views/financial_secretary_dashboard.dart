// features/financial_secretary/views/financial_secretary_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/core/widgets/quick_action_button.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/auth/views/login_screen.dart';
import 'package:cls/features/dashboard/views/member_dashboard.dart';
import 'package:cls/features/payments/views/cash_payment_screen.dart';
import 'package:cls/features/levies/views/create_levy_screen.dart';
import 'package:cls/features/obligations/views/treasurer_obligations_screen.dart';
import 'package:cls/features/members/views/treasurer_members_list_screen.dart';
import 'package:cls/features/reports/views/reports_screen.dart';
import 'package:cls/features/payments/controllers/offline_payment_provider.dart';
import 'package:cls/features/payments/models/payment_model.dart';
import 'package:cls/features/financial_secretary/controllers/financial_secretary_dashboard_provider.dart';
import 'package:cls/features/obligations/controllers/obligation_provider.dart'
    show allObligationsProvider;
import 'package:cls/features/levies/controllers/levy_provider.dart'
    show activeLeviesProvider;
import 'package:cls/features/dashboard/controllers/treasurer_dashboard_provider.dart'
    show allPaymentsStreamProvider, membersStreamProvider;

class FinancialSecretaryDashboard extends ConsumerStatefulWidget {
  const FinancialSecretaryDashboard({super.key});

  @override
  ConsumerState<FinancialSecretaryDashboard> createState() =>
      _FinancialSecretaryDashboardState();
}

class _FinancialSecretaryDashboardState
    extends ConsumerState<FinancialSecretaryDashboard> {
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
      _CollectionsTab(user: user),
      _DebtorsTab(user: user),
      const _LeviesTab(),
      const MemberDashboard(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Secretary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: () {
              ref.invalidate(allPaymentsStreamProvider);
              ref.invalidate(allObligationsProvider);
              ref.invalidate(activeLeviesProvider);
              ref.invalidate(membersStreamProvider);
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
            icon: Icon(Icons.payments_outlined),
            activeIcon: Icon(Icons.payments),
            label: 'Collections',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.money_off_outlined),
            activeIcon: Icon(Icons.money_off),
            label: 'Debtors',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'Levies',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'My Account',
          ),
        ],
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

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final dashboardAsync = ref.watch(financialSecretaryDashboardProvider);

    return dashboardAsync.when(
      data: (data) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(allPaymentsStreamProvider);
            ref.invalidate(allObligationsProvider);
            ref.invalidate(activeLeviesProvider);
            ref.invalidate(membersStreamProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // User Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.person,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          user.displayName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                            'Financial Secretary',
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
                ],
              ),
              const SizedBox(height: 20),

              // 4 Core Metric Cards
              Row(
                children: [
                  Expanded(
                    child: _FinStatCard(
                      label: 'Total Collected',
                      value: currency.format(data.totalCollected),
                      icon: Icons.account_balance_wallet,
                      color: theme.colorScheme.primary,
                      onTap: () => onNavigate(1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FinStatCard(
                      label: 'Outstanding Dues',
                      value: currency.format(data.totalOutstanding),
                      icon: Icons.pending_actions,
                      color: Colors.deepOrange,
                      onTap: () => onNavigate(2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _FinStatCard(
                      label: 'Cash in Hand',
                      value: currency.format(data.cashCollected),
                      icon: Icons.payments,
                      color: Colors.teal,
                      onTap: () => _showHandoverDetails(context, data, currency),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FinStatCard(
                      label: 'Pending Reviews',
                      value: data.pendingVerificationsCount.toString(),
                      icon: Icons.fact_check_outlined,
                      color: Colors.amber.shade800,
                      onTap: () => onNavigate(1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Cash Handover Banner (Separation of duties highlight!)
              Card(
                elevation: 0,
                color: Colors.teal.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.teal.withValues(alpha: 0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.sync_alt,
                              color: Colors.teal,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Cash Handover to Treasurer',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Text(
                            currency.format(data.cashCollected),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total physical cash collected from members. Reconcile this sum and hand over to the Treasurer with a signed voucher.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ChannelPill(
                              label: 'Cash',
                              amount: currency.format(data.cashCollected),
                              color: Colors.teal,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ChannelPill(
                              label: 'Bank Transfer',
                              amount: currency.format(data.bankCollected),
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ChannelPill(
                              label: 'Online',
                              amount: currency.format(data.onlineCollected),
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Quick Actions
              Text(
                'Financial Actions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  QuickActionButton(
                    icon: Icons.point_of_sale,
                    label: 'Record Cash',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CashPaymentScreen(
                            recordedBy: user.displayName.isNotEmpty
                                ? user.displayName
                                : 'Financial Secretary',
                          ),
                        ),
                      );
                    },
                  ),
                  QuickActionButton(
                    icon: Icons.add_circle_outline,
                    label: 'New Levy/Due',
                    onPressed: () {
                      final memberIds = ref
                              .read(membersStreamProvider)
                              .valueOrNull
                              ?.map((m) => m.id)
                              .toList() ??
                          [];
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
                    icon: Icons.assignment_outlined,
                    label: 'Obligations',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TreasurerObligationsScreen(),
                        ),
                      );
                    },
                  ),
                  QuickActionButton(
                    icon: Icons.people_outline,
                    label: 'Members Ledger',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TreasurerMembersListScreen(),
                        ),
                      );
                    },
                  ),
                  QuickActionButton(
                    icon: Icons.picture_as_pdf_outlined,
                    label: 'Reports',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ReportsScreen()),
                      );
                    },
                  ),
                  QuickActionButton(
                    icon: Icons.warning_amber_rounded,
                    label: 'Defaulters',
                    onPressed: () => onNavigate(2),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Top Defaulters Preview
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Top Defaulters (${data.memberArrears.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () => onNavigate(2),
                    child: const Text('View All'),
                  ),
                ],
              ),
              if (data.memberArrears.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'All members are fully up to date! 🎉',
                        style: TextStyle(color: theme.colorScheme.primary),
                      ),
                    ),
                  ),
                )
              else
                ...data.memberArrears.take(3).map((arrear) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.red.withValues(alpha: 0.1),
                        child: const Icon(
                          Icons.person_outline,
                          color: Colors.red,
                        ),
                      ),
                      title: Text(
                        arrear.memberName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('${arrear.unpaidCount} unpaid obligations'),
                      trailing: Text(
                        currency.format(arrear.totalOutstanding),
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      onTap: () => onNavigate(2),
                    ),
                  );
                }),
              const SizedBox(height: 20),

              // Recent Collections
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Collections',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () => onNavigate(1),
                    child: const Text('View All'),
                  ),
                ],
              ),
              if (data.recentPayments.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: Text('No payments recorded yet.')),
                  ),
                )
              else
                ...data.recentPayments.take(5).map((item) {
                  final payment = item.payment;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _methodColor(payment.method).withValues(
                          alpha: 0.1,
                        ),
                        child: Icon(
                          _methodIcon(payment.method),
                          color: _methodColor(payment.method),
                        ),
                      ),
                      title: Text(
                        item.memberName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${_methodLabel(payment.method)} • ${DateFormat('MMM dd, yyyy').format(payment.createdAt)}',
                      ),
                      trailing: Text(
                        currency.format(payment.amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text('Error: $e', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () =>
                  ref.invalidate(financialSecretaryDashboardProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHandoverDetails(
    BuildContext context,
    FinancialSecretaryDashboardData data,
    NumberFormat currency,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cash Collection & Handover',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Financial Secretary Internal Control Standard:\n'
                'All physical cash collected during meetings must be accounted for and handed over to the Treasurer with a signed handover voucher.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.payments, color: Colors.teal),
                title: const Text('Cash in Hand (To Remit)'),
                trailing: Text(
                  currency.format(data.cashCollected),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.teal,
                  ),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.account_balance, color: Colors.blue),
                title: const Text('Direct Bank Transfers (In Bank)'),
                trailing: Text(
                  currency.format(data.bankCollected),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue,
                  ),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.credit_card, color: Colors.purple),
                title: const Text('Online Gateway Payments'),
                trailing: Text(
                  currency.format(data.onlineCollected),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.purple,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Collections Tab (Payments Ledger)
// ---------------------------------------------------------------------------
class _CollectionsTab extends ConsumerStatefulWidget {
  final UserModel user;
  const _CollectionsTab({required this.user});

  @override
  ConsumerState<_CollectionsTab> createState() => _CollectionsTabState();
}

class _CollectionsTabState extends ConsumerState<_CollectionsTab> {
  String _filter = 'All';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final paymentsAsync = ref.watch(allPaymentsStreamProvider);
    final membersAsync = ref.watch(membersStreamProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Record Cash'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CashPaymentScreen(
                recordedBy: widget.user.displayName.isNotEmpty
                    ? widget.user.displayName
                    : 'Financial Secretary',
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
          if (_filter == 'Cash') {
            filtered = filtered
                .where((p) => p.method == PaymentMethod.cash)
                .toList();
          } else if (_filter == 'Bank') {
            filtered = filtered
                .where((p) => p.method == PaymentMethod.bankTransfer)
                .toList();
          } else if (_filter == 'Pending') {
            filtered = filtered
                .where((p) => p.status == PaymentStatus.pending)
                .toList();
          }

          final query = _searchController.text.trim().toLowerCase();
          if (query.isNotEmpty) {
            filtered = filtered.where((p) {
              final name = (memberMap[p.memberId] ?? p.memberName ?? '').toLowerCase();
              return name.contains(query) || p.id.toLowerCase().contains(query);
            }).toList();
          }

          filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by member name or ID...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All (${payments.length})',
                      selected: _filter == 'All',
                      onSelected: () => setState(() => _filter = 'All'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label:
                          'Pending (${payments.where((p) => p.status == PaymentStatus.pending).length})',
                      selected: _filter == 'Pending',
                      color: Colors.amber.shade700,
                      onSelected: () => setState(() => _filter = 'Pending'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label:
                          'Cash (${payments.where((p) => p.method == PaymentMethod.cash).length})',
                      selected: _filter == 'Cash',
                      color: Colors.teal,
                      onSelected: () => setState(() => _filter = 'Cash'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label:
                          'Bank (${payments.where((p) => p.method == PaymentMethod.bankTransfer).length})',
                      selected: _filter == 'Bank',
                      color: Colors.blue,
                      onSelected: () => setState(() => _filter = 'Bank'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 16),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No payments found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, index) {
                          final payment = filtered[index];
                          final memberName = memberMap[payment.memberId] ??
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
                                  _showReviewDialog(
                                    context,
                                    ref,
                                    payment,
                                    memberName,
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

  void _showReviewDialog(
    BuildContext context,
    WidgetRef ref,
    PaymentModel payment,
    String memberName,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Review Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Member: $memberName', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Amount: ₦${payment.amount.toStringAsFixed(0)}'),
            Text('Method: ${_methodLabel(payment.method)}'),
            if (payment.notes != null) Text('Note: ${payment.notes}'),
            const SizedBox(height: 12),
            const Text(
              'As Financial Secretary, you can verify this payment to credit the member\'s ledger.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(offlinePaymentProvider.notifier)
                  .verifyPendingPayment(
                    paymentId: payment.id,
                    action: 'reject',
                    verifiedBy: widget.user.displayName,
                  );
              ref.invalidate(allPaymentsStreamProvider);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(offlinePaymentProvider.notifier)
                  .verifyPendingPayment(
                    paymentId: payment.id,
                    action: 'approve',
                    verifiedBy: widget.user.displayName,
                  );
              ref.invalidate(allPaymentsStreamProvider);
            },
            child: const Text('Approve & Credit'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Debtors Tab (Defaulters Ledger)
// ---------------------------------------------------------------------------
class _DebtorsTab extends ConsumerStatefulWidget {
  final UserModel user;
  const _DebtorsTab({required this.user});

  @override
  ConsumerState<_DebtorsTab> createState() => _DebtorsTabState();
}

class _DebtorsTabState extends ConsumerState<_DebtorsTab> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final dashboardAsync = ref.watch(financialSecretaryDashboardProvider);

    return dashboardAsync.when(
      data: (data) {
        var arrears = data.memberArrears;
        final query = _searchController.text.trim().toLowerCase();
        if (query.isNotEmpty) {
          arrears = arrears
              .where((a) => a.memberName.toLowerCase().contains(query))
              .toList();
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search debtor by name...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red.withValues(alpha: 0.06),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${arrears.length} Members in Arrears',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Total: ${currency.format(data.totalOutstanding)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: arrears.isEmpty
                  ? const Center(child: Text('No debtors found.'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      itemCount: arrears.length,
                      itemBuilder: (ctx, index) {
                        final item = arrears[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.red.withValues(
                                alpha: 0.12,
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                            title: Text(
                              item.memberName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${item.unpaidCount} unpaid dues/levies',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  currency.format(item.totalOutstanding),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Colors.red,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Owing',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CashPaymentScreen(
                                    recordedBy: widget.user.displayName,
                                  ),
                                ),
                              );
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
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Levies & Dues Tab
// ---------------------------------------------------------------------------
class _LeviesTab extends ConsumerWidget {
  const _LeviesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final dashboardAsync = ref.watch(financialSecretaryDashboardProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Create Levy'),
        onPressed: () {
          final auth = ref.read(authProvider).valueOrNull;
          final memberIds = ref
                  .read(membersStreamProvider)
                  .valueOrNull
                  ?.map((m) => m.id)
                  .toList() ??
              [];
          if (auth != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateLevyScreen(
                  creatorId: auth.uid,
                  memberIds: memberIds,
                ),
              ),
            );
          }
        },
      ),
      body: dashboardAsync.when(
        data: (data) {
          final summaries = data.levySummaries;
          if (summaries.isEmpty) {
            return const Center(child: Text('No active levies found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: summaries.length,
            itemBuilder: (ctx, index) {
              final levy = summaries[index];
              final progress = levy.percentage.clamp(0.0, 1.0);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
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
                              levy.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Text(
                            '${(progress * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Collected: ${currency.format(levy.collected)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.teal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Target: ${currency.format(levy.target)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers & Sub-widgets
// ---------------------------------------------------------------------------
class _FinStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _FinStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(8),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelPill extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;

  const _ChannelPill({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            amount,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? Theme.of(context).colorScheme.primary;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(
        fontSize: 12,
        color: selected ? chipColor : Colors.black87,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final PaymentStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String text;

    switch (status) {
      case PaymentStatus.approved:
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        text = 'Approved';
        break;
      case PaymentStatus.pending:
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade800;
        text = 'Pending';
        break;
      case PaymentStatus.rejected:
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        text = 'Rejected';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}

IconData _methodIcon(PaymentMethod method) {
  switch (method) {
    case PaymentMethod.cash:
      return Icons.payments;
    case PaymentMethod.bankTransfer:
      return Icons.account_balance;
    case PaymentMethod.online:
      return Icons.credit_card;
  }
}

Color _methodColor(PaymentMethod method) {
  switch (method) {
    case PaymentMethod.cash:
      return Colors.teal;
    case PaymentMethod.bankTransfer:
      return Colors.blue;
    case PaymentMethod.online:
      return Colors.purple;
  }
}

String _methodLabel(PaymentMethod method) {
  switch (method) {
    case PaymentMethod.cash:
      return 'Cash';
    case PaymentMethod.bankTransfer:
      return 'Bank Transfer';
    case PaymentMethod.online:
      return 'Online';
  }
}
