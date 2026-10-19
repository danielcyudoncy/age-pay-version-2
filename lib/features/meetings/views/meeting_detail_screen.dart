import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/meetings/controllers/meeting_provider.dart';
import 'package:cls/features/meetings/models/meeting_model.dart';
import 'package:cls/features/notifications/controllers/notification_provider.dart';
import 'package:cls/features/notifications/models/notification_model.dart';
import 'package:cls/features/secretary/controllers/secretary_dashboard_provider.dart';
import 'package:cls/features/secretary/models/announcement_model.dart';
import '../widgets/meeting_rsvp_card.dart';
import '../widgets/meeting_excuses_section.dart';

class MeetingDetailScreen extends ConsumerStatefulWidget {
  final MeetingModel? meeting;
  final bool readOnly;

  const MeetingDetailScreen({
    super.key,
    this.meeting,
    this.readOnly = false,
  });

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

  Future<void> _save() async {
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

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final controller = ref.read(meetingControllerProvider);
      final title = _titleController.text.trim();
      final venue = _venueController.text.trim();
      final minutesText =
          _minutesController.text.trim().isEmpty
              ? null
              : _minutesController.text.trim();

      String? minutesFileUrl =
          _removeFile ? null : widget.meeting?.minutesFileUrl;
      String? minutesFileName =
          _removeFile ? null : widget.meeting?.minutesFileName;

      final orgId =
          user.organizationId.isNotEmpty ? user.organizationId : user.uid;

      if (_pickedFile != null && _pickedFileName != null) {
        final meetingId =
            widget.meeting?.id ??
            await controller.createMeeting(
              title: title,
              venue: venue,
              organizationId: orgId,
              meetingDate: _selectedDate!,
              createdBy: user.uid,
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
      );

      await controller.updateMeeting(meeting);

      // Automated broadcast for new meetings
      if (_isNew) {
        final formattedDateTime = DateFormat(
          'EEEE, MMM dd, yyyy \u2022 hh:mm a',
        ).format(_selectedDate!);

        // 1. Post to Announcements for all members to see
        final announcement = AnnouncementModel(
          id: '',
          organizationId: orgId,
          title: '📅 Upcoming Meeting: $title',
          body:
              'A new meeting session has been scheduled for all members.\n\n'
              '📅 Date & Time: $formattedDateTime\n'
              '📍 Venue: $venue\n\n'
              'Please plan to attend and arrive promptly. Attendance is mandatory.',
          category: AnnouncementCategory.meeting,
          isPinned: true,
          announcementDate: _selectedDate!,
          createdBy: user.uid,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final announcementRepo = ref.read(announcementRepositoryProvider);
        await announcementRepo.createAnnouncement(announcement);
        ref.invalidate(announcementsStreamProvider(orgId));

        // 2. Add to in-app Notifications inbox
        final notificationNotifier =
            ref.read(notificationListProvider.notifier);
        notificationNotifier.addNotification(
          NotificationModel(
            id: 'meet_${DateTime.now().millisecondsSinceEpoch}',
            title: 'Meeting Scheduled: $title',
            body: '$formattedDateTime at $venue',
            type: 'meeting',
            receivedAt: DateTime.now(),
          ),
        );
      }

      ref.invalidate(meetingsStreamProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isNew
                  ? 'Meeting scheduled and broadcast to members!'
                  : 'Meeting updated successfully',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
                  suffixIcon: widget.readOnly ? null : const Icon(Icons.access_time),
                  border: const OutlineInputBorder(),
                  hintText:
                      _selectedDate == null
                          ? 'Select date and time'
                          : dateTimeFormat.format(_selectedDate!),
                ),
              ),
              if (!_isNew && widget.meeting != null) ...[
                const SizedBox(height: 20),
                MeetingRsvpCard(meetingId: widget.meeting!.id),
                const SizedBox(height: 20),
                MeetingExcusesSection(meetingId: widget.meeting!.id),
              ],
              const SizedBox(height: 24),
              Text(
                'Meeting Minutes / Agenda',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
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
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pickMinutesFile,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload Minutes (image/scan)'),
                ),
              ],
              const SizedBox(height: 12),
              _MinutesFilePreview(
                existingUrl:
                    _removeFile ? null : widget.meeting?.minutesFileUrl,
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
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox.shrink()
                        : Icon(_isNew ? Icons.send : Icons.save),
                    label: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isNew ? 'Schedule & Notify Members' : 'Save Minutes',
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ],
            ],
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
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onRemove,
                ),
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
                    IconButton(icon: const Icon(Icons.delete), onPressed: onRemove),
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
