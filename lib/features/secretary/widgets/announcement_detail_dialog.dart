import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../models/announcement_model.dart';
import '../../meetings/views/meeting_list_screen.dart';

/// Displays a rich modal dialog to view the full details of an [AnnouncementModel].
/// Allows users across all roles to read complete meeting agendas, venue info,
/// times, and proceedings without truncation.
void showAnnouncementDetailDialog(
  BuildContext context,
  AnnouncementModel announcement,
) {
  showDialog(
    context: context,
    builder: (ctx) => AnnouncementDetailDialog(announcement: announcement),
  );
}

class AnnouncementDetailDialog extends StatelessWidget {
  final AnnouncementModel announcement;

  const AnnouncementDetailDialog({super.key, required this.announcement});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('EEEE, MMM dd, yyyy');
    final date = announcement.announcementDate ?? announcement.createdAt;
    final isMeeting = announcement.category == AnnouncementCategory.meeting;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row: Category Badge, Pin, Close icon
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isMeeting
                          ? Colors.indigo.withValues(alpha: 0.12)
                          : theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isMeeting ? Icons.event : Icons.campaign,
                          size: 14,
                          color: isMeeting ? Colors.indigo : theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          announcement.category.name.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isMeeting ? Colors.indigo : theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (announcement.isPinned) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.push_pin, size: 12, color: Colors.red),
                          SizedBox(width: 4),
                          Text(
                            'PINNED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                announcement.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),

              // Meta Information Panel (Date, Time, Venue, Audience)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            announcement.formattedTime != null
                                ? '${dateFormat.format(date)} \u2022 ${announcement.formattedTime}'
                                : dateFormat.format(date),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (announcement.effectiveVenue != null &&
                        announcement.effectiveVenue!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              announcement.effectiveVenue!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (announcement.audienceLabel != 'Everyone') ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.group_outlined,
                            size: 14,
                            color: theme.colorScheme.secondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              announcement.audienceLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Body / Agenda / Proceedings
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isMeeting) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.format_list_bulleted,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Meeting Agenda & Proceedings:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      SelectableText(
                        announcement.body.isNotEmpty
                            ? announcement.body
                            : 'No additional details provided.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  if (isMeeting) ...[
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary(context),
                        ),
                        icon: const Icon(Icons.history_edu, size: 18),
                        label: const Text('View Meetings & RSVP'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const MeetingListScreen(initialTabIndex: 0),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
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
