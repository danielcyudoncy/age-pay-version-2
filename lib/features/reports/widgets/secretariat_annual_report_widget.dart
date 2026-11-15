import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/enums.dart';
import '../controllers/reports_provider.dart';

class SecretariatAnnualReportWidget extends StatelessWidget {
  final ReportRequest request;

  const SecretariatAnnualReportWidget({super.key, required this.request});

  static final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final year = request.year ?? DateTime.now().year;
    final meetings = request.meetings;
    final members = request.members;

    // Analytics calculations
    final totalMeetings = meetings.length;
    final documentedMinutes = meetings.where((m) => m.hasMinutes).length;
    final adoptedMinutes = meetings.where((m) => m.isAdopted).length;

    // Resolutions aggregated from all meetings in this year
    final allResolutions = meetings.expand((m) => m.resolutions).toList();
    final completedResolutions =
        allResolutions.where((r) => r.isCompleted).length;

    // Membership lifecycle counts
    final activeMembers = members
        .where((m) => m.lifecycleStatus == MembershipLifecycleStatus.active)
        .length;
    final probationaryMembers = members
        .where(
          (m) => m.lifecycleStatus == MembershipLifecycleStatus.probationary,
        )
        .length;
    final suspendedMembers = members
        .where((m) => m.lifecycleStatus == MembershipLifecycleStatus.suspended)
        .length;
    final diasporaMembers = members
        .where((m) => m.lifecycleStatus == MembershipLifecycleStatus.diaspora)
        .length;
    final deceasedMembers = members
        .where((m) => m.lifecycleStatus == MembershipLifecycleStatus.deceased)
        .length;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.paddingOf(context).bottom + 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.12),
                  theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.35,
                  ),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: theme.colorScheme.primary,
                      child: const Icon(
                        Icons.history_edu,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.organizationName ?? 'Central Organisation',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${request.branchName ?? "Branch Secretariat"} \u2022 $year Annual Activity Report',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 6),
                Text(
                  'Official Secretariat Dossier documenting constitutional assembly sittings, secretarial minutes ratifications, resolutions executed, and member roster statistics.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // KPI Grid Row 1
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  label: 'Meetings Held',
                  value: '$totalMeetings',
                  subtext: '$documentedMinutes documented',
                  icon: Icons.event,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiCard(
                  label: 'Minutes Adopted',
                  value: '$adoptedMinutes',
                  subtext:
                      totalMeetings > 0
                          ? '${((adoptedMinutes / totalMeetings) * 100).toStringAsFixed(0)}% ratified'
                          : '0% ratified',
                  icon: Icons.verified,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // KPI Grid Row 2
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  label: 'Resolutions Logged',
                  value: '${allResolutions.length}',
                  subtext: '$completedResolutions completed',
                  icon: Icons.task_alt,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiCard(
                  label: 'Total Members',
                  value: '${members.length}',
                  subtext: '$activeMembers active in roster',
                  icon: Icons.people,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Section 1: Membership Movements & Lifecycle
          Text(
            'Membership Roll & Vital Statistics',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _StatusBreakdownRow(
                    label: 'Active Members in Good Standing',
                    count: activeMembers,
                    color: Colors.green,
                    icon: Icons.check_circle_outline,
                  ),
                  const Divider(height: 16),
                  _StatusBreakdownRow(
                    label: 'Probationary Members (New Intakes)',
                    count: probationaryMembers,
                    color: Colors.amber.shade800,
                    icon: Icons.hourglass_top_outlined,
                  ),
                  const Divider(height: 16),
                  _StatusBreakdownRow(
                    label: 'Diaspora & Relocated Members',
                    count: diasporaMembers,
                    color: Colors.indigo,
                    icon: Icons.flight_takeoff,
                  ),
                  const Divider(height: 16),
                  _StatusBreakdownRow(
                    label: 'Members Under Disciplinary Suspension',
                    count: suspendedMembers,
                    color: Colors.red,
                    icon: Icons.pause_circle_outline,
                  ),
                  const Divider(height: 16),
                  _StatusBreakdownRow(
                    label: 'Deceased Members (In Memoriam)',
                    count: deceasedMembers,
                    color: Colors.grey.shade700,
                    icon: Icons.sentiment_neutral,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section 2: Meeting Minutes & Adoption Register
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Meeting Sittings & Minutes Log ($totalMeetings)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (meetings.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No assembly or executive meetings on record for $year.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            )
          else
            ...meetings.map((meeting) {
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.4,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                meeting.isAdopted
                                    ? Colors.green.withValues(alpha: 0.12)
                                    : (meeting.hasMinutes
                                        ? Colors.blue.withValues(alpha: 0.12)
                                        : Colors.amber.withValues(alpha: 0.12)),
                            child: Icon(
                              meeting.isAdopted
                                  ? Icons.verified
                                  : (meeting.hasMinutes
                                      ? Icons.description
                                      : Icons.pending),
                              size: 18,
                              color:
                                  meeting.isAdopted
                                      ? Colors.green
                                      : (meeting.hasMinutes
                                          ? Colors.blue
                                          : Colors.amber.shade800),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  meeting.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_dateFormat.format(meeting.meetingDate)} \u2022 ${meeting.venue.isNotEmpty ? meeting.venue : "Secretariat"}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  meeting.isAdopted
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              meeting.isAdopted
                                  ? 'Adopted'
                                  : (meeting.hasMinutes
                                      ? 'Minutes Ready'
                                      : 'Pending Minutes'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color:
                                    meeting.isAdopted
                                        ? Colors.green.shade800
                                        : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (meeting.isAdopted) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Adopted: Moved by ${meeting.movedBy ?? "N/A"} \u2022 Seconded by ${meeting.secondedBy ?? "N/A"}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      if (meeting.resolutions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${meeting.resolutions.length} Action Item(s) logged (${meeting.resolutions.where((r) => r.isCompleted).length} completed)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 24),

          // Section 3: Resolutions & Matters Arising
          Text(
            'Annual Resolutions & Matters Arising (${allResolutions.length})',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          if (allResolutions.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No specific resolutions recorded in the minutes for $year.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            )
          else
            ...allResolutions.map((r) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                color:
                    r.isCompleted
                        ? Colors.green.withValues(alpha: 0.04)
                        : theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.35,
                        ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color:
                        r.isCompleted
                            ? Colors.green.withValues(alpha: 0.25)
                            : theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.4,
                            ),
                  ),
                ),
                child: ListTile(
                  leading: Icon(
                    r.isCompleted
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: r.isCompleted ? Colors.green : Colors.grey,
                  ),
                  title: Text(
                    r.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration:
                          r.isCompleted ? TextDecoration.lineThrough : null,
                      color: r.isCompleted ? Colors.grey.shade700 : null,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      if (r.assigneeName != null &&
                          r.assigneeName!.isNotEmpty) ...[
                        Text(
                          'Assigned: ${r.assigneeName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (r.dueDate != null)
                        Text(
                          'Due: ${_dateFormat.format(r.dueDate!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade800,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 28),

          // Official Sign-Off Block
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Secretariat Attestation',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 6),
                const Text(
                  'We hereby certify that the contents of this Annual Secretarial Dossier represent a complete, truthful, and verified account of all assembly meetings, deliberations, and secretarial records.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 140,
                          height: 1,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'General Secretary',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const Text(
                          'Executive Secretariat',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 140,
                          height: 1,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'President / Chairman',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const Text(
                          'Executive Council',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtext;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.subtext,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: color,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            Text(
              subtext,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBreakdownRow extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _StatusBreakdownRow({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
