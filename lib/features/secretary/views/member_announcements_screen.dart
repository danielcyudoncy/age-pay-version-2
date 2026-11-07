import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/national/controllers/national_provider.dart';
import 'package:cls/features/secretary/controllers/secretary_dashboard_provider.dart';
import 'package:cls/features/secretary/models/announcement_model.dart';
import '../widgets/announcement_detail_dialog.dart';

enum AnnouncementTierFilter { all, branch, national }

/// Screen members use to receive and read announcements created by the
/// secretary or vice secretary. Announcements are scoped by the organization
/// the member belongs to, resolved via [organizationIdProvider] so that
/// members whose profile predates the organizationId field still receive
/// announcements created by the secretary.
class MemberAnnouncementsScreen extends ConsumerStatefulWidget {
  const MemberAnnouncementsScreen({super.key});

  @override
  ConsumerState<MemberAnnouncementsScreen> createState() =>
      _MemberAnnouncementsScreenState();
}

class _MemberAnnouncementsScreenState
    extends ConsumerState<MemberAnnouncementsScreen> {
  AnnouncementTierFilter? _filter;

  bool _isNational(AnnouncementModel a) {
    final aud = a.targetAudience.trim().toLowerCase();
    return aud == 'national' ||
        aud == 'nationalexecutives' ||
        aud == 'national_executives' ||
        a.targetBranchId == 'national' ||
        (a.targetBranchName?.trim().toLowerCase() == 'national assembly') ||
        (a.targetBranchName?.trim().toLowerCase() == 'national');
  }

  @override
  Widget build(BuildContext context) {
    final orgIdAsync = ref.watch(organizationIdProvider);
    final activeScope = ref.watch(activeExecutiveScopeProvider);
    final dateFormat = DateFormat('MMM dd, yyyy');

    _filter ??= (activeScope == ExecutiveScope.national
        ? AnnouncementTierFilter.national
        : AnnouncementTierFilter.branch);

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
        final user = ref.watch(authProvider).valueOrNull;

        return Scaffold(
          appBar: AppBar(title: const Text('Announcements')),
          body: announcementsAsync.when(
            data: (announcements) {
              final visible =
                  announcements.where((a) => a.isVisibleTo(user)).toList();

              final branchItems =
                  visible.where((a) => !_isNational(a)).toList();
              final nationalItems =
                  visible.where((a) => _isNational(a)).toList();

              List<AnnouncementModel> filtered;
              switch (_filter) {
                case AnnouncementTierFilter.branch:
                  filtered = branchItems;
                  break;
                case AnnouncementTierFilter.national:
                  filtered = nationalItems;
                  break;
                case AnnouncementTierFilter.all:
                default:
                  filtered = visible;
                  break;
              }

              final pinned = filtered.where((a) => a.isPinned).toList();
              final others = filtered.where((a) => !a.isPinned).toList();

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: SegmentedButton<AnnouncementTierFilter>(
                      style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      segments: [
                        ButtonSegment(
                          value: AnnouncementTierFilter.all,
                          label: Text('All (${visible.length})'),
                        ),
                        ButtonSegment(
                          value: AnnouncementTierFilter.branch,
                          icon: const Icon(Icons.location_on_outlined, size: 14),
                          label: Text('Branch (${branchItems.length})'),
                        ),
                        ButtonSegment(
                          value: AnnouncementTierFilter.national,
                          icon: const Icon(Icons.stars_rounded, size: 14),
                          label: Text('National (${nationalItems.length})'),
                        ),
                      ],
                      selected: {_filter ?? AnnouncementTierFilter.all},
                      onSelectionChanged: (set) {
                        setState(() => _filter = set.first);
                      },
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.campaign_outlined,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _filter == AnnouncementTierFilter.national
                                      ? 'No national communiqués yet'
                                      : _filter == AnnouncementTierFilter.branch
                                          ? 'No branch announcements yet'
                                          : 'No announcements yet',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () async => ref.invalidate(
                              announcementsStreamProvider(orgId),
                            ),
                            child: ListView(
                              padding: EdgeInsets.fromLTRB(
                                16,
                                8,
                                16,
                                MediaQuery.paddingOf(context).bottom + 24,
                              ),
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
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
                          ),
                  ),
                ],
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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showAnnouncementDetailDialog(context, announcement),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                  child: Icon(Icons.campaign, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              announcement.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          if (announcement.isPinned) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.push_pin, size: 16, color: Colors.red),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.event_outlined, size: 13, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              announcement.formattedTime != null
                                  ? '${dateFormat.format(date)} \u2022 ${announcement.formattedTime}'
                                  : dateFormat.format(date),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (announcement.effectiveVenue != null &&
                          announcement.effectiveVenue!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 13, color: Colors.redAccent),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                announcement.effectiveVenue!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (announcement.body.isNotEmpty) ...[
              const SizedBox(height: 10),
              if (announcement.category == AnnouncementCategory.meeting) ...[
                Row(
                  children: [
                    Icon(Icons.format_list_bulleted, size: 13, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Meeting Agenda & Proceedings:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              Text(announcement.body, style: const TextStyle(fontSize: 14)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
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
                    if (announcement.audienceLabel != 'Everyone')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        constraints: const BoxConstraints(maxWidth: 200),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.group_outlined, size: 12, color: theme.colorScheme.secondary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                announcement.audienceLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.secondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                Text(
                  dateFormat.format(date),
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
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
