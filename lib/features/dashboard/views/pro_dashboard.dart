// features/dashboard/views/pro_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/core/theme/app_theme.dart';
import 'package:cls/core/widgets/quick_action_button.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/dashboard/widgets/dashboard_app_bar_actions.dart';
import 'package:cls/features/dashboard/widgets/dashboard_tab_pop_scope.dart';
import 'package:cls/features/dashboard/views/member_dashboard.dart';
import 'package:cls/features/secretary/controllers/secretary_dashboard_provider.dart';
import 'package:cls/features/secretary/views/announcements_screen.dart';
import 'package:cls/features/secretary/models/calendar_event_model.dart';
import 'package:cls/features/secretary/views/calendar_screen.dart';
import 'package:cls/features/secretary/views/documents_screen.dart';
import 'package:cls/features/secretary/views/search_screen.dart';
import 'package:cls/features/meetings/controllers/meeting_provider.dart';

class ProDashboard extends ConsumerStatefulWidget {
  const ProDashboard({super.key});

  @override
  ConsumerState<ProDashboard> createState() => _ProDashboardState();
}

class _ProDashboardState extends ConsumerState<ProDashboard> {
  int _selectedIndex = 0;

  void _onNavigate(int index) {
    setState(() => _selectedIndex = index);
  }

