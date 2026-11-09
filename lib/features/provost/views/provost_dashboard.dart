import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/controllers/auth_provider.dart';
import '../../auth/models/user_model.dart';
import '../../dashboard/views/member_dashboard.dart';
import '../../members/models/member_model.dart';
import '../../obligations/models/obligation_model.dart';
import '../../secretary/controllers/secretary_dashboard_provider.dart';
import '../controllers/provost_provider.dart';
import '../models/infraction_presets.dart';
import '../widgets/active_meeting_decorum_card.dart';
import '../widgets/issue_penalty_sheet.dart';
import '../widgets/request_waiver_dialog.dart';
import 'meeting_decorum_screen.dart';
import 'waiver_audit_ledger_screen.dart';
import '../../dashboard/widgets/dashboard_app_bar_actions.dart';
import '../../dashboard/widgets/dashboard_tab_pop_scope.dart';
import '../../dashboard/widgets/dual_role_switcher_card.dart';
import '../../calling/views/branch_directory_screen.dart';

class ProvostDashboard extends ConsumerStatefulWidget {
  const ProvostDashboard({super.key});

  @override
  ConsumerState<ProvostDashboard> createState() => _ProvostDashboardState();
}

class _ProvostDashboardState extends ConsumerState<ProvostDashboard> {
  int _selectedIndex = 0;

  void _onNavigate(int index) {
    setState(() => _selectedIndex = index);
  }

  String _appBarTitle(int index) {
    switch (index) {
      case 0:
        return '';
      case 1:
        return 'Meeting Decorum';
      case 2:
        return 'Pardon & Waiver Ledger';
      case 3:
        return 'My Dues & Payments';
      default:
        return 'Provost Dashboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please sign in')));
    }

    final activeMeeting = ref.watch(activeMeetingProvider(user.organizationId));

    final pages = <Widget>[
      _ProvostHomeTab(user: user, onNavigate: _onNavigate),
      activeMeeting != null
          ? MeetingDecorumScreen(meeting: activeMeeting)
          : _NoActiveMeetingTab(user: user, onNavigate: _onNavigate),
      WaiverAuditLedgerScreen(organizationId: user.organizationId),
      const MemberDashboard(),
    ];

    return DashboardTabPopScope(
      selectedIndex: _selectedIndex,
      onSelectTab: _onNavigate,
      child: Scaffold(
        appBar: (_selectedIndex == 2 ||
                _selectedIndex == 3 ||
                (_selectedIndex == 1 && activeMeeting != null))
            ? null
            : AppBar(
                title: _selectedIndex == 0
                    ? DashboardScopeTitle(user: user)
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(_appBarTitle(_selectedIndex)),
                      ),
                actions: [
                  DashboardAppBarActions(
                    user: user,
                    showScopeChip: _selectedIndex != 0,
                    onRefresh: () async {
                      ref.invalidate(provostPenaltiesStreamProvider(user.organizationId));
                      ref.invalidate(provostWaiversStreamProvider(user.organizationId));
                      ref.invalidate(pendingWaiversStreamProvider(user.organizationId));
                    },
                  ),
                ],
              ),
        body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onNavigate,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.gavel_outlined),
            selectedIcon: Icon(Icons.gavel),
            label: 'Sanctions',
          ),
          NavigationDestination(
            icon: Icon(Icons.rule_folder_outlined),
            selectedIcon: Icon(Icons.rule_folder),
            label: 'Decorum',
          ),
          NavigationDestination(
            icon: Icon(Icons.verified_user_outlined),
            selectedIcon: Icon(Icons.verified_user),
            label: 'Waivers',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'My Dues',
          ),
        ],
      ),
    ),
  );
  }
}

class _ProvostHomeTab extends ConsumerWidget {
  final UserModel user;
  final ValueChanged<int> onNavigate;

