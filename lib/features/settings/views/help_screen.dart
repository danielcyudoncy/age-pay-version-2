import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const String _supportPhone = '2348029228315';

  static const List<_HelpTopic> _topics = [
    _HelpTopic(
      icon: Icons.people_outline,
      title: 'Managing members',
      body: 'Open the Members tab to view, search, and update member records. '
          'Tap a member to see their profile, contributions, and obligations.',
    ),
    _HelpTopic(
      icon: Icons.campaign_outlined,
      title: 'Posting announcements',
      body: 'Go to Announcements and tap the add button. Announcements can be '
          'pinned or scheduled to keep members informed.',
    ),
    _HelpTopic(
      icon: Icons.event_outlined,
      title: 'Recording meetings',
      body: 'Use the Meetings tab to schedule meetings and record minutes. '
          'Minutes are attached to each meeting for future reference.',
    ),
    _HelpTopic(
      icon: Icons.check_circle_outline,
      title: 'Taking attendance',
      body: 'Open Attendance to mark members present or absent for a meeting. '
          'Attendance history is saved per meeting.',
    ),
    _HelpTopic(
      icon: Icons.folder_outlined,
      title: 'Sharing documents',
      body: 'Upload files in the Documents screen so members can access '
          'important records from their accounts.',
    ),
    _HelpTopic(
      icon: Icons.picture_as_pdf_outlined,
      title: 'Generating reports',
      body: 'Use Reports to create contribution and financial summaries as '
          'PDFs that can be shared with leadership.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Help')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.support_agent,
                  size: 40,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'How can we help?',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Quick guides for the most common secretary tasks in AgePay.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._topics.map((topic) => _HelpCard(topic: topic)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.contact_support_outlined,
                color: theme.colorScheme.primary,
              ),
              title: const Text('Still need help?'),
              subtitle: const Text('Call your organization administrator.'),
              trailing: const Icon(Icons.call),
              onTap: () async {
                final uri = Uri(scheme: 'tel', path: _supportPhone);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not launch the dialer.'),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  final _HelpTopic topic;

  const _HelpCard({required this.topic});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
            child: Icon(topic.icon, color: theme.colorScheme.primary),
          ),
          title: Text(
            topic.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                topic.body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpTopic {
  final IconData icon;
  final String title;
  final String body;

  const _HelpTopic({
    required this.icon,
    required this.title,
    required this.body,
  });
}
