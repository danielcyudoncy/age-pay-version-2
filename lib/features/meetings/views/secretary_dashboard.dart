// features/meetings/views/secretary_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/dashboard/views/member_dashboard.dart';
import 'package:cls/features/meetings/controllers/meeting_provider.dart';
import 'package:cls/features/meetings/models/meeting_model.dart';
import 'package:cls/features/meetings/views/meeting_detail_screen.dart';

class SecretaryDashboard extends ConsumerWidget {
  const SecretaryDashboard({super.key});

  bool _canEditMinutes(UserRole role) =>
      role == UserRole.secretary || role == UserRole.viceSecretary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final currentUser = authState.valueOrNull;
    final canEdit = currentUser != null && _canEditMinutes(currentUser.role);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Secretary Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'My Personal Dues',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MemberDashboard()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      floatingActionButton:
          canEdit
              ? FloatingActionButton.extended(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MeetingDetailScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('New Meeting'),
              )
              : null,
      body: authState.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Please sign in'));
          }
          return _MeetingsView(canEdit: canEdit);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('Error: $error', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(authProvider.notifier).refreshUser(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeetingsView extends ConsumerWidget {
  final bool canEdit;

  const _MeetingsView({required this.canEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetingsAsync = ref.watch(meetingsStreamProvider);
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return meetingsAsync.when(
      data: (meetings) {
        final recorded = meetings.where((m) => m.hasMinutes).length;

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(meetingsStreamProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Welcome, ${ref.read(authProvider).valueOrNull?.displayName ?? 'Secretary'}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        DateFormat('MMM yyyy').format(DateTime.now()),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _StatCard(
                      label: 'Total Meetings',
                      value: meetings.length.toString(),
                      icon: Icons.groups,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      label: 'Minutes Recorded',
                      value: recorded.toString(),
                      icon: Icons.description,
                      color: Colors.green,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Meetings & Minutes',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!canEdit)
                    Text(
                      'View only',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (meetings.isEmpty)
                Card(
                  color: Colors.grey.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        Icon(
                          Icons.event_note_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No meetings recorded yet',
                          style: TextStyle(fontSize: 16),
                        ),
                        if (canEdit)
                          const SizedBox(height: 8),
                        if (canEdit)
                          const Text(
                            'Tap "New Meeting" to add one and record minutes.',
                            style: TextStyle(fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                )
              else
                ...meetings.map((meeting) {
                  return _MeetingCard(
                    meeting: meeting,
                    dateFormat: dateFormat,
                    canEdit: canEdit,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MeetingDetailScreen(meeting: meeting),
                        ),
                      );
                    },
                  );
                }),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('Error: $error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(meetingsStreamProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        color: color.withValues(alpha: 0.06),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(10),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 14),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final MeetingModel meeting;
  final DateFormat dateFormat;
  final bool canEdit;
  final VoidCallback onTap;

  const _MeetingCard({
    required this.meeting,
    required this.dateFormat,
    required this.canEdit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasText = meeting.minutesText?.trim().isNotEmpty ?? false;
    final hasFile = meeting.minutesFileUrl?.isNotEmpty ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          child: Icon(Icons.event, color: theme.colorScheme.primary),
        ),
        title: Text(
          meeting.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(dateFormat.format(meeting.meetingDate)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                if (hasText)
                  _StatusChip(
                    label: 'Typed',
                    icon: Icons.edit_note,
                    color: Colors.green,
                  ),
                if (hasFile)
                  _StatusChip(
                    label: 'File',
                    icon: Icons.attach_file,
                    color: Colors.blue,
                  ),
                if (!hasText && !hasFile)
                  _StatusChip(
                    label: 'No minutes',
                    icon: Icons.pending,
                    color: Colors.orange,
                  ),
              ],
            ),
          ],
        ),
        trailing:
            canEdit
                ? const Icon(Icons.arrow_forward_ios, size: 16)
                : null,
        onTap: canEdit ? onTap : null,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _StatusChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
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
