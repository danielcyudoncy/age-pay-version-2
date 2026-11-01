import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/admin/controllers/admin_provider.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/secretary/controllers/announcement_provider.dart';
import 'package:cls/features/secretary/models/announcement_model.dart';
import 'package:cls/features/secretary/controllers/secretary_dashboard_provider.dart';

class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull;
    final orgId = user?.organizationId ?? '';
    final announcementsAsync = ref.watch(announcementsStreamProvider(orgId));
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New announcement',
            onPressed: () => _showCreateDialog(context, user, _selectedDate),
          ),
        ],
      ),
      body: announcementsAsync.when(
        data: (announcements) {
          final visible =
              announcements.where((a) => a.isVisibleTo(user)).toList();
          final announcementDates = visible
              .where((a) => a.announcementDate != null)
              .map((a) => DateFormat('yyyy-MM-dd').format(a.announcementDate!))
              .toSet();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(announcementsStreamProvider(orgId)),
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
                  announcementDates: announcementDates,
                  onDaySelected: (date) => setState(() => _selectedDate = date),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Announcements for ${DateFormat('MMM dd, yyyy').format(_selectedDate)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                      onPressed: () => _showCreateDialog(context, user, _selectedDate),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _SelectedDayAnnouncements(
                  orgId: orgId,
                  date: _selectedDate,
                  dateFormat: dateFormat,
                  onEdit: (a) => _showEditDialog(context, a, user),
                  onDelete: (a) => _deleteAnnouncement(a.id, orgId),
                ),
                const SizedBox(height: 20),
                Text(
                  'All Announcements',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (visible.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.campaign_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('No announcements yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            'Tap a date on the calendar, then tap Add or + above.',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...visible.map(
                    (a) => _AnnouncementCard(
                      announcement: a,
                      dateFormat: dateFormat,
                      onEdit: () => _showEditDialog(context, a, user),
                      onDelete: () => _deleteAnnouncement(a.id, orgId),
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
                onPressed: () => ref.invalidate(announcementsStreamProvider(orgId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, UserModel? user, DateTime date) {
    if (user == null) return;
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    AnnouncementCategory selectedCategory = AnnouncementCategory.general;
    bool isPinned = false;
    DateTime announcementDate = date;

    final isNationalOrAdmin = user.isNationalExecutive ||
        (user.role == UserRole.superAdmin &&
            (user.branchId == null || user.branchId!.isEmpty));

    String selectedAudience = isNationalOrAdmin ? 'all' : 'branch';
    String? selectedBranchId = user.branchId;
    String? selectedBranchName = user.branchName;

    final List<DropdownMenuItem<String>> audienceItems = isNationalOrAdmin
        ? const [
            DropdownMenuItem(
              value: 'all',
              child: Text('Everyone (All Members Worldwide)', overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'allExecutives',
              child: Text('All Executives (National & Branches)', overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'nationalExecutives',
              child: Text('National Executives Only', overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'branch',
              child: Text('Specific Branch (All Members)', overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'branchExecutives',
              child: Text('Specific Branch (Executives Only)', overflow: TextOverflow.ellipsis),
            ),
          ]
        : [
            DropdownMenuItem(
              value: 'branch',
              child: Text(
                'My Branch (${user.branchName ?? 'Branch'} Members)',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: 'branchExecutives',
              child: Text(
                'My Branch (${user.branchName ?? 'Branch'} Executives Only)',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Announcement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: announcementDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setDialogState(() => announcementDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder()),
                    child: Text(DateFormat('MMM dd, yyyy').format(announcementDate)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 12),
                TextField(controller: bodyController, decoration: const InputDecoration(labelText: 'Body'), maxLines: 4),
                const SizedBox(height: 12),
                DropdownButtonFormField<AnnouncementCategory>(
                  isExpanded: true,
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: AnnouncementCategory.values
                      .map((c) => DropdownMenuItem(value: c, child: Text(c.name.replaceAll('_', ' ').toUpperCase(), overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) { if (v != null) setDialogState(() => selectedCategory = v); },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedAudience,
                  decoration: const InputDecoration(
                    labelText: 'Target Audience',
                    prefixIcon: Icon(Icons.people_alt_outlined),
                  ),
                  items: audienceItems,
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedAudience = v);
                    }
                  },
                ),
                if (isNationalOrAdmin &&
                    (selectedAudience == 'branch' ||
                        selectedAudience == 'branchExecutives')) ...[
                  const SizedBox(height: 12),
                  Consumer(
                    builder: (context, ref, _) {
                      final branchesAsync =
                          ref.watch(branchesStreamFamily(user.organizationId));
                      return branchesAsync.when(
                        data: (branches) {
                          if (branches.isEmpty) {
                            return const Text('No branches available');
                          }
                          final currentBranch = branches.any((b) => b.id == selectedBranchId)
                              ? selectedBranchId
                              : branches.first.id;
                          if (selectedBranchId == null) {
                            selectedBranchId = branches.first.id;
                            selectedBranchName = branches.first.name;
                          }
                          return DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: currentBranch,
                            decoration: const InputDecoration(
                              labelText: 'Target Branch',
                              prefixIcon: Icon(Icons.location_city),
                            ),
                            items: branches
                                .map(
                                  (b) => DropdownMenuItem(
                                    value: b.id,
                                    child: Text(b.name, overflow: TextOverflow.ellipsis),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                final matched = branches.firstWhere((b) => b.id == val);
                                setDialogState(() {
                                  selectedBranchId = matched.id;
                                  selectedBranchName = matched.name;
                                });
                              }
                            },
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => const Text('Error loading branches'),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 12),
                SwitchListTile(title: const Text('Pin'), value: isPinned, onChanged: (v) => setDialogState(() => isPinned = v)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                try {
                  final controller = ref.read(announcementControllerProvider);
                  String? finalBranchId;
                  String? finalBranchName;
                  if (selectedAudience == 'branch' || selectedAudience == 'branchExecutives') {
                    finalBranchId = selectedBranchId;
                    finalBranchName = selectedBranchName;
                  } else if (!isNationalOrAdmin) {
                    finalBranchId = user.branchId;
                    finalBranchName = user.branchName;
                  }
                  final announcement = AnnouncementModel(
                    id: '',
                    organizationId: user.organizationId,
                    title: titleController.text.trim(),
                    body: bodyController.text.trim(),
                    category: selectedCategory,
                    isPinned: isPinned,
                    announcementDate: announcementDate,
                    createdBy: user.uid,
                    targetAudience: selectedAudience,
                    targetBranchId: finalBranchId,
                    targetBranchName: finalBranchName,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  await controller.createAnnouncement(announcement);
                  if (ctx.mounted) Navigator.pop(ctx);
                  ref.invalidate(announcementsStreamProvider(user.organizationId));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Announcement created successfully')),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(backgroundColor: Colors.red, content: Text('Failed to create announcement: $e')),
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

  void _showEditDialog(BuildContext context, AnnouncementModel announcement, UserModel? user) {
    if (user == null) return;
    final titleController = TextEditingController(text: announcement.title);
    final bodyController = TextEditingController(text: announcement.body);
    AnnouncementCategory selectedCategory = announcement.category;
    bool isPinned = announcement.isPinned;
    DateTime announcementDate = announcement.announcementDate ?? DateTime.now();

    final isNationalOrAdmin = user.isNationalExecutive ||
        (user.role == UserRole.superAdmin &&
            (user.branchId == null || user.branchId!.isEmpty));

    String selectedAudience = announcement.targetAudience;
    if (selectedAudience.isEmpty) selectedAudience = 'all';
    String? selectedBranchId = announcement.targetBranchId ?? user.branchId;
    String? selectedBranchName = announcement.targetBranchName ?? user.branchName;

    final List<DropdownMenuItem<String>> audienceItems = isNationalOrAdmin
        ? const [
            DropdownMenuItem(
              value: 'all',
              child: Text('Everyone (All Members Worldwide)', overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'allExecutives',
              child: Text('All Executives (National & Branches)', overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'nationalExecutives',
              child: Text('National Executives Only', overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'branch',
              child: Text('Specific Branch (All Members)', overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'branchExecutives',
              child: Text('Specific Branch (Executives Only)', overflow: TextOverflow.ellipsis),
            ),
          ]
        : [
            DropdownMenuItem(
              value: 'branch',
              child: Text(
                'My Branch (${user.branchName ?? 'Branch'} Members)',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: 'branchExecutives',
              child: Text(
                'My Branch (${user.branchName ?? 'Branch'} Executives Only)',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Announcement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: announcementDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setDialogState(() => announcementDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder()),
                    child: Text(DateFormat('MMM dd, yyyy').format(announcementDate)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 12),
                TextField(controller: bodyController, decoration: const InputDecoration(labelText: 'Body'), maxLines: 4),
                const SizedBox(height: 12),
                DropdownButtonFormField<AnnouncementCategory>(
                  isExpanded: true,
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: AnnouncementCategory.values
                      .map((c) => DropdownMenuItem(value: c, child: Text(c.name.replaceAll('_', ' ').toUpperCase(), overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) { if (v != null) setDialogState(() => selectedCategory = v); },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedAudience,
                  decoration: const InputDecoration(
                    labelText: 'Target Audience',
                    prefixIcon: Icon(Icons.people_alt_outlined),
                  ),
                  items: audienceItems,
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedAudience = v);
                    }
                  },
                ),
                if (isNationalOrAdmin &&
                    (selectedAudience == 'branch' ||
                        selectedAudience == 'branchExecutives')) ...[
                  const SizedBox(height: 12),
                  Consumer(
                    builder: (context, ref, _) {
                      final branchesAsync =
                          ref.watch(branchesStreamFamily(user.organizationId));
                      return branchesAsync.when(
                        data: (branches) {
                          if (branches.isEmpty) {
                            return const Text('No branches available');
                          }
                          final currentBranch = branches.any((b) => b.id == selectedBranchId)
                              ? selectedBranchId
                              : branches.first.id;
                          if (selectedBranchId == null) {
                            selectedBranchId = branches.first.id;
                            selectedBranchName = branches.first.name;
                          }
                          return DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: currentBranch,
                            decoration: const InputDecoration(
                              labelText: 'Target Branch',
                              prefixIcon: Icon(Icons.location_city),
                            ),
                            items: branches
                                .map(
                                  (b) => DropdownMenuItem(
                                    value: b.id,
                                    child: Text(b.name, overflow: TextOverflow.ellipsis),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                final matched = branches.firstWhere((b) => b.id == val);
                                setDialogState(() {
                                  selectedBranchId = matched.id;
                                  selectedBranchName = matched.name;
                                });
                              }
                            },
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => const Text('Error loading branches'),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 12),
                SwitchListTile(title: const Text('Pin'), value: isPinned, onChanged: (v) => setDialogState(() => isPinned = v)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                try {
                  final controller = ref.read(announcementControllerProvider);
                  String? finalBranchId;
                  String? finalBranchName;
                  if (selectedAudience == 'branch' || selectedAudience == 'branchExecutives') {
                    finalBranchId = selectedBranchId;
                    finalBranchName = selectedBranchName;
                  } else if (!isNationalOrAdmin) {
                    finalBranchId = user.branchId;
                    finalBranchName = user.branchName;
                  }
                  final updated = announcement.copyWith(
                    title: titleController.text.trim(),
                    body: bodyController.text.trim(),
                    category: selectedCategory,
                    isPinned: isPinned,
                    announcementDate: announcementDate,
                    targetAudience: selectedAudience,
                    targetBranchId: finalBranchId,
                    targetBranchName: finalBranchName,
                  );
                  await controller.updateAnnouncement(updated);
                  if (ctx.mounted) Navigator.pop(ctx);
                  ref.invalidate(announcementsStreamProvider(user.organizationId));
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(backgroundColor: Colors.red, content: Text('Failed to update announcement: $e')),
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

  Future<void> _deleteAnnouncement(String id, String orgId) async {
    try {
      final controller = ref.read(announcementControllerProvider);
      await controller.deleteAnnouncement(id);
      ref.invalidate(announcementsStreamProvider(orgId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Failed to delete announcement: $e')),
        );
      }
    }
  }
}

class _SelectedDayAnnouncements extends ConsumerWidget {
  final String orgId;
  final DateTime date;
  final DateFormat dateFormat;
  final void Function(AnnouncementModel) onEdit;
  final void Function(AnnouncementModel) onDelete;

  const _SelectedDayAnnouncements({
    required this.orgId,
    required this.date,
    required this.dateFormat,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayAnnouncementsAsync = ref.watch(
      announcementsByDateStreamProvider((orgId: orgId, date: date)),
    );
    final user = ref.watch(authProvider).valueOrNull;

    return dayAnnouncementsAsync.when(
      data: (items) {
        final visible = items.where((a) => a.isVisibleTo(user)).toList();
        if (visible.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No announcements on this date.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ),
          );
        }
        return Column(
          children: visible
              .map((a) => _AnnouncementCard(
                    announcement: a,
                    dateFormat: dateFormat,
                    onEdit: () => onEdit(a),
                    onDelete: () => onDelete(a),
                  ))
              .toList(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  final DateTime selectedDate;
  final Set<String> announcementDates;
  final ValueChanged<DateTime> onDaySelected;

  const _MonthCalendar({
    required this.selectedDate,
    required this.announcementDates,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
    final daysInMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0).day;
    final startWeekday = (firstDayOfMonth.weekday - 1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () =>
                      onDaySelected(DateTime(selectedDate.year, selectedDate.month - 1, 1)),
                ),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        DateFormat('MMMM yyyy').format(selectedDate),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () =>
                      onDaySelected(DateTime(selectedDate.year, selectedDate.month + 1, 1)),
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
                  Center(
                    child: Text(
                      day,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                    ),
                  ),
                for (int i = 0; i < startWeekday; i++) const SizedBox.shrink(),
                for (int day = 1; day <= daysInMonth; day++) ...[
                  _DayCell(
                    date: DateTime(selectedDate.year, selectedDate.month, day),
                    isSelected:
                        selectedDate.year == selectedDate.year &&
                        selectedDate.month == selectedDate.month &&
                        selectedDate.day == day,
                    isToday: now.year == selectedDate.year && now.month == selectedDate.month && now.day == day,
                    hasAnnouncement: announcementDates.contains(
                      DateFormat('yyyy-MM-dd').format(DateTime(selectedDate.year, selectedDate.month, day)),
                    ),
                    onTap: () => onDaySelected(DateTime(selectedDate.year, selectedDate.month, day)),
                  ),
                ],
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
  final bool hasAnnouncement;
  final VoidCallback onTap;

  const _DayCell({
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.hasAnnouncement,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : (isToday ? colorScheme.primaryContainer : null),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${date.day}',
                style: TextStyle(
                  color: isSelected
                      ? colorScheme.onPrimary
                      : (isToday ? colorScheme.onPrimaryContainer : null),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
            if (hasAnnouncement) ...[
              const SizedBox(height: 2),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: isSelected ? colorScheme.onPrimary : colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final AnnouncementModel announcement;
  final DateFormat dateFormat;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AnnouncementCard({
    required this.announcement,
    required this.dateFormat,
    required this.onEdit,
    required this.onDelete,
  });

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
            // Header Row: Avatar, Title & Date, Pin, Edit & Delete buttons
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
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (announcement.isPinned) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.push_pin, size: 16, color: Colors.red),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateFormat.format(date),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.edit, size: 18),
                  tooltip: 'Edit announcement',
                  onPressed: onEdit,
                ),
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  tooltip: 'Delete announcement',
                  onPressed: onDelete,
                ),
              ],
            ),
            if (announcement.body.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                announcement.body,
                style: const TextStyle(fontSize: 14),
              ),
            ],
            const SizedBox(height: 12),
            // Tags: Category and Audience
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
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width - 96,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_alt_outlined, size: 12, color: theme.colorScheme.secondary),
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
          ],
        ),
      ),
    );
  }
}
