// features/secretary/views/attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/meetings/controllers/meeting_provider.dart';
import 'package:cls/features/secretary/controllers/secretary_dashboard_provider.dart';
import 'package:cls/features/secretary/models/attendance_model.dart';
import 'package:cls/features/secretary/controllers/attendance_provider.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetingsAsync = ref.watch(meetingsStreamProvider);
    final membersAsync = ref.watch(membersStreamProvider);
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(membersStreamProvider);
          ref.invalidate(meetingsStreamProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: Colors.green.withValues(alpha: 0.06),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Present',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    color: Colors.red.withValues(alpha: 0.06),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(Icons.cancel, color: Colors.red, size: 28),
                          const SizedBox(height: 8),
                          Text(
                            'Absent',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    color: Colors.orange.withValues(alpha: 0.06),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Colors.orange,
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Late',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
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
                      child: Text('No meetings available'),
                    ),
                  );
                }
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Meeting'),
                  items: meetings
                      .map(
                        (m) => DropdownMenuItem(
                          value: m.id,
                          child: Text(
                            '${m.title} - ${dateFormat.format(m.meetingDate)}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MeetingAttendanceScreen(meetingId: value),
                        ),
                      );
                    }
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => const Text('Failed to load meetings'),
            ),
            const SizedBox(height: 20),
            Text(
              'Attendance History',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            membersAsync.when(
              data: (members) {
                final present = members.where((m) => m.isActive).length;
                final total = members.length;
                final percentage = total > 0
                    ? ((present / total) * 100).toStringAsFixed(1)
                    : '0.0';
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Overall Attendance',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$percentage%',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Members',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$total',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => const Text('Failed to load members'),
            ),
          ],
        ),
      ),
    );
  }
}

class MeetingAttendanceScreen extends ConsumerWidget {
  final String meetingId;
  const MeetingAttendanceScreen({super.key, required this.meetingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mark Attendance')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(membersStreamProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            membersAsync.when(
              data: (members) {
                return Column(
                  children: members.map((member) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(
                          member.fullName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),

                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StatusButton(
                              label: 'P',
                              color: Colors.green,
                              onTap: () => _recordAttendance(
                                ref,
                                member.id,
                                member.fullName,
                                AttendanceStatus.present,
                              ),
                            ),
                            const SizedBox(width: 6),
                            StatusButton(
                              label: 'L',
                              color: Colors.orange,
                              onTap: () => _recordAttendance(
                                ref,
                                member.id,
                                member.fullName,
                                AttendanceStatus.late,
                              ),
                            ),
                            const SizedBox(width: 6),
                            StatusButton(
                              label: 'A',
                              color: Colors.red,
                              onTap: () => _recordAttendance(
                                ref,
                                member.id,
                                member.fullName,
                                AttendanceStatus.absent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => const Text('Failed to load members'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _recordAttendance(
    WidgetRef ref,
    String memberId,
    String memberName,
    AttendanceStatus status,
  ) async {
    final controller = ref.read(attendanceControllerProvider);
    final user = ref.read(authProvider).valueOrNull;
    if (user == null) return;
    final attendance = AttendanceModel(
      id: '',
      organizationId: user.uid,
      meetingId: meetingId,
      memberId: memberId,
      memberName: memberName,
      status: status,
      recordedAt: DateTime.now(),
      recordedBy: user.uid,
    );
    await controller.recordAttendance(attendance);
    ref.invalidate(attendanceStreamProvider(meetingId));
  }
}

class StatusButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const StatusButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
      ),
      child: Text(label, style: TextStyle(fontSize: 12)),
    );
  }
}
