// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/secretary/controllers/calendar_event_provider.dart';
import 'package:cls/features/secretary/controllers/secretary_dashboard_provider.dart';
import 'package:cls/features/secretary/models/calendar_event_model.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull;
    final orgId = user?.uid ?? '';
    final eventsAsync = ref.watch(calendarEventsStreamProvider(orgId));
    final dateFormat = DateFormat('MMM dd, yyyy \u2022 HH:mm');

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

          final upcoming = events.where((e) => !e.startDate.isBefore(now)).toList()
            ..sort((a, b) => a.startDate.compareTo(b.startDate));
          final past = events.where((e) => e.startDate.isBefore(now)).toList()
            ..sort((a, b) => b.startDate.compareTo(a.startDate));

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(calendarEventsStreamProvider(orgId)),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _MonthCalendar(
                  selectedDate: _selectedDate,
                  events: events,
                  onDaySelected: (date) {
                    setState(() => _selectedDate = date);
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
                  ...selectedDayEvents.map((e) => _EventCard(event: e, dateFormat: dateFormat)),
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
                  ...upcoming.map((e) => _EventCard(event: e, dateFormat: dateFormat)),
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
                  ...past.map((e) => _EventCard(event: e, dateFormat: dateFormat)),
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
              ElevatedButton(onPressed: () => ref.invalidate(calendarEventsStreamProvider(orgId)), child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, UserModel? user) {
    if (user == null) return;
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();
    CalendarEventType selectedType = CalendarEventType.communityEvent;
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(hours: 2));

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
                final controller = ref.read(calendarEventControllerProvider);
                final event = CalendarEventModel(
                  id: '',
                  organizationId: user.uid,
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
                await controller.createEvent(event);
                if (ctx.mounted) Navigator.pop(ctx);
                ref.invalidate(calendarEventsStreamProvider(user.uid));
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  final DateTime selectedDate;
  final List<CalendarEventModel> events;
  final ValueChanged<DateTime> onDaySelected;

  const _MonthCalendar({required this.selectedDate, required this.events, required this.onDaySelected});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
    final daysInMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0).day;
    final startWeekday = firstDayOfMonth.weekday % 7;

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
                    isSelected: selectedDate.year == now.year && selectedDate.month == now.month && selectedDate.day == day,
                    isToday: now.year == selectedDate.year && now.month == selectedDate.month && now.day == day,
                    hasEvent: eventDates.contains(DateFormat('yyyy-MM-dd').format(DateTime(selectedDate.year, selectedDate.month, day))),
                    onTap: () => onDaySelected(DateTime(selectedDate.year, selectedDate.month, day)),
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

  const _DayCell({required this.date, required this.isSelected, required this.isToday, required this.hasEvent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
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

  const _EventCard({required this.event, required this.dateFormat});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _typeColor(event.type).withValues(alpha: 0.12),
          child: Icon(_typeIcon(event.type), color: _typeColor(event.type), size: 20),
        ),
        title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${event.type.name.toUpperCase()} \u2022 ${dateFormat.format(event.startDate)}'),
        trailing: event.location != null ? Icon(Icons.location_on, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant) : null,
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
