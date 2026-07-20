import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/secretary/controllers/secretary_dashboard_provider.dart';
import 'package:cls/features/secretary/models/announcement_model.dart';

/// Screen members use to receive and read announcements created by the
/// secretary or vice secretary. Announcements are scoped by the organization
/// the member belongs to, resolved via [organizationIdProvider] so that
/// members whose profile predates the organizationId field still receive
/// announcements created by the secretary.
class MemberAnnouncementsScreen extends ConsumerWidget {
  const MemberAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgIdAsync = ref.watch(organizationIdProvider);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return orgIdAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Announcements')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Announcements')),
        body: Center(
          child: Text('Error: $error', style: const TextStyle(color: Colors.red)),
        ),
      ),
      data: (orgId) {
        final announcementsAsync = ref.watch(announcementsStreamProvider(orgId));

        return Scaffold(
          appBar: AppBar(title: const Text('Announcements')),
          body: announcementsAsync.when(
            data: (announcements) {
              if (announcements.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.campaign_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text('No announcements yet', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                );
              }

              final pinned = announcements.where((a) => a.isPinned).toList();
              final others = announcements.where((a) => !a.isPinned).toList();

              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(announcementsStreamProvider(orgId)),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ...pinned.map(
                      (a) => _MemberAnnouncementCard(
                        announcement: a,
                        dateFormat: dateFormat,
                      ),
                    ),
                    if (pinned.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Recent',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    ...others.map(
                      (a) => _MemberAnnouncementCard(
                        announcement: a,
                        dateFormat: dateFormat,
                      ),
                    ),
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
                    onPressed: () =>
                        ref.invalidate(announcementsStreamProvider(orgId)),
                    child: const Text('Retry'),
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

class _MemberAnnouncementCard extends StatelessWidget {
  final AnnouncementModel announcement;
  final DateFormat dateFormat;

  const _MemberAnnouncementCard({required this.announcement, required this.dateFormat});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = announcement.announcementDate ?? announcement.createdAt;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                  child: Icon(Icons.campaign, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    announcement.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                if (announcement.isPinned) const Icon(Icons.push_pin, size: 16, color: Colors.red),
              ],
            ),
            const SizedBox(height: 10),
            Text(announcement.body, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    announcement.category.name.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  dateFormat.format(date),
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