  const _ProvostHomeTab({
    required this.user,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    final penaltiesAsync =
        ref.watch(provostPenaltiesStreamProvider(user.organizationId));
    final waiversAsync =
        ref.watch(provostWaiversStreamProvider(user.organizationId));
    final membersAsync = ref.watch(membersStreamProvider);

    final membersMap = <String, String>{};
    membersAsync.whenData((members) {
      for (final m in members) {
        if (m is MemberModel) {
          membersMap[m.id] = m.fullName;
        }
      }
    });

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(provostPenaltiesStreamProvider(user.organizationId));
        ref.invalidate(provostWaiversStreamProvider(user.organizationId));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Provost Hero Greeting Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.primary(context),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.amberAccent,
                        child: Icon(Icons.gavel_rounded,
                            color: AppTheme.primary(context), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'Chief Provost • Order & Disciplinary Enforcement',
                              style: TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Dual Role Scope Switcher Banner (if user holds both Branch & National offices)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DualRoleSwitcherCard(user: user),
            ),

            // Active Meeting Decorum Banner Card
            ActiveMeetingDecorumCard(
              organizationId: user.organizationId,
              provostName: user.displayName,
            ),

            // Statistics Summary Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: penaltiesAsync.when(
                data: (penalties) {
                  final totalFines = penalties.fold<double>(
                      0.0, (sum, p) => sum + p.amount);
                  final unpaidCount =
                      penalties.where((p) => !p.isPaid && !p.isWaived).length;
                  final waivers = waiversAsync.valueOrNull ?? [];
                  final pendingWaiverCount = waivers
                      .where(
                          (w) => w.status == PenaltyWaiverStatus.pendingApproval)
                      .length;

                  return Row(
                    children: [
                      Expanded(
                        child: _kpiCard(
                          title: 'Total Fines',
                          value: currency.format(totalFines),
                          icon: Icons.money_off,
                          color: AppTheme.statusColor(context, Colors.red),
                          bgColor: AppTheme.statusBg(context, Colors.red),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _kpiCard(
                          title: 'Active Fines',
                          value: '$unpaidCount Unpaid',
                          icon: Icons.warning_amber_rounded,
                          color: Colors.orange.shade800,
                          bgColor: Colors.orange.shade50,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _kpiCard(
                          title: 'Pending Waivers',
                          value: '$pendingWaiverCount Queue',
                          icon: Icons.pending_actions,
                          color: Colors.teal.shade800,
                          bgColor: Colors.teal.shade50,
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),

            // Quick Actions Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (_) => IssuePenaltySheet(
                        organizationId: user.organizationId,
                        provostName: user.displayName,
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text(
                    '+ Issue Disciplinary Sanction',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

            // Branch Calls Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.phone_in_talk, color: Colors.green),
                  label: const Text(
                    'Branch Calls Directory',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BranchDirectoryScreen(),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Recent Sanctions Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Recent Sanctions & Penalties',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => onNavigate(2),
                    child: const Text('View All Waivers'),
                  ),
                ],
              ),
            ),

            penaltiesAsync.when(
              data: (penalties) {
                if (penalties.isEmpty) {
                  return Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.cardBorder(context)),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.verified_outlined,
                              size: 40, color: Colors.green.shade600),
                          const SizedBox(height: 8),
                          const Text(
                            'Decorum Upheld',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No disciplinary fines issued yet. Tap "+ Issue Disciplinary Sanction" above to record an infraction.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: penalties.length,
                  itemBuilder: (ctx, idx) {
                    final p = penalties[idx];
                    final memberName = membersMap[p.memberId] ?? 'Member';
                    return _penaltyTile(
                      context: context,
                      penalty: p,
                      memberName: memberName,
                      provostName: user.displayName,
                      currency: currency,
                    );
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Error loading penalties: $err'),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _penaltyTile({
    required BuildContext context,
    required ObligationModel penalty,
    required String memberName,
    required String provostName,
    required NumberFormat currency,
  }) {
    Color statusColor;
    String statusLabel;

    if (penalty.isWaived) {
      statusColor = Colors.teal.shade700;
      statusLabel = 'Pardoned / Waived';
    } else if (penalty.waiverStatus == PenaltyWaiverStatus.pendingApproval) {
      statusColor = AppTheme.statusColor(context, Colors.amber);
      statusLabel = 'Waiver Pending President';
    } else if (penalty.isPaid) {
      statusColor = Colors.green.shade700;
      statusLabel = 'Fine Paid';
    } else {
      statusColor = Colors.red.shade700;
      statusLabel = 'Unpaid Fine';
    }

    final preset = penalty.infractionType != null
        ? InfractionPreset.forType(penalty.infractionType!)
        : null;

    final canRequestWaiver =
        !penalty.isWaived &&
        penalty.waiverStatus != PenaltyWaiverStatus.pendingApproval &&
        !penalty.isPaid;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.cardBorder(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      (preset?.color ?? Colors.red).withValues(alpha: 0.15),
                  child: Icon(
                    preset?.icon ?? Icons.gavel,
                    size: 16,
                    color: preset?.color ?? Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    penalty.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  currency.format(penalty.amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.person_outline,
                    size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  memberName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM d, yyyy').format(penalty.createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
            if (penalty.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                penalty.description,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                if (canRequestWaiver)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.teal.shade800,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => RequestWaiverDialog(
                          penalty: penalty,
                          memberName: memberName,
                          provostName: provostName,
                        ),
                      );
                    },
                    icon: const Icon(Icons.healing, size: 14),
                    label: const Text(
                      'Pardon / Waive',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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

class _NoActiveMeetingTab extends StatelessWidget {
  final UserModel user;
  final ValueChanged<int> onNavigate;

  const _NoActiveMeetingTab({
    required this.user,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_busy_outlined,
                size: 48,
                color: AppTheme.primary(context),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Meeting Active Today',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'When the General Secretary schedules or commences a meeting for today, the active decorum session will automatically unlock here for rapid roll-call and lateness sanctioning.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => onNavigate(0),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Provost Dashboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary(context),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
