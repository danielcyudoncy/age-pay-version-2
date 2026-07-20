// features/secretary/views/secretary_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/core/widgets/quick_action_button.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/dashboard/views/member_dashboard.dart';
import 'package:cls/features/meetings/controllers/meeting_provider.dart';
import 'package:cls/features/meetings/models/meeting_model.dart';
import 'package:cls/features/meetings/views/meeting_detail_screen.dart';
import 'package:cls/features/dashboard/controllers/member_dashboard_provider.dart';
import 'package:cls/features/notifications/controllers/notification_provider.dart';
import 'package:cls/features/secretary/controllers/secretary_dashboard_provider.dart';
import 'package:cls/features/secretary/views/members_management_screen.dart';
import 'package:cls/features/secretary/views/announcements_screen.dart';
import 'package:cls/features/secretary/views/attendance_screen.dart';
import 'package:cls/features/secretary/views/documents_screen.dart';
import 'package:cls/features/secretary/views/calendar_screen.dart';
import 'package:cls/features/secretary/views/search_screen.dart';
import 'package:cls/features/secretary/views/secretary_profile_screen.dart';
import 'package:cls/features/settings/views/settings_screen.dart';
import 'package:cls/features/settings/views/help_screen.dart';
import 'package:cls/features/settings/views/about_screen.dart';
import 'package:cls/features/reports/views/reports_screen.dart';
import 'package:cls/features/notifications/views/notifications_screen.dart';

class SecretaryDashboard extends ConsumerStatefulWidget {
  const SecretaryDashboard({super.key});

  @override
  ConsumerState<SecretaryDashboard> createState() => _SecretaryDashboardState();
}

class _SecretaryDashboardState extends ConsumerState<SecretaryDashboard> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please sign in')));
    }

    final orgId = user.organizationId;
    final announcementsCount = ref
        .watch(announcementsStreamProvider(orgId))
        .when(
          data: (items) => items.length,
          loading: () => 0,
          error: (_, _) => 0,
        );

    final pages = <Widget>[
      _HomeTab(user: user, onNavigate: _onNavigate),
      const MembersManagementScreen(),
      const _MeetingsTab(),
      const AnnouncementsScreen(),
      const MemberDashboard(),
      _MoreTab(user: user),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Members',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.event_outlined),
            activeIcon: Icon(Icons.event),
            label: 'Meetings',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: announcementsCount > 0,
              label: Text(announcementsCount.toString()),
              child: const Icon(Icons.campaign_outlined),
            ),
            activeIcon: Badge(
              isLabelVisible: announcementsCount > 0,
              label: Text(announcementsCount.toString()),
              child: const Icon(Icons.campaign),
            ),
            label: 'Announcements',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'My Account',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  void _onNavigate(int index) {
    setState(() => _selectedIndex = index);
  }
}

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
    final orgId = user.organizationId;

    final membersAsync = ref.watch(membersStreamProvider);
    final meetingsAsync = ref.watch(meetingsStreamProvider);
    final paymentsAsync = ref.watch(memberTotalPaidProvider(user.uid));
    final obligationsAsync = ref.watch(
      memberTotalOutstandingProvider(user.uid),
    );
    final notificationsCount = ref.watch(unreadCountProvider);
    final announcementsAsync = ref.watch(announcementsStreamProvider(orgId));
    final documentsAsync = ref.watch(documentsStreamProvider(orgId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(membersStreamProvider);
        ref.invalidate(meetingsStreamProvider);
        ref.invalidate(announcementsStreamProvider(orgId));
        ref.invalidate(documentsStreamProvider(orgId));
        ref.invalidate(calendarEventsStreamProvider(orgId));
      },
      child: ListView(
        padding: const EdgeInsets.only(
          top: 36,
          left: 16,
          right: 16,
          bottom: 16,
        ),
        children: [
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
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Secretary',
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
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Total Members',
                  value: '...',
                  icon: Icons.people,
                  color: theme.colorScheme.primary,
                  streamAsync: membersAsync,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Active Members',
                  value: '...',
                  icon: Icons.check_circle,
                  color: Colors.green,
                  streamAsync: membersAsync,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Monthly Contributions',
                  value: '...',
                  icon: Icons.payments,
                  color: Colors.blue,
                  futureAsync: paymentsAsync,
                  formatter: (v) => currency.format(v ?? 0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Pending',
                  value: '...',
                  icon: Icons.pending,
                  color: Colors.orange,
                  futureAsync: obligationsAsync,
                  formatter: (v) => currency.format(v ?? 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Upcoming Meetings',
                  value: '...',
                  icon: Icons.event,
                  color: Colors.purple,
                  streamAsync: meetingsAsync,
                  filter: (items) => items
                      .where(
                        (m) => (m as MeetingModel).meetingDate.isAfter(
                          DateTime.now(),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Announcements',
                  value: '...',
                  icon: Icons.campaign,
                  color: Colors.teal,
                  streamAsync: announcementsAsync,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Documents',
                  value: '...',
                  icon: Icons.folder,
                  color: Colors.indigo,
                  streamAsync: documentsAsync,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Notifications',
                  value: notificationsCount.toString(),
                  icon: Icons.notifications,
                  color: Colors.red,
                  showBadge: notificationsCount > 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Quick Actions',
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
                icon: Icons.campaign,
                label: 'Announcement',
                onPressed: () => onNavigate(3),
              ),
              QuickActionButton(
                icon: Icons.event,
                label: 'Schedule Meeting',
                onPressed: () => onNavigate(2),
              ),
              QuickActionButton(
                icon: Icons.description,
                label: 'Meeting Minutes',
                onPressed: () => onNavigate(2),
              ),
              QuickActionButton(
                icon: Icons.people,
                label: 'Members',
                onPressed: () => onNavigate(1),
              ),
              QuickActionButton(
                icon: Icons.check_circle,
                label: 'Attendance',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                ),
              ),
              QuickActionButton(
                icon: Icons.payments,
                label: 'Contributions',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportsScreen()),
                ),
              ),
              QuickActionButton(
                icon: Icons.upload_file,
                label: 'Documents',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DocumentsScreen()),
                ),
              ),
              QuickActionButton(
                icon: Icons.picture_as_pdf,
                label: 'Reports',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportsScreen()),
                ),
              ),
              QuickActionButton(
                icon: Icons.calendar_today,
                label: 'Calendar',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CalendarScreen()),
                ),
              ),
              QuickActionButton(
                icon: Icons.notifications,
                label: 'Notifications',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NotificationsScreen(currentUser: user),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _StatCard extends ConsumerWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final AsyncValue? streamAsync;
  final AsyncValue? futureAsync;
  final String Function(dynamic)? formatter;
  final dynamic Function(List)? filter;
  final bool showBadge;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.streamAsync,
    this.futureAsync,
    this.formatter,
    this.filter,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget content;
    if (streamAsync != null) {
      content = streamAsync!.when(
        data: (items) {
          final list = items is List ? items : [items];
          final filtered = filter != null ? filter!(list) : list;
          return Text(
            filtered.length.toString(),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 20,
            ),
          );
        },
        loading: () => const CircularProgressIndicator(strokeWidth: 2),
        error: (error, _) =>
            const Icon(Icons.error_outline, size: 16, color: Colors.red),
      );
    } else if (futureAsync != null) {
      content = futureAsync!.when(
        data: (v) => Text(
          formatter != null ? formatter!(v) : v.toString(),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: color,
            fontSize: 20,
          ),
        ),
        loading: () => const CircularProgressIndicator(strokeWidth: 2),
        error: (error, _) =>
            const Icon(Icons.error_outline, size: 16, color: Colors.red),
      );
    } else {
      content = Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: color,
          fontSize: 20,
        ),
      );
    }

    return SizedBox(
      width: 160,
      child: Card(
        elevation: 0,
        color: color.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              content,
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

class _MeetingsTab extends ConsumerWidget {
  const _MeetingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetingsAsync = ref.watch(meetingsStreamProvider);
    final dateFormat = DateFormat('MMM dd, yyyy');
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull;
    final canEdit =
        user != null &&
        (user.role == UserRole.secretary ||
            user.role == UserRole.viceSecretary);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meetings'),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MeetingDetailScreen(),
                  ),
                );
              },
            ),
        ],
      ),
      body: meetingsAsync.when(
        data: (meetings) {
          final recorded = meetings.where((m) => m.hasMinutes).length;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(meetingsStreamProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MeetingStatCard(
                        label: 'Total',
                        value: meetings.length.toString(),
                        icon: Icons.event,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MeetingStatCard(
                        label: 'Minutes Recorded',
                        value: recorded.toString(),
                        icon: Icons.description,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (meetings.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_note_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No meetings recorded yet',
                            style: TextStyle(fontSize: 16),
                          ),
                          if (canEdit) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Tap + to add a meeting and record minutes.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                else
                  ...meetings.map((meeting) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.12),
                          child: Icon(
                            Icons.event,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          meeting.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(dateFormat.format(meeting.meetingDate)),
                        trailing: canEdit
                            ? const Icon(Icons.arrow_forward_ios, size: 16)
                            : null,
                        onTap: canEdit
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        MeetingDetailScreen(meeting: meeting),
                                  ),
                                );
                              }
                            : null,
                      ),
                    );
                  }),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('Error: $error', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(meetingsStreamProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeetingStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MeetingStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: color,
                fontSize: 20,
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
    );
  }
}

