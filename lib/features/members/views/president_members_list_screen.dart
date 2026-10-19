// features/members/views/president_members_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/dashboard/controllers/president_dashboard_provider.dart';
import 'package:cls/features/members/views/treasurer_member_detail_screen.dart';
import 'package:cls/features/members/views/member_profile_screen.dart';
import 'package:cls/features/secretary/views/search_screen.dart';
import 'package:cls/features/secretary/views/calendar_screen.dart';
import 'package:cls/features/secretary/views/documents_screen.dart';
import 'package:cls/features/reports/views/reports_screen.dart';
import 'package:cls/features/secretary/views/attendance_screen.dart';
import 'package:cls/features/notifications/views/notifications_screen.dart';
import 'package:cls/features/settings/views/settings_screen.dart';
import 'package:cls/features/settings/views/help_screen.dart';
import 'package:cls/features/settings/views/about_screen.dart';

class PresidentMembersListScreen extends ConsumerStatefulWidget {
  const PresidentMembersListScreen({super.key});

  @override
  ConsumerState<PresidentMembersListScreen> createState() =>
      _PresidentMembersListScreenState();
}

class _PresidentMembersListScreenState
    extends ConsumerState<PresidentMembersListScreen> {
  int _selectedIndex = 0;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _MembersListTab(
        searchController: _searchController,
        query: _query,
        onQueryChanged: (value) {
          setState(() {
            _query = value.toLowerCase();
          });
        },
      ),
      _MoreTab(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Members',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

class _MembersListTab extends ConsumerWidget {
  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onQueryChanged;

  const _MembersListTab({
    required this.searchController,
    required this.query,
    required this.onQueryChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(presidentMembersStreamProvider);
    final dateFormat = DateFormat('MMM d, yyyy');

    return Column(
      children: [
        AppBar(
          title: const Text('All Registered Members'),
          centerTitle: true,
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search by name or email...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: onQueryChanged,
          ),
        ),
        Expanded(
          child: membersAsync.when(
            data: (members) {
              final filtered = query.isEmpty
                  ? members
                  : members.where((m) {
                      final q = query;
                      return m.fullName.toLowerCase().contains(q) ||
                          m.email.toLowerCase().contains(q);
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final member = filtered[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          member.fullName.isNotEmpty
                              ? member.fullName[0]
                              : '?',
                        ),
                      ),
                      title: Text(member.fullName),
                      subtitle: Text(
                        'Joined ${dateFormat.format(member.joinedDate)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TreasurerMemberDetailScreen(
                              memberId: member.userId,
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
            error: (error, _) => Center(
              child: Text(
                'Error: $error',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MoreTab extends ConsumerWidget {
  const _MoreTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull;

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
        onTap: user == null
            ? null
            : () => Navigator.push(
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
          MaterialPageRoute(builder: (_) => const MemberProfileScreen()),
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
  final VoidCallback? onTap;
  const _MoreItem({
    required this.title,
    required this.icon,
    required this.color,
    this.onTap,
  });
}
