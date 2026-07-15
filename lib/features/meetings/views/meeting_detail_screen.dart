import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/meetings/controllers/meeting_provider.dart';
import 'package:cls/features/meetings/models/meeting_model.dart';

class MeetingDetailScreen extends ConsumerStatefulWidget {
  final MeetingModel? meeting;

  const MeetingDetailScreen({super.key, this.meeting});

  @override
  ConsumerState<MeetingDetailScreen> createState() =>
      _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends ConsumerState<MeetingDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
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
      _minutesController.text = meeting.minutesText ?? '';
      _selectedDate = meeting.meetingDate;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
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
      setState(() => _error = 'Please select the meeting date');
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
      final minutesText =
          _minutesController.text.trim().isEmpty
              ? null
              : _minutesController.text.trim();

      String? minutesFileUrl = _removeFile ? null : widget.meeting?.minutesFileUrl;
      String? minutesFileName =
          _removeFile ? null : widget.meeting?.minutesFileName;

      if (_pickedFile != null && _pickedFileName != null) {
        final meetingId =
            widget.meeting?.id ??
            await controller.createMeeting(
              title: title,
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
            meetingDate: _selectedDate!,
            createdBy: user.uid,
          );

      final meeting = MeetingModel(
        id: id,
        title: title,
        meetingDate: _selectedDate!,
        minutesText: minutesText,
        minutesFileUrl: minutesFileUrl,
        minutesFileName: minutesFileName,
        createdAt: widget.meeting?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: widget.meeting?.createdBy ?? user.uid,
      );

      await controller.updateMeeting(meeting);

      if (mounted) {
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
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New Meeting' : 'Meeting Minutes'),
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
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Meeting Title',
                  prefixIcon: Icon(Icons.title),
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
                readOnly: true,
                onTap: _pickDate,
                decoration: InputDecoration(
                  labelText: 'Meeting Date',
                  prefixIcon: const Icon(Icons.calendar_today),
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                  hintText:
                      _selectedDate == null
                          ? 'Select date'
                          : dateFormat.format(_selectedDate!),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Minutes',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _minutesController,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Type the minutes of the meeting here...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickMinutesFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload Minutes (image)'),
              ),
              const SizedBox(height: 12),
              _MinutesFilePreview(
                existingUrl:
                    _removeFile ? null : widget.meeting?.minutesFileUrl,
                existingName: widget.meeting?.minutesFileName,
                pickedFile: _pickedFile,
                pickedFileName: _pickedFileName,
                onOpen: _openFile,
                onRemove: () => setState(() {
                  _removeFile = true;
                  _pickedFile = null;
                  _pickedFileName = null;
                }),
                onUndoRemove: () => setState(() => _removeFile = false),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child:
                      _isSaving
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : Text(
                            _isNew ? 'Save Meeting' : 'Save Minutes',
                            style: const TextStyle(fontSize: 16),
                          ),
                ),
              ),
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

  const _MinutesFilePreview({
    required this.existingUrl,
    required this.existingName,
    required this.pickedFile,
    required this.pickedFileName,
    required this.onOpen,
    required this.onRemove,
    required this.onUndoRemove,
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
          trailing: IconButton(
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
          trailing: Row(
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
        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
