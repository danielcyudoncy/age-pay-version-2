import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/core/theme/app_theme.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/admin/controllers/admin_provider.dart';
import 'package:cls/features/admin/models/admin_dashboard_data.dart';
import 'package:cls/features/admin/models/organization_model.dart';
import 'package:cls/features/admin/views/admin_users_screen.dart';
import 'package:cls/features/admin/views/organization_management_screen.dart';
import 'package:cls/features/admin/views/system_configuration_screen.dart';
import 'package:cls/features/admin/views/admin_profile_screen.dart';
import 'package:cls/features/admin/widgets/admin_metric_card.dart';
import 'package:cls/features/admin/widgets/quick_action_card.dart';
import 'package:cls/features/dashboard/views/member_dashboard.dart';
import 'package:cls/features/national/views/national_hub_screen.dart';
import 'package:cls/features/dashboard/widgets/dashboard_app_bar_actions.dart';
import 'package:cls/features/dashboard/widgets/dashboard_tab_pop_scope.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  int _selectedIndex = 0;

  void _onSelectTab(int index) {
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull;
    final dashboardAsync = ref.watch(adminDashboardProvider);
    final theme = Theme.of(context);

    final pages = <Widget>[
      _AdminConsoleTab(
        user: user,
        dashboardAsync: dashboardAsync,
        onSelectTab: _onSelectTab,
      ),
      const MemberDashboard(),
      const NationalHubScreen(),
    ];

    return DashboardTabPopScope(
      selectedIndex: _selectedIndex,
      onSelectTab: _onSelectTab,
      child: Scaffold(
        appBar: _selectedIndex == 0
            ? AppBar(
                title: const Text('Admin Dashboard'),
                actions: [
                  IconButton(
                    icon: CircleAvatar(
                      radius: 15,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        user?.displayName.isNotEmpty == true
                            ? user!.displayName[0].toUpperCase()
                            : 'A',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    tooltip: 'Super Admin Profile',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminProfileScreen(),
                        ),
                      );
                    },
                  ),
                  DashboardAppBarActions(
                    user: user,
                    onRefresh: () async {
                      ref.invalidate(organizationsStreamProvider);
                      ref.invalidate(allUsersStreamProvider);
                      ref.invalidate(adminDashboardProvider);
                    },
                  ),
                ],
              )
            : null,
        body: IndexedStack(
          index: _selectedIndex,
          children: pages,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onSelectTab,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppTheme.brandGreen,
          unselectedItemColor: theme.colorScheme.onSurfaceVariant,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings_outlined),
              activeIcon: Icon(Icons.admin_panel_settings),
              label: 'Admin Console',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.badge_outlined),
              activeIcon: Icon(Icons.badge),
              label: 'Branch Member',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.public_outlined),
              activeIcon: Icon(Icons.public),
              label: 'National Branch',
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminConsoleTab extends ConsumerWidget {
  final UserModel? user;
  final AsyncValue<AdminDashboardData> dashboardAsync;
  final ValueChanged<int> onSelectTab;

  const _AdminConsoleTab({
    required this.user,
    required this.dashboardAsync,
    required this.onSelectTab,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final orgAsync = ref.watch(currentOrganizationProvider);
    final currentOrg = orgAsync.valueOrNull;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(organizationsStreamProvider);
        ref.invalidate(allUsersStreamProvider);
        ref.invalidate(adminDashboardProvider);
      },
      child: dashboardAsync.when(
        data: (data) {
          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.paddingOf(context).bottom + 24,
            ),
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Welcome, ${user?.displayName.isNotEmpty == true ? user!.displayName : 'Super Admin'}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                ),
              ),
              const SizedBox(height: 16),
              _buildMembershipCard(context, theme, currentOrg),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AdminMetricCard(
                        label: 'Organizations',
                        value: data.totalOrganizations.toString(),
                        icon: Icons.business,
                        color: theme.colorScheme.primary,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const OrganizationManagementScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      AdminMetricCard(
                        label: 'Active Orgs',
                        value: data.activeOrganizations.toString(),
                        icon: Icons.check_circle,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 12),
                      AdminMetricCard(
                        label: 'Total Users',
                        value: data.totalUsers.toString(),
                        icon: Icons.people,
                        color: Colors.blue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminUsersScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      AdminMetricCard(
                        label: 'Pending',
                        value: data.pendingApprovals.toString(),
                        icon: Icons.pending_actions,
                        color: Colors.orange,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const AdminUsersScreen(filterPending: true),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Management',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          QuickActionCard(
                            title: 'Organizations',
                            subtitle: 'Manage organizations',
                            icon: Icons.business,
                            color: theme.colorScheme.primary,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const OrganizationManagementScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          QuickActionCard(
                            title: 'Users',
                            subtitle: 'Manage users & roles',
                            icon: Icons.people,
                            color: Colors.green,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AdminUsersScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          QuickActionCard(
                            title: 'Settings',
                            subtitle: 'System configuration',
                            icon: Icons.settings,
                            color: Colors.orange,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const SystemConfigurationScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          QuickActionCard(
                            title: 'My Profile',
                            subtitle: 'Super Admin profile',
                            icon: Icons.person_outline,
                            color: Colors.indigo,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const AdminProfileScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error: $error',
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(organizationsStreamProvider);
                  ref.invalidate(allUsersStreamProvider);
                  ref.invalidate(adminDashboardProvider);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMembershipCard(
    BuildContext context,
    ThemeData theme,
    OrganizationModel? org,
  ) {
    final branchName = user?.branchName?.isNotEmpty == true
        ? user!.branchName!
        : (org?.name != null ? '${org!.name} (Primary)' : 'Local Branch Member');

    final nationalTitle = user?.nationalRole != null
        ? 'National Executive (${user!.nationalRole!.displayName})'
        : 'National Assembly & Council';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
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
                    color: AppTheme.brandGreen.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.badge_outlined,
                    size: 20,
                    color: AppTheme.brandGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Member Affiliations',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'You hold registered status in branch and national tiers',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Branch Membership Tile
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 20,
                    color: AppTheme.brandGreen,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Branch Member',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          branchName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onSelectTab(1),
                    icon: const Icon(Icons.arrow_forward, size: 14),
                    label: const Text('Member View', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // National Branch Tile
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.public_outlined,
                    size: 20,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'National Branch',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          nationalTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onSelectTab(2),
                    icon: const Icon(Icons.arrow_forward, size: 14),
                    label: const Text('National Hub', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
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
