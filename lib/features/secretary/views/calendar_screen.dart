// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/secretary/controllers/calendar_event_provider.dart';
import 'package:cls/features/secretary/controllers/secretary_dashboard_provider.dart';
import 'package:cls/features/secretary/models/calendar_event_model.dart';
import 'package:cls/features/secretary/controllers/announcement_provider.dart';
import 'package:cls/features/meetings/controllers/meeting_provider.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();

  bool _canManageEvents(UserModel? user) {
    if (user == null) return false;
    return user.role == UserRole.superAdmin ||
        user.role == UserRole.president ||
        user.role == UserRole.vicePresident ||
        user.role == UserRole.secretary ||
        user.role == UserRole.viceSecretary ||
        user.role == UserRole.publicRelationsOfficer;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull;
    final orgId = user?.organizationId.isNotEmpty == true ? user!.organizationId : (user?.uid ?? '');
    final eventsAsync = ref.watch(allCalendarEventsProvider(orgId));
    final dateFormat = DateFormat('MMM dd, yyyy \u2022 HH:mm');
    final canManage = _canManageEvents(user);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateDialog(context, user),
          ),
        ],
      ),
      body: eventsAsync.when(
        data: (events) {
          final now = DateTime.now();
          final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
          final selectedDayEvents = events.where((e) {
            return DateFormat('yyyy-MM-dd').format(e.startDate) == selectedDateStr;
          }).toList()..sort((a, b) => a.startDate.compareTo(b.startDate));

          bool isPast(CalendarEventModel e) {
            if (e.allDay) {
              final endOfDay = DateTime(e.endDate.year, e.endDate.month, e.endDate.day, 23, 59, 59);
              return endOfDay.isBefore(now);
            }
            return e.endDate.isBefore(now);
          }

          final upcoming = events.where((e) => !isPast(e)).toList()
            ..sort((a, b) => a.startDate.compareTo(b.startDate));
          final past = events.where((e) => isPast(e)).toList()
            ..sort((a, b) => b.startDate.compareTo(a.startDate));

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(calendarEventsStreamProvider(orgId));
              ref.invalidate(announcementsStreamProvider(orgId));
              ref.invalidate(meetingsStreamProvider);
            },
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.paddingOf(context).bottom + 24,
              ),
              children: [
                _MonthCalendar(
                  selectedDate: _selectedDate,
                  events: events,
                  onDaySelected: (date) {
                    setState(() => _selectedDate = date);
                  },
                  onDayLongPressed: (date) {
                    setState(() => _selectedDate = date);
                    _showCreateDialog(context, user, initialDate: date);
                  },
                ),
                const SizedBox(height: 20),
                Text('Selected Day', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (selectedDayEvents.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(child: Text('No events on ${DateFormat('MMM dd, yyyy').format(_selectedDate)}', style: TextStyle(color: Colors.grey.shade600))),
                    ),
                  )
                else
                  ...selectedDayEvents.map((e) => _EventCard(
                    event: e,
                    dateFormat: dateFormat,
                    onTap: () => _showEventDetails(context, e, user, canManage),
                    onEdit: canManage ? () => _showEditDialog(context, user, e) : null,
                    onDelete: canManage ? () => _confirmDelete(context, e) : null,
                  )),
                const SizedBox(height: 20),
                Text('Upcoming', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (upcoming.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(child: Text('No upcoming events', style: TextStyle(color: Colors.grey.shade600))),
                    ),
                  )
                else
                  ...upcoming.map((e) => _EventCard(
                    event: e,
                    dateFormat: dateFormat,
                    onTap: () => _showEventDetails(context, e, user, canManage),
                    onEdit: canManage ? () => _showEditDialog(context, user, e) : null,
                    onDelete: canManage ? () => _confirmDelete(context, e) : null,
                  )),
                const SizedBox(height: 20),
                Text('Past', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (past.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(child: Text('No past events', style: TextStyle(color: Colors.grey.shade600))),
                    ),
                  )
                else
                  ...past.map((e) => _EventCard(
                    event: e,
                    dateFormat: dateFormat,
                    onTap: () => _showEventDetails(context, e, user, canManage),
                    onEdit: canManage ? () => _showEditDialog(context, user, e) : null,
                    onDelete: canManage ? () => _confirmDelete(context, e) : null,
                  )),
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
                onPressed: () {
                  ref.invalidate(calendarEventsStreamProvider(orgId));
                  ref.invalidate(announcementsStreamProvider(orgId));
                  ref.invalidate(meetingsStreamProvider);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, UserModel? user, {DateTime? initialDate}) {
    if (user == null) return;
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();
    CalendarEventType selectedType = CalendarEventType.communityEvent;
    DateTime startDate = initialDate != null
        ? DateTime(initialDate.year, initialDate.month, initialDate.day, 9, 0)
        : DateTime.now();
    DateTime endDate = startDate.add(const Duration(hours: 2));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 12),
                TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
                const SizedBox(height: 12),
                TextField(controller: locationController, decoration: const InputDecoration(labelText: 'Location')),
                const SizedBox(height: 12),
                DropdownButtonFormField<CalendarEventType>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: CalendarEventType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name.replaceAll('_', ' ').toUpperCase()))).toList(),
                  onChanged: (v) { if (v != null) setDialogState(() => selectedType = v); },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date == null || !mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(startDate),
                    );
                    if (time == null || !mounted) return;
                    setDialogState(() => startDate = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Start', border: OutlineInputBorder()),
                    child: Text(DateFormat('MMM dd, yyyy HH:mm').format(startDate)),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: endDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date == null || !mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(endDate),
                    );
                    if (time == null || !mounted) return;
                    setDialogState(() => endDate = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'End', border: OutlineInputBorder()),
                    child: Text(DateFormat('MMM dd, yyyy HH:mm').format(endDate)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                if (endDate.isBefore(startDate)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End date must be after start date')));
                  return;
                }
                final targetOrgId = user.organizationId.isNotEmpty ? user.organizationId : user.uid;
                final controller = ref.read(calendarEventControllerProvider);
                final event = CalendarEventModel(
                  id: '',
                  organizationId: targetOrgId,
                  title: titleController.text.trim(),
                  description: descriptionController.text.trim(),
                  type: selectedType,
                  startDate: startDate,
                  endDate: endDate,
                  location: locationController.text.trim().isEmpty ? null : locationController.text.trim(),
                  createdBy: user.uid,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                try {
                  await controller.createEvent(event);
                  if (ctx.mounted) Navigator.pop(ctx);
                  ref.invalidate(calendarEventsStreamProvider(targetOrgId));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Event scheduled successfully')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to schedule event: $e')),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, UserModel? user, CalendarEventModel event) {
    if (user == null) return;
    final titleController = TextEditingController(text: event.title);
    final descriptionController = TextEditingController(text: event.description);
    final locationController = TextEditingController(text: event.location ?? '');
    CalendarEventType selectedType = event.type;
    DateTime startDate = event.startDate;
    DateTime endDate = event.endDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 12),
                TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
                const SizedBox(height: 12),
                TextField(controller: locationController, decoration: const InputDecoration(labelText: 'Location')),
                const SizedBox(height: 12),
                DropdownButtonFormField<CalendarEventType>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: CalendarEventType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name.replaceAll('_', ' ').toUpperCase()))).toList(),
                  onChanged: (v) { if (v != null) setDialogState(() => selectedType = v); },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date == null || !mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(startDate),
                    );
                    if (time == null || !mounted) return;
                    setDialogState(() => startDate = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Start', border: OutlineInputBorder()),
                    child: Text(DateFormat('MMM dd, yyyy HH:mm').format(startDate)),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: endDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date == null || !mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(endDate),
                    );
                    if (time == null || !mounted) return;
                    setDialogState(() => endDate = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'End', border: OutlineInputBorder()),
                    child: Text(DateFormat('MMM dd, yyyy HH:mm').format(endDate)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                if (endDate.isBefore(startDate)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End date must be after start date')));
                  return;
                }
                final targetOrgId = user.organizationId.isNotEmpty ? user.organizationId : user.uid;
                try {
                  if (event.id.startsWith('announcement_')) {
                    final announcementId = event.id.replaceFirst('announcement_', '');
                    final controller = ref.read(announcementControllerProvider);
                    final announcements = ref.read(announcementsStreamProvider(targetOrgId)).valueOrNull ?? [];
                    final existing = announcements.where((a) => a.id == announcementId).firstOrNull;
                    if (existing != null) {
                      await controller.updateAnnouncement(
                        existing.copyWith(
                          title: titleController.text.trim(),
                          body: descriptionController.text.trim(),
                          announcementDate: startDate,
                          updatedAt: DateTime.now(),
                        ),
                      );
                      ref.invalidate(announcementsStreamProvider(targetOrgId));
                    }
                  } else if (event.id.startsWith('meeting_')) {
                    final meetingId = event.id.replaceFirst('meeting_', '');
                    final controller = ref.read(meetingControllerProvider);
                    final meetings = ref.read(meetingsStreamProvider).valueOrNull ?? [];
                    final existing = meetings.where((m) => m.id == meetingId).firstOrNull;
                    if (existing != null) {
                      await controller.updateMeeting(
                        existing.copyWith(
                          title: titleController.text.trim(),
                          venue: locationController.text.trim(),
                          meetingDate: startDate,
                          updatedAt: DateTime.now(),
                        ),
                      );
                      ref.invalidate(meetingsStreamProvider);
                    }
                  } else {
                    final controller = ref.read(calendarEventControllerProvider);
                    final updatedEvent = event.copyWith(
                      title: titleController.text.trim(),
                      description: descriptionController.text.trim(),
                      type: selectedType,
                      startDate: startDate,
                      endDate: endDate,
                      location: locationController.text.trim().isEmpty ? null : locationController.text.trim(),
                      updatedAt: DateTime.now(),
                    );
                    await controller.updateEvent(updatedEvent);
                    ref.invalidate(calendarEventsStreamProvider(event.organizationId.isNotEmpty ? event.organizationId : targetOrgId));
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Event updated successfully')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update event: $e')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, CalendarEventModel event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "${event.title}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (event.id.startsWith('announcement_')) {
        final announcementId = event.id.replaceFirst('announcement_', '');
        await ref.read(announcementControllerProvider).deleteAnnouncement(announcementId);
        ref.invalidate(announcementsStreamProvider(event.organizationId));
      } else if (event.id.startsWith('meeting_')) {
        final meetingId = event.id.replaceFirst('meeting_', '');
        await ref.read(meetingControllerProvider).deleteMeeting(meetingId);
        ref.invalidate(meetingsStreamProvider);
      } else {
        final controller = ref.read(calendarEventControllerProvider);
        await controller.deleteEvent(event.id);
        ref.invalidate(calendarEventsStreamProvider(event.organizationId));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${event.title}" deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete event: $e')));
      }
    }
  }

  void _showEventDetails(BuildContext context, CalendarEventModel event, UserModel? user, bool canManage) {
    final dateFormat = DateFormat('EEEE, MMM dd, yyyy \u2022 HH:mm');
    String source = 'Calendar Event';
    Color sourceColor = Theme.of(context).colorScheme.primary;
    IconData sourceIcon = Icons.calendar_today;

    if (event.id.startsWith('announcement_')) {
      source = 'Broadcast Announcement';
      sourceColor = Colors.orange.shade800;
      sourceIcon = Icons.campaign;
    } else if (event.id.startsWith('meeting_')) {
      source = 'General Meeting';
      sourceColor = Colors.purple;
      sourceIcon = Icons.groups;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: sourceColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(sourceIcon, size: 14, color: sourceColor),
                  const SizedBox(width: 6),
                  Text(
                    source,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: sourceColor,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.access_time, size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      dateFormat.format(event.startDate),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                ],
              ),
              if (event.location != null && event.location!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, size: 18, color: Colors.redAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        event.location!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ],
              if (event.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Description / Agenda',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    event.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (canManage) ...[
            TextButton.icon(
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Edit'),
              onPressed: () {
                Navigator.pop(ctx);
                _showEditDialog(context, user, event);
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.delete, size: 16, color: Colors.red),
              label: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.pop(ctx);
                _confirmDelete(context, event);
              },
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  final DateTime selectedDate;
  final List<CalendarEventModel> events;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime>? onDayLongPressed;

  const _MonthCalendar({required this.selectedDate, required this.events, required this.onDaySelected, this.onDayLongPressed});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
    final daysInMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0).day;
    final startWeekday = (firstDayOfMonth.weekday - 1);

    final eventDates = events.map((e) => DateFormat('yyyy-MM-dd').format(e.startDate)).toSet();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    final prev = DateTime(selectedDate.year, selectedDate.month - 1, 1);
                    onDaySelected(prev);
                  },
                ),
                Text(
                  DateFormat('MMMM yyyy').format(selectedDate),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    final next = DateTime(selectedDate.year, selectedDate.month + 1, 1);
                    onDaySelected(next);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 7,
              childAspectRatio: 1.0,
              children: [
                for (final day in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                  Center(child: Text(day, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600))),
                for (int i = 0; i < startWeekday; i++)
                  const SizedBox.shrink(),
                for (int day = 1; day <= daysInMonth; day++)
                  _DayCell(
                    date: DateTime(selectedDate.year, selectedDate.month, day),
                    isSelected: selectedDate.year == selectedDate.year && selectedDate.month == selectedDate.month && selectedDate.day == day,
                    isToday: now.year == selectedDate.year && now.month == selectedDate.month && now.day == day,
                    hasEvent: eventDates.contains(DateFormat('yyyy-MM-dd').format(DateTime(selectedDate.year, selectedDate.month, day))),
                    onTap: () => onDaySelected(DateTime(selectedDate.year, selectedDate.month, day)),
                    onLongPress: onDayLongPressed != null ? () => onDayLongPressed!(DateTime(selectedDate.year, selectedDate.month, day)) : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final bool hasEvent;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _DayCell({required this.date, required this.isSelected, required this.isToday, required this.hasEvent, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : (isToday ? colorScheme.primaryContainer : null),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                '${date.day}',
                style: TextStyle(
                  color: isSelected ? colorScheme.onPrimary : (isToday ? colorScheme.onPrimaryContainer : null),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
            if (hasEvent)
              Positioned(
                bottom: 4,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isSelected ? colorScheme.onPrimary : colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final CalendarEventModel event;
  final DateFormat dateFormat;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const _EventCard({
    required this.event,
    required this.dateFormat,
    this.onEdit,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final canManage = onEdit != null || onDelete != null;
    String sourceTag = '';
    if (event.id.startsWith('announcement_')) {
      sourceTag = 'BROADCAST \u2022 ';
    } else if (event.id.startsWith('meeting_')) {
      sourceTag = 'MEETING \u2022 ';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: _typeColor(event.type).withValues(alpha: 0.12),
          child: Icon(_typeIcon(event.type), color: _typeColor(event.type), size: 20),
        ),
        title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$sourceTag${event.type.name.toUpperCase()} \u2022 ${dateFormat.format(event.startDate)}'),
        trailing: canManage
            ? PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (value) {
                  if (value == 'edit') onEdit?.call();
                  if (value == 'delete') onDelete?.call();
                },
                itemBuilder: (context) => [
                  if (onEdit != null)
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  if (onDelete != null)
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              )
            : (event.location != null ? Icon(Icons.location_on, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant) : null),
      ),
    );
  }

  Color _typeColor(CalendarEventType type) {
    switch (type) {
      case CalendarEventType.meeting: return Colors.purple;
      case CalendarEventType.contributionDeadline: return Colors.red;
      case CalendarEventType.communityEvent: return Colors.blue;
      case CalendarEventType.birthday: return Colors.pink;
      case CalendarEventType.holiday: return Colors.green;
      case CalendarEventType.reminder: return Colors.orange;
    }
  }

  IconData _typeIcon(CalendarEventType type) {
    switch (type) {
      case CalendarEventType.meeting: return Icons.event;
      case CalendarEventType.contributionDeadline: return Icons.payments;
      case CalendarEventType.communityEvent: return Icons.celebration;
      case CalendarEventType.birthday: return Icons.cake;
      case CalendarEventType.holiday: return Icons.public;
      case CalendarEventType.reminder: return Icons.alarm;
    }
  }
}
