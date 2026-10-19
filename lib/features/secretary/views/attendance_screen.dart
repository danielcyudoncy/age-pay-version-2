// features/secretary/views/attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/meetings/controllers/meeting_provider.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/secretary/controllers/attendance_provider.dart';
import 'package:cls/features/secretary/controllers/secretary_dashboard_provider.dart';
import 'package:cls/features/secretary/models/attendance_model.dart';
import 'package:cls/features/meetings/models/meeting_rsvp_model.dart';
import 'package:cls/features/meetings/controllers/meeting_rsvp_provider.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Attendance Register'),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.analytics_outlined),
                text: 'Annual Review',
              ),
              Tab(
                icon: Icon(Icons.fact_check_outlined),
                text: 'Roll Call',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AnnualReviewTab(),
            _RollCallTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 1: ANNUAL REVIEW
// ---------------------------------------------------------------------------
class _AnnualReviewTab extends ConsumerStatefulWidget {
  const _AnnualReviewTab();

  @override
  ConsumerState<_AnnualReviewTab> createState() => _AnnualReviewTabState();
}

class _AnnualReviewTabState extends ConsumerState<_AnnualReviewTab> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedYear = ref.watch(selectedAttendanceYearProvider);
    final statsAsync = ref.watch(annualAttendanceStatsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(meetingsStreamProvider);
        ref.invalidate(membersStreamProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildYearSelector(context, selectedYear),
          const SizedBox(height: 16),
          statsAsync.when(
            data: (stats) => _buildStatsContent(context, stats, theme),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: theme.colorScheme.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Failed to load annual stats: $err',
                        style: TextStyle(color: theme.colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearSelector(BuildContext context, int selectedYear) {
    final theme = Theme.of(context);
    final currentYear = DateTime.now().year;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous Year',
            onPressed: () {
              ref.read(selectedAttendanceYearProvider.notifier).state =
                  selectedYear - 1;
            },
          ),
          Row(
            children: [
              Icon(Icons.calendar_month, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: selectedYear,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  items: List.generate(7, (index) {
                    final yr = currentYear + 1 - index;
                    return DropdownMenuItem(
                      value: yr,
                      child: Text('$yr Review'),
                    );
                  }),
                  onChanged: (newYear) {
                    if (newYear != null) {
                      ref.read(selectedAttendanceYearProvider.notifier).state =
                          newYear;
                    }
                  },
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next Year',
            onPressed: selectedYear >= currentYear + 1
                ? null
                : () {
                    ref.read(selectedAttendanceYearProvider.notifier).state =
                        selectedYear + 1;
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsContent(
    BuildContext context,
    AnnualAttendanceStats stats,
    ThemeData theme,
  ) {
    final filteredMembers = stats.memberSummaries.where((m) {
      if (_searchQuery.isEmpty) return true;
      return m.memberName.toLowerCase().contains(_searchQuery);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI Cards Grid
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Meetings Held',
                value: stats.totalMeetingsHeld.toString(),
                icon: Icons.event,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'Average Rate',
                value: '${stats.averageAttendanceRate.toStringAsFixed(1)}%',
                icon: Icons.pie_chart,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: '100% Attended',
                value: stats.perfectAttendanceCount.toString(),
                icon: Icons.verified,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'Below 50% Rate',
                value: stats.lowAttendanceCount.toString(),
                icon: Icons.warning_amber_rounded,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Member Register Header & Search
        Row(
          children: [
            Expanded(
              child: Text(
                'Member Annual Register',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${filteredMembers.length} Members',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search member by name...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (val) {
            setState(() => _searchQuery = val.trim().toLowerCase());
          },
        ),
        const SizedBox(height: 16),

        // Member List
        if (stats.totalMeetingsHeld == 0)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No meetings recorded in ${stats.year}',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Schedule meetings and record roll call to build the annual register.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (filteredMembers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('No matching members found')),
          )
        else
          ...filteredMembers.map((summary) {
            return _MemberAnnualCard(
              summary: summary,
              onTap: () => _showMemberAttendanceDetail(context, summary, stats.year),
            );
          }),
      ],
    );
  }

  void _showMemberAttendanceDetail(
    BuildContext context,
    MemberAnnualAttendance summary,
    int year,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MemberAttendanceDetailSheet(
        summary: summary,
        year: year,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MEMBER ANNUAL CARD WIDGET
// ---------------------------------------------------------------------------
class _MemberAnnualCard extends StatelessWidget {
  final MemberAnnualAttendance summary;
  final VoidCallback onTap;

  const _MemberAnnualCard({
    required this.summary,
    required this.onTap,
  });

  Color _rateColor(double rate) {
    if (rate >= 80) return Colors.green;
    if (rate >= 50) return Colors.orange;
    return Colors.red;
  }

  String _statusLabel(double rate) {
    if (rate >= 80) return 'Good Standing';
    if (rate >= 50) return 'Fair';
    return 'Attention Needed';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rate = summary.attendanceRate;
    final rateColor = _rateColor(rate);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      summary.memberName.isNotEmpty
                          ? summary.memberName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
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
                          summary.memberName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: rateColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _statusLabel(rate),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: rateColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${rate.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: rateColor,
                        ),
                      ),
                      Text(
                        '${summary.attendedCount}/${summary.totalMeetings}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: summary.totalMeetings > 0 ? (rate / 100.0) : 0.0,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(rateColor),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _BadgeCount(
                    label: 'Present',
                    count: summary.presentCount,
                    color: Colors.green,
                  ),
                  _BadgeCount(
                    label: 'Late',
                    count: summary.lateCount,
                    color: Colors.orange,
                  ),
                  _BadgeCount(
                    label: 'Absent',
                    count: summary.absentCount,
                    color: Colors.red,
                  ),
                  if (summary.excusedCount > 0)
                    _BadgeCount(
                      label: 'Excused',
                      count: summary.excusedCount,
                      color: Colors.blue,
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

class _BadgeCount extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _BadgeCount({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DETAIL BOTTOM SHEET: MEMBER'S ANNUAL BREAKDOWN
// ---------------------------------------------------------------------------
class _MemberAttendanceDetailSheet extends StatelessWidget {
  final MemberAnnualAttendance summary;
  final int year;

  const _MemberAttendanceDetailSheet({
    required this.summary,
    required this.year,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    summary.memberName.isNotEmpty
                        ? summary.memberName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.memberName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$year Annual Attendance History',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${summary.attendanceRate.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: summary.records.isEmpty
                ? const Center(
                    child: Text('No meeting records found for this year'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: summary.records.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final rec = summary.records[index];
                      return Card(
                        margin: EdgeInsets.zero,
                        elevation: 0,
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        child: ListTile(
                          title: Text(
                            rec.meetingTitle,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(dateFormat.format(rec.meetingDate)),
                          trailing: _StatusBadge(status: rec.status),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final AttendanceStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case AttendanceStatus.present:
        color = Colors.green;
        label = 'Present';
        break;
      case AttendanceStatus.late:
        color = Colors.orange;
        label = 'Late';
        break;
      case AttendanceStatus.absent:
        color = Colors.red;
        label = 'Absent';
        break;
      case AttendanceStatus.excused:
        color = Colors.blue;
        label = 'Excused';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 2: ROLL CALL / MARK ATTENDANCE
// ---------------------------------------------------------------------------
class _RollCallTab extends ConsumerStatefulWidget {
  const _RollCallTab();

  @override
  ConsumerState<_RollCallTab> createState() => _RollCallTabState();
}

class _RollCallTabState extends ConsumerState<_RollCallTab> {
  String? _selectedMeetingId;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meetingsAsync = ref.watch(meetingsStreamProvider);
    final membersAsync = ref.watch(membersStreamProvider);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(meetingsStreamProvider);
        ref.invalidate(membersStreamProvider);
        if (_selectedMeetingId != null) {
          ref.invalidate(attendanceStreamProvider(_selectedMeetingId!));
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Select Meeting',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          meetingsAsync.when(
            data: (meetings) {
              if (meetings.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No meetings available yet. Create a meeting first.'),
                  ),
                );
              }

              // Auto-select the latest meeting if none selected
              _selectedMeetingId ??= meetings.first.id;

              return DropdownButtonFormField<String>(
                initialValue: _selectedMeetingId,
                decoration: InputDecoration(
                  labelText: 'Meeting Session',
                  prefixIcon: const Icon(Icons.event),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: meetings.map((m) {
                  return DropdownMenuItem(
                    value: m.id,
                    child: Text(
                      '${m.title} (${dateFormat.format(m.meetingDate)})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedMeetingId = val);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('Failed to load meetings: $err'),
          ),
          const SizedBox(height: 16),

          if (_selectedMeetingId != null) ...[
            _RollCallMeetingStats(meetingId: _selectedMeetingId!),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search roster by name...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val.trim().toLowerCase());
              },
            ),
            const SizedBox(height: 12),
            membersAsync.when(
              data: (rawMembers) {
                final members = rawMembers.whereType<MemberModel>().toList();
                final filtered = members.where((m) {
                  if (_searchQuery.isEmpty) return true;
                  return m.fullName.toLowerCase().contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No members found in roster')),
                  );
                }

                return _MeetingMemberRoster(
                  meetingId: _selectedMeetingId!,
                  members: filtered,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Failed to load members: $err'),
            ),
          ],
        ],
      ),
    );
  }
}

class _RollCallMeetingStats extends ConsumerWidget {
  final String meetingId;

  const _RollCallMeetingStats({required this.meetingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsync = ref.watch(attendanceStreamProvider(meetingId));

    return attendanceAsync.when(
      data: (records) {
        final presentCount =
            records.where((r) => r.status == AttendanceStatus.present).length;
        final lateCount =
            records.where((r) => r.status == AttendanceStatus.late).length;
        final excusedCount =
            records.where((r) => r.status == AttendanceStatus.excused).length;
        final absentCount =
            records.where((r) => r.status == AttendanceStatus.absent).length;

        return Row(
          children: [
            Expanded(
              child: _MiniStatusStat(
                label: 'Present',
                count: presentCount,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _MiniStatusStat(
                label: 'Late',
                count: lateCount,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _MiniStatusStat(
                label: 'Excused',
                count: excusedCount,
                color: Colors.purple,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _MiniStatusStat(
                label: 'Absent',
                count: absentCount,
                color: Colors.red,
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _MiniStatusStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _MiniStatusStat({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MeetingMemberRoster extends ConsumerWidget {
  final String meetingId;
  final List<MemberModel> members;

  const _MeetingMemberRoster({
    required this.meetingId,
    required this.members,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsync = ref.watch(attendanceStreamProvider(meetingId));
    final rsvpsAsync = ref.watch(meetingRsvpsStreamProvider(meetingId));

    final recordedMap = {
      for (final a in (attendanceAsync.valueOrNull ?? [])) a.memberId: a.status
    };
    final rsvpMap = {
      for (final r in (rsvpsAsync.valueOrNull ?? [])) r.memberId: r
    };

    return Column(
      children: members.map((member) {
        final currentStatus = recordedMap[member.id];
        final rsvp = rsvpMap[member.id];

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0.5,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (rsvp != null) ...[
                        const SizedBox(height: 2),
                        if (rsvp.status == MeetingRsvpStatus.excused)
                          Row(
                            children: [
                              Icon(
                                Icons.assignment_late_outlined,
                                size: 12,
                                color: Colors.purple.shade700,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Excuse: ${rsvp.reason.isNotEmpty ? rsvp.reason : "Apology submitted"}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.purple.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        else if (rsvp.status == MeetingRsvpStatus.late)
                          Text(
                            'RSVP: Coming late${rsvp.reason.isNotEmpty ? " (${rsvp.reason})" : ""}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        else
                          Text(
                            'RSVP: Confirmed Coming',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RollCallButton(
                      label: 'P',
                      color: Colors.green,
                      isSelected: currentStatus == AttendanceStatus.present,
                      onTap: () => _mark(
                        ref,
                        member.id,
                        member.fullName,
                        AttendanceStatus.present,
                      ),
                    ),
                    const SizedBox(width: 5),
                    _RollCallButton(
                      label: 'L',
                      color: Colors.orange,
                      isSelected: currentStatus == AttendanceStatus.late,
                      onTap: () => _mark(
                        ref,
                        member.id,
                        member.fullName,
                        AttendanceStatus.late,
                      ),
                    ),
                    const SizedBox(width: 5),
                    _RollCallButton(
                      label: 'E',
                      color: Colors.purple,
                      isSelected: currentStatus == AttendanceStatus.excused,
                      onTap: () => _mark(
                        ref,
                        member.id,
                        member.fullName,
                        AttendanceStatus.excused,
                      ),
                    ),
                    const SizedBox(width: 5),
                    _RollCallButton(
                      label: 'A',
                      color: Colors.red,
                      isSelected: currentStatus == AttendanceStatus.absent,
                      onTap: () => _mark(
                        ref,
                        member.id,
                        member.fullName,
                        AttendanceStatus.absent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _mark(
    WidgetRef ref,
    String memberId,
    String memberName,
    AttendanceStatus status,
  ) async {
    final controller = ref.read(attendanceControllerProvider);
    final user = ref.read(authProvider).valueOrNull;
    if (user == null) return;
    final orgId =
        user.organizationId.isNotEmpty ? user.organizationId : user.uid;

    final attendance = AttendanceModel(
      id: '${meetingId}_$memberId',
      organizationId: orgId,
      meetingId: meetingId,
      memberId: memberId,
      memberName: memberName,
      status: status,
      recordedAt: DateTime.now(),
      recordedBy: user.uid,
    );
    await controller.recordAttendance(attendance);
    ref.invalidate(attendanceStreamProvider(meetingId));
    ref.invalidate(organizationAttendanceStreamProvider(orgId));
  }
}

class _RollCallButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _RollCallButton({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 38,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.4),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BACKWARD-COMPATIBLE WRAPPER
// ---------------------------------------------------------------------------
class MeetingAttendanceScreen extends StatelessWidget {
  final String meetingId;
  const MeetingAttendanceScreen({super.key, required this.meetingId});

  @override
  Widget build(BuildContext context) {
    return const AttendanceScreen();
  }
}
