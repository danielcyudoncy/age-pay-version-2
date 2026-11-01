// features/members/views/treasurer_members_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/dashboard/controllers/treasurer_dashboard_provider.dart';
import 'package:cls/features/obligations/controllers/obligation_provider.dart';
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
import 'package:cls/features/calling/views/branch_directory_screen.dart';
import 'package:cls/features/calling/widgets/member_call_button.dart';

class TreasurerMembersListScreen extends ConsumerStatefulWidget {
  const TreasurerMembersListScreen({super.key});

  @override
  ConsumerState<TreasurerMembersListScreen> createState() =>
      _TreasurerMembersListScreenState();
}

class _TreasurerMembersListScreenState
    extends ConsumerState<TreasurerMembersListScreen> {
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
    final membersAsync = ref.watch(membersStreamProvider);
    final dateFormat = DateFormat('MMM d, yyyy');
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    return Column(
      children: [
        AppBar(
          title: const Text('All Registered Members'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.phone_in_talk, color: Colors.green),
              tooltip: 'Branch Calling Directory',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BranchDirectoryScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, email, or phone...',
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
                          m.email.toLowerCase().contains(q) ||
                          m.phoneNumber.toLowerCase().contains(q);
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
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  MediaQuery.paddingOf(context).bottom + 24,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final member = filtered[index];
                  return _MemberLedgerCard(
                    member: member,
                    dateFormat: dateFormat,
                    currency: currency,
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
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.green.withValues(alpha: 0.25),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 13, color: Colors.green),
                SizedBox(width: 4),
                Text(
                  'Dues Cleared',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 13, color: Colors.red),
              const SizedBox(width: 4),
              Text(
                'Owes ${currency.format(totalOwed)}',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          '...',
          style: TextStyle(color: Colors.grey, fontSize: 11),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _MemberLedgerCard extends StatelessWidget {
  final MemberModel member;
  final DateFormat dateFormat;
  final NumberFormat currency;
  final VoidCallback onTap;

  const _MemberLedgerCard({
    required this.member,
    required this.dateFormat,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryContact = member.phoneNumber.isNotEmpty
        ? member.phoneNumber
        : (member.email.isNotEmpty ? member.email : 'No contact provided');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Tier: Avatar, Name, Secondary Info, and Call Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      member.fullName.isNotEmpty
                          ? member.fullName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.fullName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                secondaryContact,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (member.branchName != null &&
                                member.branchName!.trim().isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 5),
                                child: Text(
                                  '•',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  member.branchName!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.primary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Dedicated Call Action
                  MemberCallButton(member: member, isCompact: true),
                ],
              ),

              const SizedBox(height: 10),
              Divider(
                height: 1,
                thickness: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 10),

              // Bottom Tier: Dues Status Badge, Joined Date, and Ledger Affordance
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MemberOwingBadge(
                    memberId: member.userId,
                    currency: currency,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Joined ${dateFormat.format(member.joinedDate)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ledger',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
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
            ],
          ),
        ),
      ),
    );
  }
}
