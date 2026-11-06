import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/core/theme/app_theme.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/meetings/controllers/meeting_provider.dart';
import 'package:cls/features/meetings/models/meeting_model.dart';
import 'package:cls/features/national/controllers/national_provider.dart';
import 'package:cls/features/notifications/controllers/notification_provider.dart';
import 'package:cls/features/notifications/models/notification_model.dart';
import 'package:cls/features/secretary/controllers/secretary_dashboard_provider.dart';
import 'package:cls/features/secretary/models/announcement_model.dart';
import '../widgets/meeting_rsvp_card.dart';
import '../widgets/meeting_excuses_section.dart';

class MeetingDetailScreen extends ConsumerStatefulWidget {
  final MeetingModel? meeting;
  final bool readOnly;

  const MeetingDetailScreen({super.key, this.meeting, this.readOnly = false});

  @override
  ConsumerState<MeetingDetailScreen> createState() =>
      _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends ConsumerState<MeetingDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _venueController = TextEditingController();
  final _minutesController = TextEditingController();
  final _picker = ImagePicker();

  DateTime? _selectedDate;
  File? _pickedFile;
  String? _pickedFileName;
  bool _removeFile = false;
  bool _isSaving = false;
  String? _error;
  String _targetAudience = 'all';

  bool get _isNew => widget.meeting == null;