class _MoreTab extends ConsumerWidget {
  final UserModel user;
  const _MoreTab({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final items = [
      _MoreItem(
        title: 'Calendar',
        icon: Icons.calendar_today,
        color: Colors.blue,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CalendarScreen()),
        ),
      ),
      _MoreItem(
        title: 'Documents',
        icon: Icons.folder,
        color: Colors.indigo,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DocumentsScreen()),
        ),
      ),
      _MoreItem(
        title: 'Reports',
        icon: Icons.picture_as_pdf,
        color: Colors.red,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReportsScreen()),
        ),
      ),
      _MoreItem(
        title: 'Attendance',
        icon: Icons.check_circle,
        color: Colors.green,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AttendanceScreen()),
        ),
      ),
      _MoreItem(
        title: 'Notifications',
        icon: Icons.notifications,
        color: Colors.orange,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NotificationsScreen(currentUser: user),
          ),
        ),
      ),
      _MoreItem(
        title: 'Profile',
        icon: Icons.person,
        color: theme.colorScheme.primary,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SecretaryProfileScreen()),
        ),
      ),
      _MoreItem(
        title: 'Search',
        icon: Icons.search,
        color: Colors.purple,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SearchScreen()),
        ),
      ),
      _MoreItem(
        title: 'Settings',
        icon: Icons.settings,
        color: Colors.grey,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
      ),
      _MoreItem(
        title: 'Help',
        icon: Icons.help_outline,
        color: Colors.teal,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HelpScreen()),
        ),
      ),
      _MoreItem(
        title: 'About',
        icon: Icons.info_outline,
        color: Colors.brown,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AboutScreen()),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: item.color.withValues(alpha: 0.12),
                child: Icon(item.icon, color: item.color),
              ),
              title: Text(
                item.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: item.onTap,
            ),
          );
        },
      ),
    );
  }
}

class _MoreItem {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _MoreItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
