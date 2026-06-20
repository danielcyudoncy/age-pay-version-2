// features/dashboard/screens/member_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/core/widgets/quick_action_button.dart';
import 'package:cls/data/models/payment_model.dart';
import 'package:cls/data/models/obligation_model.dart';
import 'package:cls/features/auth/providers/auth_provider.dart';
import 'package:cls/features/dashboard/providers/member_dashboard_provider.dart';
import 'package:cls/features/obligations/providers/obligation_provider.dart';
import 'package:cls/features/payments/screens/make_payment_screen.dart';
import 'package:cls/features/payments/screens/payment_history_screen.dart';
import 'package:cls/features/obligations/screens/member_obligations_screen.dart';

class MemberDashboard extends ConsumerWidget {
  const MemberDashboard({super.key});

  String _greeting(String? name) {
    final hour = DateTime.now().hour;
    String timeGreeting;
    if (hour < 12) {
      timeGreeting = 'Good morning';
    } else if (hour < 17) {
      timeGreeting = 'Good afternoon';
    } else {
      timeGreeting = 'Good evening';
    }
    return name != null && name.isNotEmpty
        ? '$timeGreeting, $name'
        : timeGreeting;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull;
    final memberId = user?.uid;

    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final dateFormat = DateFormat('MMM dd, yyyy');
    final dateTimeFormat = DateFormat('MMM dd, yyyy \u2022 HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      body: authState.when(
        data: (u) {
          if (u == null || memberId == null || memberId.isEmpty) {
            return const Center(child: Text('Please sign in'));
          }
          return _buildDashboard(
            context,
            ref,
            memberId,
            user?.displayName,
            currency,
            dateFormat,
            dateTimeFormat,
          );
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

  Widget _buildDashboard(
    BuildContext context,
    WidgetRef ref,
    String memberId,
    String? displayName,
    NumberFormat currency,
    DateFormat dateFormat,
    DateFormat dateTimeFormat,
  ) {
    final totalPaidAsync = ref.watch(memberTotalPaidProvider(memberId));
    final totalOutstandingAsync = ref.watch(
      memberTotalOutstandingProvider(memberId),
    );
    final activeLeviesAsync = ref.watch(memberActiveLeviesProvider(memberId));
    final recentPaymentsAsync = ref.watch(
      memberRecentPaymentsProvider(memberId),
    );
    final registrationStatusAsync = ref.watch(
      memberRegistrationFeeStatusProvider(memberId),
    );
    final activeObligationsAsync = ref.watch(
      memberActiveObligationsProvider(memberId),
    );

    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(memberPaymentsStreamProvider(memberId));
        ref.invalidate(memberObligationsProvider(memberId));
        ref.invalidate(memberActiveObligationsProvider(memberId));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _greeting(displayName),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _SummaryCardsRow(
            totalPaidAsync: totalPaidAsync,
            totalOutstandingAsync: totalOutstandingAsync,
            activeLeviesAsync: activeLeviesAsync,
            currency: currency,
          ),
          const SizedBox(height: 20),
          _RegistrationStatusCard(statusAsync: registrationStatusAsync),
          const SizedBox(height: 20),
          _RecentPaymentsSection(
            paymentsAsync: recentPaymentsAsync,
            currency: currency,
            dateTimeFormat: dateTimeFormat,
            memberId: memberId,
          ),
          const SizedBox(height: 20),
          _ActiveLeviesSection(
            obligationsAsync: activeObligationsAsync,
            currency: currency,
            dateFormat: dateFormat,
            memberId: memberId,
          ),
          const SizedBox(height: 20),
          _QuickActionsRow(memberId: memberId, memberEmail: userEmail(ref)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String userEmail(WidgetRef ref) {
    final user = ref.read(authProvider).valueOrNull;
    return user?.email ?? '';
  }
}

class _SummaryCardsRow extends StatelessWidget {
  final AsyncValue<double> totalPaidAsync;
  final AsyncValue<double> totalOutstandingAsync;
  final AsyncValue<int> activeLeviesAsync;
  final NumberFormat currency;

  const _SummaryCardsRow({
    required this.totalPaidAsync,
    required this.totalOutstandingAsync,
    required this.activeLeviesAsync,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _SummaryCard(
            label: 'Total Paid',
            valueAsync: totalPaidAsync,
            formatter: (v) => currency.format(v),
            icon: Icons.paid,
            color: Colors.green,
          ),
          const SizedBox(width: 12),
          _SummaryCard(
            label: 'Total Outstanding',
            valueAsync: totalOutstandingAsync,
            formatter: (v) => currency.format(v),
            icon: Icons.pending,
            color: Colors.redAccent,
          ),
          const SizedBox(width: 12),
          _SummaryCard(
            label: 'Active Levies',
            valueAsync: activeLeviesAsync,
            formatter: (v) => v.toString(),
            icon: Icons.assignment,
            color: Colors.blue,
          ),
        ],
      ),
    );
  }
}

class _SummaryCard<T> extends StatelessWidget {
  final String label;
  final AsyncValue<T> valueAsync;
  final String Function(T) formatter;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.valueAsync,
    required this.formatter,
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
              valueAsync.when(
                data: (value) => Text(
                  formatter(value),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                loading: () => const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, _) => const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 20,
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

class _RegistrationStatusCard extends StatelessWidget {
  final AsyncValue<bool> statusAsync;

  const _RegistrationStatusCard({required this.statusAsync});

  @override
  Widget build(BuildContext context) {
    return statusAsync.when(
      data: (isRegistered) => Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                isRegistered ? Icons.check_circle : Icons.cancel,
                color: isRegistered ? Colors.green : Colors.grey,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registration Status',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isRegistered ? 'Registered \u2713' : 'Incomplete',
                      style: TextStyle(
                        fontSize: 14,
                        color: isRegistered
                            ? Colors.green
                            : Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, _) => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'Unable to load registration status',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentPaymentsSection extends StatelessWidget {
  final AsyncValue<List<PaymentModel>> paymentsAsync;
  final NumberFormat currency;
  final DateFormat dateTimeFormat;
  final String memberId;

  const _RecentPaymentsSection({
    required this.paymentsAsync,
    required this.currency,
    required this.dateTimeFormat,
    required this.memberId,
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
              'Recent Payments',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaymentHistoryScreen(memberId: memberId),
                  ),
                );
              },
              child: const Text('See All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        paymentsAsync.when(
          data: (payments) {
            if (payments.isEmpty) {
              return Card(
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
                        'No payments yet',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MakePaymentScreen(
                                memberId: memberId,
                                memberEmail: '',
                              ),
                            ),
                          );
                        },
                        child: const Text('Make a payment'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: payments.map((payment) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _statusColor(
                            payment.status,
                          ).withValues(alpha: 0.15),
                          child: Icon(
                            Icons.payment,
                            color: _statusColor(payment.status),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currency.format(payment.amount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_methodLabel(payment.method)} \u2022 ${dateTimeFormat.format(payment.createdAt)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor(
                              payment.status,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _statusLabel(payment.status),
                            style: TextStyle(
                              color: _statusColor(payment.status),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Text(
            'Failed to load payments',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }
}

class _ActiveLeviesSection extends StatelessWidget {
  final AsyncValue<List<ObligationModel>> obligationsAsync;
  final NumberFormat currency;
  final DateFormat dateFormat;
  final String memberId;

  const _ActiveLeviesSection({
    required this.obligationsAsync,
    required this.currency,
    required this.dateFormat,
    required this.memberId,
  });

  Color _statusColor(ObligationStatus status) {
    switch (status) {
      case ObligationStatus.unpaid:
        return Colors.red;
      case ObligationStatus.partial:
        return Colors.orange;
      case ObligationStatus.paid:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Levies',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        obligationsAsync.when(
          data: (obligations) {
            final active = obligations
                .where((o) => o.status != ObligationStatus.paid)
                .toList();
            if (active.isEmpty) {
              return Card(
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
                        'All caught up!',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  MemberObligationsScreen(memberId: memberId),
                            ),
                          );
                        },
                        child: const Text('View all obligations'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: active.map((obligation) {
                final progress = obligation.amount > 0
                    ? (obligation.paidAmount / obligation.amount).clamp(
                        0.0,
                        1.0,
                      )
                    : 0.0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                obligation.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(
                                  obligation.status,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                obligation.status.name[0].toUpperCase() +
                                    obligation.status.name.substring(1),
                                style: TextStyle(
                                  color: _statusColor(obligation.status),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Due ${dateFormat.format(obligation.dueDate)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Outstanding: ${currency.format(obligation.outstandingBalance)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${(progress * 100).toStringAsFixed(0)}% paid',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _statusColor(obligation.status),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _statusColor(obligation.status),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Text(
            'Failed to load obligations',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final String memberId;
  final String memberEmail;

  const _QuickActionsRow({required this.memberId, required this.memberEmail});

  @override
  Widget build(BuildContext context) {
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
              icon: Icons.payment,
              label: 'Make Payment',
              isPrimary: true,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MakePaymentScreen(
                      memberId: memberId,
                      memberEmail: memberEmail,
                    ),
                  ),
                );
              },
            ),
            QuickActionButton(
              icon: Icons.history,
              label: 'View History',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaymentHistoryScreen(memberId: memberId),
                  ),
                );
              },
            ),
            QuickActionButton(
              icon: Icons.assignment,
              label: 'View Obligations',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MemberObligationsScreen(memberId: memberId),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}
