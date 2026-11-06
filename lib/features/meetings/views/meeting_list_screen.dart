import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/controllers/auth_provider.dart';
import '../../auth/models/user_model.dart';
import '../../national/controllers/national_provider.dart';
import '../controllers/meeting_provider.dart';
import '../models/meeting_model.dart';
import 'meeting_detail_screen.dart';

class MeetingListScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const MeetingListScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<MeetingListScreen> createState() => _MeetingListScreenState();
}

class _MeetingListScreenState extends ConsumerState<MeetingListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'national', 'branch', 'minutes'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool _canManageMeetings(UserModel? user, ExecutiveScope activeScope) {
    if (user == null) return false;
    if (user.role == UserRole.superAdmin) return true;
    final effectiveRole = (activeScope == ExecutiveScope.national && user.nationalRole != null)
        ? user.nationalRole!
        : user.role;
    return effectiveRole == UserRole.secretary ||
        effectiveRole == UserRole.viceSecretary ||
        effectiveRole == UserRole.president ||
        effectiveRole == UserRole.vicePresident;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).valueOrNull;
    final activeScope = ref.watch(activeExecutiveScopeProvider);
    final isNationalScope = activeScope == ExecutiveScope.national &&
        (user?.nationalRole != null || user?.role == UserRole.superAdmin);
    final canManage = _canManageMeetings(user, activeScope);
    final meetingsAsync = ref.watch(meetingsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isNationalScope
              ? 'National Assembly Meetings & Minutes'
              : 'Meetings & Minutes Archive',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(meetingsStreamProvider),
          ),
          if (canManage)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Schedule Meeting',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MeetingDetailScreen(),
                  ),
                );
                ref.invalidate(meetingsStreamProvider);
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.brandGreen,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: AppTheme.brandGreen,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              icon: Icon(Icons.event),
              text: 'Upcoming',
            ),
            Tab(
              icon: Icon(Icons.history_edu),
              text: 'Past & Minutes',
            ),
          ],
        ),
      ),
      body: meetingsAsync.when(
        data: (allMeetings) {
          final now = DateTime.now();
          final upcomingThreshold = now.subtract(const Duration(hours: 4));
          final isExecutive = user?.isExecutive ?? false;

          // Audience filtering: ordinary members cannot see executive-only meetings
          final accessibleMeetings = allMeetings.where((m) {
            if (m.isExecutivesOnly && !isExecutive) return false;
            return true;
          }).toList();

          final upcomingMeetings = accessibleMeetings
              .where((m) => m.meetingDate.isAfter(upcomingThreshold))
              .toList()
            ..sort((a, b) => a.meetingDate.compareTo(b.meetingDate));

          final pastMeetings = accessibleMeetings
              .where((m) => !m.meetingDate.isAfter(upcomingThreshold))
              .toList()
            ..sort((a, b) => b.meetingDate.compareTo(a.meetingDate));

          return Column(
            children: [
              // Search & Filter header
              _buildSearchAndFilterHeader(theme, isNationalScope),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _MeetingsListTab(
                      meetings: _filterMeetings(upcomingMeetings),
                      isPastTab: false,
                      canManage: canManage,
                      onMeetingTap: (m) => _openMeetingDetail(m, canManage),
                    ),
                    _MeetingsListTab(
                      meetings: _filterMeetings(pastMeetings),
                      isPastTab: true,
                      canManage: canManage,
                      onMeetingTap: (m) => _openMeetingDetail(m, canManage),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text('Failed to load meetings: $err'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(meetingsStreamProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MeetingDetailScreen(),
                  ),
                );
                ref.invalidate(meetingsStreamProvider);
              },
              icon: const Icon(Icons.add),
              label: const Text('New Meeting'),
            )
          : null,
    );
  }

  Widget _buildSearchAndFilterHeader(ThemeData theme, bool isNationalScope) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          // Search box
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search title, venue, or minutes...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'All Meetings'),
                const SizedBox(width: 8),
                _buildFilterChip('minutes', '📝 Has Minutes'),
                const SizedBox(width: 8),
                if (!isNationalScope) ...[
                  _buildFilterChip('branch', 'Branch Only'),
                  const SizedBox(width: 8),
                  _buildFilterChip('national', 'National Assembly'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterId, String label) {
    final isSelected = _selectedFilter == filterId;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : null,
      ),
      selectedColor: AppTheme.brandGreen,
      onSelected: (_) {
        setState(() {
          _selectedFilter = filterId;
        });
      },
    );
  }

  List<MeetingModel> _filterMeetings(List<MeetingModel> meetings) {
    return meetings.where((m) {
      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final title = m.title.toLowerCase();
        final venue = m.venue.toLowerCase();
        final minutes = m.minutesText?.toLowerCase() ?? '';
        final matches = title.contains(_searchQuery) ||
            venue.contains(_searchQuery) ||
            minutes.contains(_searchQuery);
        if (!matches) return false;
      }

      // Filter chips
      if (_selectedFilter == 'minutes') {
        if (!m.hasMinutes) return false;
      } else if (_selectedFilter == 'national') {
        final isNational = m.scope == 'national' || m.branchId == 'national';
        if (!isNational) return false;
      } else if (_selectedFilter == 'branch') {
        final isNational = m.scope == 'national' || m.branchId == 'national';
        if (isNational) return false;
      }

      return true;
    }).toList();
  }

  Future<void> _openMeetingDetail(MeetingModel meeting, bool canManage) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeetingDetailScreen(
          meeting: meeting,
          readOnly: !canManage,
        ),
      ),
    );
    if (mounted) {
      ref.invalidate(meetingsStreamProvider);
    }
  }
}

