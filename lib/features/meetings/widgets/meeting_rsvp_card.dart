import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/controllers/auth_provider.dart';
import '../controllers/meeting_rsvp_provider.dart';
import '../models/meeting_rsvp_model.dart';

class MeetingRsvpCard extends ConsumerStatefulWidget {
  final String meetingId;

  const MeetingRsvpCard({super.key, required this.meetingId});

  @override
  ConsumerState<MeetingRsvpCard> createState() => _MeetingRsvpCardState();
}

class _MeetingRsvpCardState extends ConsumerState<MeetingRsvpCard> {
  MeetingRsvpStatus? _selectedStatus;
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  bool _isSubmitting = false;

  final List<String> _quickReasons = const [
    'Work Engagement',
    'Family Emergency',
    'Out of Town / Travel',
    'Health / Medical',
    'Official Assignment',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit(MeetingRsvpStatus status, String? reason) async {
    final user = ref.read(authProvider).valueOrNull;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to RSVP')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final controller = ref.read(meetingRsvpControllerProvider);
      final memberName = user.displayName.trim().isNotEmpty
          ? user.displayName
          : user.email.split('@').first;
      final orgId = user.organizationId.isNotEmpty
          ? user.organizationId
          : user.uid;

      await controller.submitRsvp(
        meetingId: widget.meetingId,
        memberId: user.uid,
        memberName: memberName,
        organizationId: orgId,
        status: status,
        reason: reason,
      );

      ref.invalidate(meetingRsvpsStreamProvider(widget.meetingId));

      if (mounted) {
        setState(() {
          _isEditing = false;
          _selectedStatus = null;
          _reasonController.clear();
        });

        final message = status == MeetingRsvpStatus.excused
            ? 'Absence excuse submitted successfully'
            : (status == MeetingRsvpStatus.late
                ? 'Response saved: Coming late'
                : 'Attendance confirmed: Coming');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: status == MeetingRsvpStatus.excused
                ? Colors.orange.shade800
                : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit RSVP: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();

    final existingRsvp = ref.watch(
      memberMeetingRsvpProvider((
        meetingId: widget.meetingId,
        memberId: user.uid,
      )),
    );

    // If member already has an RSVP and isn't editing, show their status card
    if (existingRsvp != null && !_isEditing) {
      return _buildExistingRsvpCard(context, theme, existingRsvp);
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.how_to_reg,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Will you attend this meeting?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_isEditing)
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        setState(() {
                          _isEditing = false;
                          _selectedStatus = null;
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Let the house and secretary know your attendance plan.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              // Option Selection Row
              Row(
                children: [
                  Expanded(
                    child: _buildChoiceChip(
                      label: 'Coming',
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                      isSelected: _selectedStatus == MeetingRsvpStatus.attending,
                      onTap: () {
                        setState(() => _selectedStatus = MeetingRsvpStatus.attending);
                        _submit(MeetingRsvpStatus.attending, null);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildChoiceChip(
                      label: 'Late',
                      icon: Icons.schedule,
                      color: Colors.amber.shade800,
                      isSelected: _selectedStatus == MeetingRsvpStatus.late,
                      onTap: () {
                        setState(() => _selectedStatus = MeetingRsvpStatus.late);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildChoiceChip(
                      label: 'Not Coming',
                      icon: Icons.cancel_outlined,
                      color: Colors.redAccent,
                      isSelected: _selectedStatus == MeetingRsvpStatus.excused,
                      onTap: () {
                        setState(() => _selectedStatus = MeetingRsvpStatus.excused);
                      },
                    ),
                  ),
                ],
              ),
              // Expanded Section for Late Note or Absence Excuse
              if (_selectedStatus == MeetingRsvpStatus.late) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Expected arrival or note (optional):',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Arriving 30 mins late due to traffic',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : () => _submit(
                              MeetingRsvpStatus.late,
                              _reasonController.text.trim(),
                            ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: const Text('Confirm Coming Late'),
                  ),
                ),
              ],
              if (_selectedStatus == MeetingRsvpStatus.excused) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'State reason for absence (required):',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'This official excuse will be noted by the secretary and published to the house.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _quickReasons.map((reason) {
                    return ActionChip(
                      label: Text(reason, style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        setState(() {
                          _reasonController.text = reason;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Describe your reason clearly...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 3) {
                      return 'Please state your reason for absence (min 3 characters)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            if (_formKey.currentState!.validate()) {
                              _submit(
                                MeetingRsvpStatus.excused,
                                _reasonController.text.trim(),
                              );
                            }
                          },
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.assignment_turned_in),
                    label: const Text('Submit Official Excuse'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExistingRsvpCard(
    BuildContext context,
    ThemeData theme,
    MeetingRsvpModel rsvp,
  ) {
    Color statusColor;
    IconData statusIcon;
    String statusTitle;

    switch (rsvp.status) {
      case MeetingRsvpStatus.attending:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusTitle = 'You are Attending (Coming)';
        break;
      case MeetingRsvpStatus.late:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        statusTitle = 'You are Coming Late';
        break;
      case MeetingRsvpStatus.excused:
        statusColor = Colors.redAccent;
        statusIcon = Icons.cancel;
        statusTitle = 'You Submitted an Excuse (Not Coming)';
        break;
    }

    final dateFormat = DateFormat('MMM d \u2022 h:mm a');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: statusColor.withValues(alpha: 0.05),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOUR MEETING RSVP',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        statusTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isEditing = true;
                      _selectedStatus = rsvp.status;
                      _reasonController.text = rsvp.reason;
                    });
                  },
                  child: const Text('Change'),
                ),
              ],
            ),
            if (rsvp.reason.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.format_quote, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        rsvp.reason,
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Recorded on ${dateFormat.format(rsvp.updatedAt)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.4),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : color,
              size: 22,
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : color,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
