import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../controllers/meeting_rsvp_provider.dart';
import '../models/meeting_rsvp_model.dart';

class MeetingExcusesSection extends ConsumerStatefulWidget {
  final String meetingId;

  const MeetingExcusesSection({super.key, required this.meetingId});

  @override
  ConsumerState<MeetingExcusesSection> createState() =>
      _MeetingExcusesSectionState();
}

class _MeetingExcusesSectionState extends ConsumerState<MeetingExcusesSection> {
  int _selectedFilterIndex = 0; // 0 = Excuses, 1 = Coming, 2 = Coming Late

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rsvpsAsync = ref.watch(meetingRsvpsStreamProvider(widget.meetingId));

    return rsvpsAsync.when(
      data: (rsvps) {
        final excusedList =
            rsvps.where((r) => r.status == MeetingRsvpStatus.excused).toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        final attendingList =
            rsvps.where((r) => r.status == MeetingRsvpStatus.attending).toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        final lateList =
            rsvps.where((r) => r.status == MeetingRsvpStatus.late).toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.speaker_notes,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'House RSVPs & Excuses',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${rsvps.length} responses',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Summary Chips Row / Selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: 'Excuses',
                        count: excusedList.length,
                        color: Colors.redAccent,
                        icon: Icons.cancel_outlined,
                        isSelected: _selectedFilterIndex == 0,
                        onTap: () => setState(() => _selectedFilterIndex = 0),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Coming',
                        count: attendingList.length,
                        color: Colors.green,
                        icon: Icons.check_circle_outline,
                        isSelected: _selectedFilterIndex == 1,
                        onTap: () => setState(() => _selectedFilterIndex = 1),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Coming Late',
                        count: lateList.length,
                        color: Colors.amber.shade800,
                        icon: Icons.schedule,
                        isSelected: _selectedFilterIndex == 2,
                        onTap: () => setState(() => _selectedFilterIndex = 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                // Content View according to selected filter
                if (_selectedFilterIndex == 0)
                  _buildExcusesView(context, theme, excusedList)
                else if (_selectedFilterIndex == 1)
                  _buildAttendeesView(context, theme, attendingList, 'Coming')
                else
                  _buildAttendeesView(
                    context,
                    theme,
                    lateList,
                    'Coming Late',
                    showReason: true,
                  ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text('Could not load RSVPs: $err'),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(width: 6),
            Text(
              '$label ($count)',
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExcusesView(
    BuildContext context,
    ThemeData theme,
    List<MeetingRsvpModel> excuses,
  ) {
    if (excuses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.mark_chat_read_outlined,
                size: 36,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 8),
              Text(
                'No absence excuses submitted for this meeting.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    final dateFormat = DateFormat('MMM d \u2022 h:mm a');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.assignment_late_outlined, size: 16, color: Colors.redAccent),
            const SizedBox(width: 6),
            Text(
              'Apologies for Absence (${excuses.length})',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: excuses.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final excuse = excuses[index];
            final initial = excuse.memberName.isNotEmpty
                ? excuse.memberName[0].toUpperCase()
                : 'M';

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.redAccent.shade100,
                        child: Text(
                          initial,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          excuse.memberName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Excused',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.format_quote,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            excuse.reason.isNotEmpty
                                ? excuse.reason
                                : 'Absence apology tendered.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade800,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Submitted ${dateFormat.format(excuse.updatedAt)}',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAttendeesView(
    BuildContext context,
    ThemeData theme,
    List<MeetingRsvpModel> attendees,
    String title, {
    bool showReason = false,
  }) {
    if (attendees.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'No members marked as $title yet.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title (${attendees.length})',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: attendees.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final member = attendees[index];
            final initial = member.memberName.isNotEmpty
                ? member.memberName[0].toUpperCase()
                : 'M';

            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: showReason
                    ? Colors.amber.shade100
                    : Colors.green.shade100,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: showReason
                        ? Colors.amber.shade900
                        : Colors.green.shade900,
                  ),
                ),
              ),
              title: Text(
                member.memberName,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              subtitle: showReason && member.reason.isNotEmpty
                  ? Text(
                      'Note: ${member.reason}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  : null,
              trailing: Icon(
                showReason ? Icons.schedule : Icons.check_circle,
                size: 16,
                color: showReason ? Colors.amber.shade800 : Colors.green,
              ),
            );
          },
        ),
      ],
    );
  }
}