class _MeetingsListTab extends StatelessWidget {
  final List<MeetingModel> meetings;
  final bool isPastTab;
  final bool canManage;
  final ValueChanged<MeetingModel> onMeetingTap;

  const _MeetingsListTab({
    required this.meetings,
    required this.isPastTab,
    required this.canManage,
    required this.onMeetingTap,
  });

  @override
  Widget build(BuildContext context) {
    if (meetings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPastTab ? Icons.history_edu : Icons.event_available,
                size: 56,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                isPastTab
                    ? 'No past meeting minutes found'
                    : 'No upcoming meetings scheduled',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isPastTab
                    ? 'Official minutes will appear here once meetings conclude and the Secretary publishes them.'
                    : 'Newly scheduled meetings with agendas will appear here.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final dateFormat = DateFormat('EEE, MMM dd, yyyy \u2022 hh:mm a');

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.paddingOf(context).bottom + 80,
      ),
      itemCount: meetings.length,
      itemBuilder: (context, index) {
        final meeting = meetings[index];
        final theme = Theme.of(context);
        final isNational = meeting.scope == 'national' || meeting.branchId == 'national';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: meeting.hasMinutes && isPastTab
                  ? Colors.green.withValues(alpha: 0.35)
                  : theme.dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onMeetingTap(meeting),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges Wrap: Scope & Audience & Minutes Status
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Scope badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isNational
                              ? Colors.purple.withValues(alpha: 0.12)
                              : Colors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isNational ? 'National Assembly' : 'Branch Meeting',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isNational ? Colors.purple.shade700 : Colors.blue.shade700,
                          ),
                        ),
                      ),
                      // Audience badge
                      if (meeting.isExecutivesOnly)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield_outlined, size: 12, color: Colors.deepOrange.shade800),
                              const SizedBox(width: 4),
                              Text(
                                'Executives Only',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.deepOrange.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Minutes status indicator (especially for past meetings)
                      if (isPastTab)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: meeting.hasMinutes
                                ? Colors.green.withValues(alpha: 0.15)
                                : Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                meeting.hasMinutes ? Icons.check_circle : Icons.pending_outlined,
                                size: 13,
                                color: meeting.hasMinutes ? Colors.green.shade700 : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                meeting.hasMinutes ? 'Minutes Ready' : 'Pending Minutes',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: meeting.hasMinutes ? Colors.green.shade800 : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Title
                  Text(
                    meeting.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Date & Time
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        dateFormat.format(meeting.meetingDate),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),

                  // Venue
                  if (meeting.venue.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            meeting.venue,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Minutes Snippet Preview (for past meetings)
                  if (isPastTab && meeting.hasMinutes) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.article_outlined, size: 14, color: Colors.green.shade700),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Recorded Proceedings Snippet:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (meeting.minutesFileUrl?.isNotEmpty == true) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.attach_file, size: 13, color: Colors.green.shade800),
                                const SizedBox(width: 2),
                                Text(
                                  'Doc Attached',
                                  style: TextStyle(fontSize: 11, color: Colors.green.shade800),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            meeting.minutesText?.isNotEmpty == true
                                ? meeting.minutesText!
                                : 'Attached scan/document available. Tap to view full proceedings.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade800,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),
                  // Tap to View / Edit Action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        canManage ? 'Edit / Document Minutes' : 'View Minutes & Details',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