  String _appBarTitle(int index) {
    switch (index) {
      case 0:
        return 'Public Relations (PRO)';
      case 1:
        return 'Broadcasts & Announcements';
      case 2:
        return 'Community Calendar';
      case 3:
        return 'Media & Documents';
      case 4:
        return 'My Dues & Payments';
      default:
        return 'PRO Dashboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please sign in')));
    }

    final pages = <Widget>[
      _ProHomeTab(user: user, onNavigate: _onNavigate),
      const AnnouncementsScreen(),
      const CalendarScreen(),
      const DocumentsScreen(),
      const MemberDashboard(),
    ];

    return DashboardTabPopScope(
      selectedIndex: _selectedIndex,
      onSelectTab: (index) => setState(() => _selectedIndex = index),
      child: Scaffold(
        appBar: (_selectedIndex == 1 || _selectedIndex == 2 || _selectedIndex == 3 || _selectedIndex == 4)
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
                        icon: const Icon(Icons.search, color: AppTheme.brandGreen),
                        tooltip: 'Search directory',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SearchScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                    onRefresh: () async {
                      final orgId = user.organizationId;
                      ref.invalidate(announcementsStreamProvider(orgId));
                      ref.invalidate(allCalendarEventsProvider(orgId));
                      ref.invalidate(meetingsStreamProvider);
                      ref.invalidate(documentsStreamProvider(orgId));
                      ref.invalidate(membersStreamProvider);
                    },
                  ),
                ],
              ),
        body: IndexedStack(index: _selectedIndex, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) => setState(() => _selectedIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Overview',
            ),
            NavigationDestination(
              icon: Icon(Icons.campaign_outlined),
              selectedIcon: Icon(Icons.campaign),
              label: 'Broadcasts',
            ),
            NavigationDestination(
              icon: Icon(Icons.event_outlined),
              selectedIcon: Icon(Icons.event),
              label: 'Calendar',
            ),
            NavigationDestination(
              icon: Icon(Icons.perm_media_outlined),
              selectedIcon: Icon(Icons.perm_media),
              label: 'Media Hub',
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

// ---------------------------------------------------------------------------
// PRO HOME / OVERVIEW TAB
// ---------------------------------------------------------------------------
class _ProHomeTab extends ConsumerWidget {
  final UserModel user;
  final ValueChanged<int> onNavigate;

  const _ProHomeTab({
    required this.user,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final orgId = user.organizationId;
    final announcementsAsync = ref.watch(announcementsStreamProvider(orgId));
    final eventsAsync = ref.watch(allCalendarEventsProvider(orgId));
    final documentsAsync = ref.watch(documentsStreamProvider(orgId));
    final membersAsync = ref.watch(membersStreamProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(announcementsStreamProvider(orgId));
        ref.invalidate(calendarEventsStreamProvider(orgId));
        ref.invalidate(meetingsStreamProvider);
        ref.invalidate(documentsStreamProvider(orgId));
        ref.invalidate(membersStreamProvider);
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.12),
                  theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: theme.colorScheme.primary,
                  child: const Icon(
                    Icons.campaign,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.displayName.isNotEmpty
                                  ? user.displayName
                                  : 'Public Relations Officer',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'PRO',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Publicity, Member Mobilization & External Relations',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Communication KPIs
          Row(
            children: [
              Expanded(
                child: _ProMetricCard(
                  label: 'Announcements',
                  value: announcementsAsync.when(
                    data: (items) => '${items.length}',
                    loading: () => '...',
                    error: (_, _) => '0',
                  ),
                  icon: Icons.campaign_outlined,
                  color: theme.colorScheme.primary,
                  onTap: () => onNavigate(1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ProMetricCard(
                  label: 'Calendar Events',
                  value: eventsAsync.when(
                    data: (items) => '${items.length}',
                    loading: () => '...',
                    error: (_, _) => '0',
                  ),
                  icon: Icons.event_outlined,
                  color: Colors.blue,
                  onTap: () => onNavigate(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ProMetricCard(
                  label: 'Media & Docs',
                  value: documentsAsync.when(
                    data: (items) => '${items.length}',
                    loading: () => '...',
                    error: (_, _) => '0',
                  ),
                  icon: Icons.folder_outlined,
                  color: Colors.teal,
                  onTap: () => onNavigate(3),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ProMetricCard(
                  label: 'Roster Members',
                  value: membersAsync.when(
                    data: (items) => '${items.length}',
                    loading: () => '...',
                    error: (_, _) => '0',
                  ),
                  icon: Icons.groups_outlined,
                  color: Colors.deepPurple,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SearchScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Quick Action Buttons
          Text(
            'Quick Actions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                QuickActionButton(
                  icon: Icons.campaign,
                  label: 'New Broadcast',
                  onPressed: () => onNavigate(1),
                ),
                const SizedBox(width: 12),
                QuickActionButton(
                  icon: Icons.event,
                  label: 'New Event',
                  onPressed: () => onNavigate(2),
                ),
                const SizedBox(width: 12),
                QuickActionButton(
                  icon: Icons.upload_file,
                  label: 'Upload Media',
                  onPressed: () => onNavigate(3),
                ),
                const SizedBox(width: 12),
                QuickActionButton(
                  icon: Icons.person_search,
                  label: 'Search Roster',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SearchScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                QuickActionButton(
                  icon: Icons.payments_outlined,
                  label: 'Pay My Dues',
                  onPressed: () => onNavigate(4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Recent Broadcasts Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Broadcasts',
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
          const SizedBox(height: 8),
          announcementsAsync.when(
            data: (items) {
              final visible = items.where((a) => a.isVisibleTo(user)).toList();
              if (visible.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.campaign_outlined,
                            size: 40,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 8),
                          const Text('No announcements broadcasted yet'),
                          const SizedBox(height: 8),
                          FilledButton.tonalIcon(
                            onPressed: () => onNavigate(1),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Post New Broadcast'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              final recent = visible.take(3).toList();
              final dateFormat = DateFormat('MMM dd, yyyy');

              return Column(
                children: recent.map((ann) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(
                          Icons.campaign,
                          color: theme.colorScheme.onPrimaryContainer,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        ann.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${ann.targetAudience.toUpperCase()} • ${dateFormat.format(ann.announcementDate ?? ann.createdAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () => onNavigate(1),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Text('Error loading broadcasts: $err'),
          ),
          const SizedBox(height: 20),

          // Upcoming Events & Mobilization Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mobilization & Events',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => onNavigate(2),
                child: const Text('View Calendar'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          eventsAsync.when(
            data: (events) {
              final now = DateTime.now();
              bool isPast(CalendarEventModel e) {
                if (e.allDay) {
                  final endOfDay = DateTime(e.endDate.year, e.endDate.month, e.endDate.day, 23, 59, 59);
                  return endOfDay.isBefore(now);
                }
                return e.endDate.isBefore(now);
              }

              final upcoming = events
                  .where((e) => !isPast(e))
                  .take(3)
                  .toList();

              if (upcoming.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'No upcoming events scheduled',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              }

              final dateFormat = DateFormat('MMM dd, yyyy \u2022 HH:mm');
              return Column(
                children: upcoming.map((e) {
                  String sourceTag = '';
                  IconData icon = Icons.event;
                  Color iconColor = Colors.blue;
                  if (e.id.startsWith('announcement_')) {
                    sourceTag = 'Broadcast \u2022 ';
                    icon = Icons.campaign;
                    iconColor = theme.colorScheme.primary;
                  } else if (e.id.startsWith('meeting_')) {
                    sourceTag = 'Meeting \u2022 ';
                    icon = Icons.groups;
                    iconColor = Colors.purple;
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: iconColor.withValues(alpha: 0.12),
                        child: Icon(icon, color: iconColor, size: 20),
                      ),
                      title: Text(
                        e.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '$sourceTag${dateFormat.format(e.startDate)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: e.location != null
                          ? const Icon(Icons.location_on, size: 16)
                          : null,
                      onTap: () => onNavigate(2),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _ProMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ProMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