  @override
  void initState() {
    super.initState();
    final meeting = widget.meeting;
    if (meeting != null) {
      _titleController.text = meeting.title;
      _venueController.text = meeting.venue;
      _minutesController.text = meeting.minutesText ?? '';
      _selectedDate = meeting.meetingDate;
      _targetAudience = meeting.targetAudience;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _venueController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2000),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate != null && mounted) {
      final initialTime = _selectedDate != null
          ? TimeOfDay.fromDateTime(_selectedDate!)
          : const TimeOfDay(hour: 10, minute: 0);
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: initialTime,
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      } else {
        setState(() => _selectedDate = pickedDate);
      }
    }
  }

  Future<void> _pickMinutesFile() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _pickedFile = File(picked.path);
        _pickedFileName = picked.name;
        _removeFile = false;
      });
    }
  }

  Future<void> _save({bool publishAndNotify = false}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      setState(() => _error = 'Please select the meeting date & time');
      return;
    }
    final user = ref.read(authProvider).valueOrNull;
    if (user == null) {
      setState(() => _error = 'Session expired. Please sign in again.');
      return;
    }

    final rawMinutes = _minutesController.text.trim();
    final hasMinutesContent = rawMinutes.isNotEmpty ||
        _pickedFile != null ||
        (widget.meeting?.minutesFileUrl != null && !_removeFile);

    if (publishAndNotify && !hasMinutesContent) {
      setState(() {
        _error = 'Please enter minutes or attach a file before publishing to members.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final controller = ref.read(meetingControllerProvider);
      final title = _titleController.text.trim();
      final venue = _venueController.text.trim();
      final minutesText = rawMinutes.isEmpty ? null : rawMinutes;

      String? minutesFileUrl = _removeFile
          ? null
          : widget.meeting?.minutesFileUrl;
      String? minutesFileName = _removeFile
          ? null
          : widget.meeting?.minutesFileName;

      final orgId = user.organizationId.isNotEmpty
          ? user.organizationId
          : user.uid;

      final activeScope = ref.read(activeExecutiveScopeProvider);
      final isNational = activeScope == ExecutiveScope.national &&
          (user.nationalRole != null || user.role == UserRole.superAdmin);
      final meetingScope =
          widget.meeting?.scope ?? (isNational ? 'national' : 'branch');
      final meetingBranchId =
          widget.meeting?.branchId ?? (isNational ? 'national' : user.branchId);

      if (_pickedFile != null && _pickedFileName != null) {
        final meetingId =
            widget.meeting?.id ??
            await controller.createMeeting(
              title: title,
              venue: venue,
              organizationId: orgId,
              meetingDate: _selectedDate!,
              createdBy: user.uid,
              targetAudience: _targetAudience,
              scope: meetingScope,
              branchId: meetingBranchId,
            );
        final result = await controller.uploadMinutesFile(
          meetingId,
          _pickedFile!,
          _pickedFileName!,
        );
        minutesFileUrl = result['url'];
        minutesFileName = result['name'];
      }

      final id =
          widget.meeting?.id ??
          await controller.createMeeting(
            title: title,
            venue: venue,
            organizationId: orgId,
            meetingDate: _selectedDate!,
            createdBy: user.uid,
            targetAudience: _targetAudience,
            scope: meetingScope,
            branchId: meetingBranchId,
          );

      final meeting = MeetingModel(
        id: id,
        organizationId: widget.meeting?.organizationId.isNotEmpty == true
            ? widget.meeting!.organizationId
            : orgId,
        title: title,
        venue: venue,
        meetingDate: _selectedDate!,
        minutesText: minutesText,
        minutesFileUrl: minutesFileUrl,
        minutesFileName: minutesFileName,
        createdAt: widget.meeting?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: widget.meeting?.createdBy ?? user.uid,
        targetAudience: _targetAudience,
        scope: meetingScope,
        branchId: meetingBranchId,
      );

      await controller.updateMeeting(meeting);

      // Automated broadcast for new meetings
      if (_isNew) {
        final formattedDateTime = DateFormat(
          'EEEE, MMM dd, yyyy \u2022 hh:mm a',
        ).format(_selectedDate!);

        final isExecutiveOnly = _targetAudience == 'executives';
        final announcementAudience = isExecutiveOnly
            ? (isNational ? 'nationalexecutives' : 'branchexecutives')
            : (isNational ? 'all' : 'branch');

        // 1. Post to Announcements
        final announcement = AnnouncementModel(
          id: '',
          organizationId: orgId,
          title: isExecutiveOnly
              ? '🏛️ Executive Meeting: $title'
              : '📅 Upcoming Meeting: $title',
          body: isExecutiveOnly
              ? 'An executive meeting session has been scheduled for all executive members.\n\n'
                  '📅 Date & Time: $formattedDateTime\n'
                  '📍 Venue: $venue\n\n'
                  'Please plan to attend and arrive promptly. Attendance is mandatory for all executive officers.'
              : 'A new meeting session has been scheduled for all members.\n\n'
                  '📅 Date & Time: $formattedDateTime\n'
                  '📍 Venue: $venue\n\n'
                  'Please plan to attend and arrive promptly. Attendance is mandatory.',
          category: AnnouncementCategory.meeting,
          isPinned: true,
          announcementDate: _selectedDate!,
          venue: venue,
          createdBy: user.uid,
          targetAudience: announcementAudience,
          targetBranchId: isNational ? null : user.branchId,
          targetBranchName: isNational ? null : user.branchName,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final announcementRepo = ref.read(announcementRepositoryProvider);
        await announcementRepo.createAnnouncement(announcement);
        ref.invalidate(announcementsStreamProvider(orgId));

        // 2. Add to in-app Notifications inbox and persist to repository
        final notification = NotificationModel(
          id: 'meet_${DateTime.now().millisecondsSinceEpoch}',
          organizationId: orgId,
          targetRole: isExecutiveOnly ? 'executives' : null,
          title: isExecutiveOnly
              ? 'Executive Meeting Scheduled: $title'
              : 'Meeting Scheduled: $title',
          body: '$formattedDateTime at $venue',
          type: 'meeting',
          payload: id,
          targetBranchId: isNational ? null : user.branchId,
          receivedAt: DateTime.now(),
        );

        try {
          final notificationRepo = ref.read(notificationRepositoryProvider);
          await notificationRepo.sendNotification(notification);
        } catch (_) {}

        final notificationNotifier = ref.read(
          notificationListProvider.notifier,
        );
        notificationNotifier.addNotification(notification);
      } else if (publishAndNotify) {
        final formattedDateTime = DateFormat(
          'EEEE, MMM dd, yyyy \u2022 hh:mm a',
        ).format(_selectedDate!);

        final isExecutiveOnly = _targetAudience == 'executives';
        final announcementAudience = isExecutiveOnly
            ? (isNational ? 'nationalexecutives' : 'branchexecutives')
            : (isNational ? 'all' : 'branch');

        // 1. Post to Announcements for Minutes Published
        final announcement = AnnouncementModel(
          id: '',
          organizationId: orgId,
          title: isExecutiveOnly
              ? '🏛️ Executive Minutes Published: $title'
              : '📝 Meeting Minutes Published: $title',
          body: isExecutiveOnly
              ? 'The official minutes and deliberations for the executive meeting held on $formattedDateTime have been recorded and published.\n\n'
                  '📍 Venue: ${venue.isNotEmpty ? venue : 'Executive Secretariat'}\n\n'
                  'Executive officers can now read the recorded proceedings, resolutions, and view attached files in the Meeting Minutes archive.'
              : 'The official minutes and proceedings for the meeting held on $formattedDateTime have been recorded and published by the Secretariat.\n\n'
                  '📍 Venue: ${venue.isNotEmpty ? venue : 'General Meeting'}\n\n'
                  'All members can now view the recorded minutes, attendance records, and download attached documents directly from the Meeting Minutes archive.',
          category: AnnouncementCategory.meeting,
          isPinned: true,
          announcementDate: DateTime.now(),
          venue: venue.isNotEmpty ? venue : null,
          createdBy: user.uid,
          targetAudience: announcementAudience,
          targetBranchId: isNational ? null : user.branchId,
          targetBranchName: isNational ? null : user.branchName,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final announcementRepo = ref.read(announcementRepositoryProvider);
        await announcementRepo.createAnnouncement(announcement);
        ref.invalidate(announcementsStreamProvider(orgId));

        // 2. Add to in-app Notifications inbox
        final notification = NotificationModel(
          id: 'min_${DateTime.now().millisecondsSinceEpoch}',
          organizationId: orgId,
          targetRole: isExecutiveOnly ? 'executives' : null,
          title: isExecutiveOnly
              ? 'Executive Minutes Published: $title'
              : 'Meeting Minutes Published: $title',
          body: 'Official minutes for "$title" held on $formattedDateTime are now available.',
          type: 'meeting',
          payload: id,
          targetBranchId: isNational ? null : user.branchId,
          receivedAt: DateTime.now(),
        );

        try {
          final notificationRepo = ref.read(notificationRepositoryProvider);
          await notificationRepo.sendNotification(notification);
        } catch (_) {}

        final notificationNotifier = ref.read(
          notificationListProvider.notifier,
        );
        notificationNotifier.addNotification(notification);
      }

      ref.invalidate(meetingsStreamProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isNew
                  ? 'Meeting scheduled and broadcast to members!'
                  : (publishAndNotify
                      ? 'Minutes published and broadcast to all members!'
                      : 'Meeting details updated successfully'),
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _openFile(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open file')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateTimeFormat = DateFormat('EEE, MMM dd, yyyy \u2022 hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.readOnly
              ? 'Meeting Details'
              : (_isNew ? 'New Meeting' : 'Meeting Minutes'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Form(
            key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.errorContainer),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              TextFormField(
                controller: _titleController,
                readOnly: widget.readOnly,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Meeting Title',
                  hintText: 'e.g. General Monthly Meeting',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Meeting title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _venueController,
                readOnly: widget.readOnly,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Meeting Venue / Location',
                  hintText: 'e.g. Civic Centre, Town Hall, or Virtual (Zoom)',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Meeting venue is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                readOnly: true,
                onTap: widget.readOnly ? null : _pickDateTime,
                decoration: InputDecoration(
                  labelText: 'Meeting Date & Time',
                  prefixIcon: const Icon(Icons.calendar_today),
                  suffixIcon: widget.readOnly
                      ? null
                      : const Icon(Icons.access_time),
                  border: const OutlineInputBorder(),
                  hintText: _selectedDate == null
                      ? 'Select date and time'
                      : dateTimeFormat.format(_selectedDate!),
                ),
              ),
              const SizedBox(height: 16),
              if (!widget.readOnly) ...[
                Text(
                  'Target Audience',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'all',
                        icon: Icon(Icons.groups_outlined),
                        label: Text('All Members'),
                      ),
                      ButtonSegment<String>(
                        value: 'executives',
                        icon: Icon(Icons.shield_outlined),
                        label: Text('Executives Only'),
                      ),
                    ],
                    selected: {_targetAudience},
                    onSelectionChanged: (newSelection) {
                      setState(() {
                        _targetAudience = newSelection.first;
                      });
                    },
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: _targetAudience == 'executives'
                          ? Colors.deepOrange.withValues(alpha: 0.15)
                          : theme.colorScheme.primaryContainer,
                      selectedForegroundColor: _targetAudience == 'executives'
                          ? Colors.deepOrange
                          : theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _targetAudience == 'executives'
                      ? 'Only executive members will see this meeting on their dashboard.'
                      : 'All registered members will see this meeting on their dashboard.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _targetAudience == 'executives'
                        ? Colors.deepOrange.withValues(alpha: 0.08)
                        : theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _targetAudience == 'executives'
                          ? Colors.deepOrange.withValues(alpha: 0.3)
                          : theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _targetAudience == 'executives'
                            ? Icons.shield_outlined
                            : Icons.groups_outlined,
                        size: 20,
                        color: _targetAudience == 'executives'
                            ? Colors.deepOrange
                            : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Target Audience: ',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _targetAudience == 'executives'
                            ? 'Executives Only'
                            : 'All Members',
                        style: TextStyle(
                          color: _targetAudience == 'executives'
                              ? Colors.deepOrange.shade800
                              : theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (!_isNew && widget.meeting != null) ...[
                const SizedBox(height: 20),
                MeetingRsvpCard(meetingId: widget.meeting!.id),
                const SizedBox(height: 20),
                MeetingExcusesSection(meetingId: widget.meeting!.id),
              ],
              const SizedBox(height: 24),
              if (widget.readOnly) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: (widget.meeting?.hasMinutes == true)
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (widget.meeting?.hasMinutes == true)
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.amber.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        (widget.meeting?.hasMinutes == true)
                            ? Icons.check_circle_outline
                            : Icons.pending_actions,
                        color: (widget.meeting?.hasMinutes == true)
                            ? Colors.green.shade700
                            : Colors.amber.shade800,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          (widget.meeting?.hasMinutes == true)
                              ? 'Official Meeting Minutes Documented & Verified'
                              : 'Meeting Minutes Pending Documentation by the Secretariat',
                          style: TextStyle(
                            color: (widget.meeting?.hasMinutes == true)
                                ? Colors.green.shade800
                                : Colors.amber.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'Meeting Minutes / Agenda',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('meeting_minutes_field'),
                controller: _minutesController,
                readOnly: widget.readOnly,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: widget.readOnly
                      ? 'No agenda or minutes recorded yet.'
                      : 'Type the agenda or minutes of the meeting here...',
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (!widget.readOnly) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickMinutesFile,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload Minutes (image/scan)'),
                ),
              ],
              const SizedBox(height: 8),
              _MinutesFilePreview(
                existingUrl: _removeFile
                    ? null
                    : widget.meeting?.minutesFileUrl,
                existingName: widget.meeting?.minutesFileName,
                pickedFile: _pickedFile,
                pickedFileName: _pickedFileName,
                onOpen: _openFile,
                readOnly: widget.readOnly,
                onRemove: () => setState(() {
                  _removeFile = true;
                  _pickedFile = null;
                  _pickedFileName = null;
                }),
                onUndoRemove: () => setState(() => _removeFile = false),
              ),
              if (!widget.readOnly) ...[
                const SizedBox(height: 20),
                if (_isNew)
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.brandGreen,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isSaving ? null : () => _save(),
                      icon: _isSaving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send),
                      label: Text(
                        _isSaving
                            ? 'Scheduling...'
                            : 'Schedule & Notify Members',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                else ...[
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.brandGreen,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isSaving ? null : () => _save(publishAndNotify: true),
                      icon: _isSaving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.campaign_outlined),
                      label: Text(
                        _isSaving ? 'Publishing...' : 'Publish Minutes & Notify Members',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 46,
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isSaving ? null : () => _save(publishAndNotify: false),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save Details (Without Notifying)'),
                    ),
                  ),
                ],
              ],
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
            ],
          ),
        ),
      ),
    ),
  );
  }
}

class _MinutesFilePreview extends StatelessWidget {
  final String? existingUrl;
  final String? existingName;
  final File? pickedFile;
  final String? pickedFileName;
  final void Function(String url) onOpen;
  final VoidCallback onRemove;
  final VoidCallback onUndoRemove;
  final bool readOnly;

  const _MinutesFilePreview({
    required this.existingUrl,
    required this.existingName,
    required this.pickedFile,
    required this.pickedFileName,
    required this.onOpen,
    required this.onRemove,
    required this.onUndoRemove,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (pickedFile != null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.image),
          title: Text(pickedFileName ?? 'Selected file'),
          subtitle: const Text('Ready to upload'),
          trailing: readOnly
              ? null
              : IconButton(icon: const Icon(Icons.close), onPressed: onRemove),
        ),
      );
    }

    if (existingUrl != null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.attach_file),
          title: Text(existingName ?? 'Uploaded minutes'),
          subtitle: const Text('Tap to open'),
          trailing: readOnly
              ? IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => onOpen(existingUrl!),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => onOpen(existingUrl!),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: onRemove,
                    ),
                  ],
                ),
          onTap: () => onOpen(existingUrl!),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        'No file uploaded yet.',
        style: TextStyle(
          fontSize: 13,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
