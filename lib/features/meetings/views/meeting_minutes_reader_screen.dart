import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/meeting_provider.dart';
import '../models/meeting_model.dart';

/// Full-screen dedicated reader for official meeting minutes and proceedings.
class MeetingMinutesReaderScreen extends ConsumerWidget {
  final MeetingModel meeting;

  const MeetingMinutesReaderScreen({super.key, required this.meeting});

  Future<void> _openFile(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open attached file')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final liveMeeting =
        ref.watch(singleMeetingStreamProvider(meeting.id)).valueOrNull ?? meeting;

    final dateFormat = DateFormat('EEEE, MMMM dd, yyyy \u2022 hh:mm a');
    final minutesText = (liveMeeting.minutesText != null &&
            liveMeeting.minutesText!.trim().isNotEmpty)
        ? liveMeeting.minutesText!.trim()
        : 'Official minutes proceedings documented. See attached files for complete signed secretarial records.';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Official Minutes Reader'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy Minutes',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: minutesText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Official minutes copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Formal Gazette Header ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.surface
                      : Colors.green.shade50.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified,
                                color: Colors.white,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'OFFICIAL PROCEEDINGS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          liveMeeting.isExecutivesOnly
                              ? 'EXECUTIVE SITTING'
                              : 'GENERAL SITTING',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: liveMeeting.isExecutivesOnly
                                ? Colors.deepOrange
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      liveMeeting.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 15,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            dateFormat.format(liveMeeting.meetingDate),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            liveMeeting.venue.isNotEmpty
                                ? liveMeeting.venue
                                : 'General Assembly',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Adoption & Ratification Seal (if adopted) ──
              if (liveMeeting.isAdopted) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.how_to_reg, color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Formally Adopted & Ratified',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (liveMeeting.movedBy?.isNotEmpty == true)
                        Text(
                          '• Motion Moved By: ${liveMeeting.movedBy}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (liveMeeting.secondedBy?.isNotEmpty == true)
                        Text(
                          '• Seconded By: ${liveMeeting.secondedBy}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (liveMeeting.adoptedAt != null)
                        Text(
                          '• Date Ratified: ${DateFormat('MMMM dd, yyyy').format(liveMeeting.adoptedAt!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      if (liveMeeting.adoptionNotes?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Amendments: ${liveMeeting.adoptionNotes}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ── Official Deliberations Body ──
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.4,
                    ),
                  ),
                ),
                color: isDark
                    ? theme.colorScheme.surface
                    : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.article_outlined,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'OFFICIAL DELIBERATIONS & RECORD',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      SelectableText(
                        minutesText,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.75,
                          letterSpacing: 0.2,
                          color: isDark ? const Color(0xFFE8ECE9) : const Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Attached Signed Document / PDF Preview ──
              if (liveMeeting.minutesFileUrl != null &&
                  liveMeeting.minutesFileUrl!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: Colors.green.withValues(alpha: 0.35),
                    ),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf,
                        color: Colors.green,
                        size: 22,
                      ),
                    ),
                    title: Text(
                      liveMeeting.minutesFileName ?? 'Official Signed Document',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Tap to view formal scanned copy'),
                    trailing: const Icon(
                      Icons.open_in_new,
                      color: Colors.green,
                      size: 20,
                    ),
                    onTap: () => _openFile(context, liveMeeting.minutesFileUrl!),
                  ),
                ),
              ],

              // ── Resolutions & Action Items Register ──
              if (liveMeeting.resolutions.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Sitting Resolutions & Action Register (${liveMeeting.resolutions.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                ...liveMeeting.resolutions.map((r) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    color: r.isCompleted
                        ? Colors.green.withValues(alpha: 0.05)
                        : theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: r.isCompleted
                            ? Colors.green.withValues(alpha: 0.3)
                            : theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.4),
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
                          color: r.isCompleted ? Colors.grey : null,
                        ),
                      ),
                      subtitle: Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (r.assigneeName != null &&
                              r.assigneeName!.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  size: 13,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  r.assigneeName!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          if (r.dueDate != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.alarm,
                                  size: 13,
                                  color: Colors.orange.shade800,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Due: ${DateFormat('MMM dd').format(r.dueDate!)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],

              // ── Secretarial Attestation Footer ──
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.shield_outlined, color: Colors.grey, size: 28),
                    const SizedBox(height: 6),
                    Text(
                      'Official Document of the Secretariat',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'This record constitutes the formal minutes and deliberations of the assembly. Financial records are immutable.',
                      textAlign: TextAlign.center,
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
      ),
    );
  }
}
