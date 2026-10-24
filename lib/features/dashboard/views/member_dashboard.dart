import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/core/widgets/quick_action_button.dart';
import 'package:cls/features/payments/models/payment_model.dart';
import 'package:cls/features/obligations/models/obligation_model.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/dashboard/controllers/member_dashboard_provider.dart';
import 'package:cls/features/obligations/controllers/obligation_provider.dart';
import 'package:cls/features/payments/views/make_payment_screen.dart';
import 'package:cls/features/payments/views/payment_history_screen.dart';
import 'package:cls/features/obligations/views/member_obligations_screen.dart';
import 'package:cls/features/members/views/member_profile_screen.dart';
import 'package:cls/features/secretary/controllers/secretary_dashboard_provider.dart';
import 'package:cls/features/secretary/views/member_announcements_screen.dart';
import 'package:cls/features/meetings/controllers/meeting_provider.dart';
import 'package:cls/features/meetings/models/meeting_rsvp_model.dart';
import 'package:cls/features/meetings/controllers/meeting_rsvp_provider.dart';
import 'package:cls/features/meetings/views/meeting_detail_screen.dart';
import 'package:cls/features/reports/views/reports_screen.dart';
import 'package:cls/features/expenses/views/expense_list_screen.dart';
import 'package:cls/core/theme/app_theme.dart';
import 'package:cls/features/dashboard/widgets/dashboard_app_bar_actions.dart';

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
    final orgIdAsync = ref.watch(organizationIdProvider);
    final orgId = orgIdAsync.valueOrNull ?? user?.organizationId ?? '';

    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final dateFormat = DateFormat('MMM dd, yyyy');
    final dateTimeFormat = DateFormat('MMM dd, yyyy \u2022 HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          DashboardAppBarActions(
            user: user,
            extraActions: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.assessment_outlined, color: AppTheme.brandGreen),
                tooltip: 'Financial Reports & Purse',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReportsScreen()),
                  );
                },
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.person_outline, color: AppTheme.brandGreen),
                tooltip: 'My Profile',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MemberProfileScreen()),
                  );
                },
              ),
            ],
            onRefresh: () async {
              if (memberId != null) {
                ref.invalidate(memberTotalPaidProvider(memberId));
                ref.invalidate(memberTotalOutstandingProvider(memberId));
                ref.invalidate(memberActiveLeviesProvider(memberId));
                ref.invalidate(memberRecentPaymentsProvider(memberId));
              }
              ref.invalidate(authProvider);
            },
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
            orgId,
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
    String orgId,
    String? displayName,
    NumberFormat currency,
    DateFormat dateFormat,
    DateFormat dateTimeFormat,
  ) {
    // Automatically check and reconcile active dues/levies for this member
    ref.watch(memberObligationReconciliationProvider(memberId));

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

    final user = ref.watch(authProvider).valueOrNull;
    final isExecutive = user?.isExecutive ?? false;

    final announcementsCount = ref
        .watch(announcementsStreamProvider(orgId))
        .when(
          data: (items) {
            final visible = isExecutive
                ? items
                : items.where((a) => !a.isExecutivesOnly).toList();
            return visible.length;
          },
          loading: () => 0,
          error: (_, _) => 0,
        );

    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(memberObligationReconciliationProvider(memberId));
        ref.invalidate(memberPaymentsStreamProvider(memberId));
        ref.invalidate(memberObligationsProvider(memberId));
        ref.invalidate(memberActiveObligationsProvider(memberId));
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
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
          const _UpcomingMeetingCard(),
          _RegistrationStatusCard(statusAsync: registrationStatusAsync),
          const SizedBox(height: 20),
          _RecentPaymentsSection(
            paymentsAsync: recentPaymentsAsync,
            currency: currency,
            dateTimeFormat: dateTimeFormat,
            memberId: memberId,
            memberEmail: userEmail(ref),
          ),
          const SizedBox(height: 20),
          _ActiveLeviesSection(
            obligationsAsync: activeObligationsAsync,
            currency: currency,
            dateFormat: dateFormat,
            memberId: memberId,
          ),
          const SizedBox(height: 20),
          _QuickActionsRow(
            memberId: memberId,
            memberEmail: userEmail(ref),
            announcementsCount: announcementsCount,
          ),
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
                      isRegistered ? 'Completed' : 'Incomplete',
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
  final String memberEmail;

  const _RecentPaymentsSection({
    required this.paymentsAsync,
    required this.currency,
    required this.dateTimeFormat,
    required this.memberId,
    required this.memberEmail,
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
                                memberEmail: memberEmail,
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
  final int announcementsCount;

  const _QuickActionsRow({
    required this.memberId,
    required this.memberEmail,
    required this.announcementsCount,
  });

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
            QuickActionButton(
              icon: Icons.campaign,
              label: 'Announcements',
              badgeCount: announcementsCount,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MemberAnnouncementsScreen(),
                  ),
                );
              },
            ),
            QuickActionButton(
              icon: Icons.assessment_outlined,
              label: 'Reports & Purse',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ReportsScreen(),
                  ),
                );
              },
            ),
            QuickActionButton(
              icon: Icons.receipt_long_outlined,
              label: 'Expenses',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExpenseListScreen(
                      currentUserId: memberId,
                      isExecutive: false,
                    ),
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

class _UpcomingMeetingCard extends ConsumerWidget {
  const _UpcomingMeetingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetingsAsync = ref.watch(meetingsStreamProvider);
    final user = ref.watch(authProvider).valueOrNull;
    final isExecutive = user?.isExecutive ?? false;

    return meetingsAsync.when(
      data: (meetings) {
        final now = DateTime.now();
        final threshold = now.subtract(const Duration(hours: 4));
        final upcomingMeetings =
            meetings.where((m) {
              if (!m.meetingDate.isAfter(threshold)) return false;
              if (m.isExecutivesOnly && !isExecutive) return false;
              return true;
            }).toList()
              ..sort((a, b) => a.meetingDate.compareTo(b.meetingDate));

        if (upcomingMeetings.isEmpty) {
          return const SizedBox.shrink();
        }

        final meeting = upcomingMeetings.first;
        final theme = Theme.of(context);
        final dateTimeFormat = DateFormat('EEE, MMM dd, yyyy \u2022 hh:mm a');

        final myRsvp = user != null
            ? ref.watch(
                memberMeetingRsvpProvider((
                  meetingId: meeting.id,
                  memberId: user.uid,
                )),
              )
            : null;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: meeting.isExecutivesOnly
                  ? Colors.deepOrange.withValues(alpha: 0.35)
                  : theme.colorScheme.primary.withValues(alpha: 0.25),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => MeetingDetailScreen(
                        meeting: meeting,
                        readOnly: true,
                      ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (meeting.isExecutivesOnly
                            ? Colors.deepOrange
                            : theme.colorScheme.primary)
                        .withValues(alpha: 0.08),
                    theme.colorScheme.surface,
                  ],
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: meeting.isExecutivesOnly
                              ? Colors.deepOrange
                              : theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              meeting.isExecutivesOnly
                                  ? Icons.shield_outlined
                                  : Icons.event_available,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              meeting.isExecutivesOnly
                                  ? 'EXECUTIVE MEETING'
                                  : 'UPCOMING MEETING',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Details & RSVPs',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    meeting.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_filled,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dateTimeFormat.format(meeting.meetingDate),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (meeting.venue.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            meeting.venue,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  // RSVP status or prompt
                  if (myRsvp != null)
                    Row(
                      children: [
                        Icon(
                          myRsvp.status == MeetingRsvpStatus.attending
                              ? Icons.check_circle
                              : (myRsvp.status == MeetingRsvpStatus.late
                                  ? Icons.schedule
                                  : Icons.cancel),
                          size: 16,
                          color: myRsvp.status == MeetingRsvpStatus.attending
                              ? Colors.green
                              : (myRsvp.status == MeetingRsvpStatus.late
                                  ? Colors.orange.shade800
                                  : Colors.redAccent),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Your RSVP: ${myRsvp.status.displayName}${myRsvp.reason.isNotEmpty ? " • \"${myRsvp.reason}\"" : ""}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: myRsvp.status == MeetingRsvpStatus.attending
                                  ? Colors.green.shade800
                                  : (myRsvp.status == MeetingRsvpStatus.late
                                      ? Colors.orange.shade900
                                      : Colors.redAccent.shade700),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'Change',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Tap here to indicate if you are Coming or Send Excuse',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

