import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/admin/controllers/admin_provider.dart';
import 'package:cls/features/admin/views/admin_users_screen.dart';
import 'package:cls/features/admin/views/organization_management_screen.dart';
import 'package:cls/features/admin/views/system_configuration_screen.dart';
import 'package:cls/features/admin/views/admin_profile_screen.dart';
import 'package:cls/features/admin/widgets/admin_metric_card.dart';
import 'package:cls/features/admin/widgets/quick_action_card.dart';
import 'package:cls/features/dashboard/widgets/dashboard_app_bar_actions.dart';

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull;
    final dashboardAsync = ref.watch(adminDashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: CircleAvatar(
              radius: 15,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                user?.displayName.isNotEmpty == true
                    ? user!.displayName[0].toUpperCase()
                    : 'A',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            tooltip: 'Super Admin Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
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
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(organizationsStreamProvider);
          ref.invalidate(allUsersStreamProvider);
          ref.invalidate(adminDashboardProvider);
        },
        child: dashboardAsync.when(
          data: (data) {
            final theme = Theme.of(context);
            return ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.paddingOf(context).bottom + 24,
              ),
              children: [
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Welcome, ${user?.displayName ?? 'Admin'}',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield_rounded, size: 14, color: theme.colorScheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                'Profile',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
      ),
    );
  }
}
