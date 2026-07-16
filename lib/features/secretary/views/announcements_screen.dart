import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull;
    final orgId = user?.uid ?? '';
    final announcementsAsync = ref.watch(announcementsStreamProvider(orgId));
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateDialog(context, user),
          ),
        ],
      ),
      body: announcementsAsync.when(
        data: (announcements) {
          if (announcements.isEmpty) {
            return Center(
              child: Column(
                children: [
                  Icon(Icons.campaign_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('No announcements yet', style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }

          final pinned = announcements.where((a) => a.isPinned).toList();
          final others = announcements.where((a) => !a.isPinned).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(announcementsStreamProvider(orgId)),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ...pinned.map((a) => _AnnouncementCard(announcement: a, dateFormat: dateFormat, onEdit: () => _showEditDialog(context, a, user), onDelete: () => _deleteAnnouncement(a.id, orgId))),
                if (pinned.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Recent', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                ],
                ...others.map((a) => _AnnouncementCard(announcement: a, dateFormat: dateFormat, onEdit: () => _showEditDialog(context, a, user), onDelete: () => _deleteAnnouncement(a.id, orgId))),
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
              ElevatedButton(onPressed: () => ref.invalidate(announcementsStreamProvider(orgId)), child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, UserModel? user) {
    if (user == null) return;
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    AnnouncementCategory selectedCategory = AnnouncementCategory.general;
    bool isPinned = false;
    bool isScheduled = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Announcement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 12),
                TextField(controller: bodyController, decoration: const InputDecoration(labelText: 'Body'), maxLines: 4),
                const SizedBox(height: 12),
                DropdownButtonFormField<AnnouncementCategory>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: AnnouncementCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.name.replaceAll('_', ' ').toUpperCase()))).toList(),
                  onChanged: (v) { if (v != null) setDialogState(() => selectedCategory = v); },
                ),
                const SizedBox(height: 12),
                SwitchListTile(title: const Text('Pin'), value: isPinned, onChanged: (v) => setDialogState(() => isPinned = v)),
                SwitchListTile(title: const Text('Schedule'), value: isScheduled, onChanged: (v) => setDialogState(() => isScheduled = v)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                final controller = ref.read(announcementControllerProvider);
                final announcement = AnnouncementModel(
                  id: '',
                  organizationId: user.uid,
                  title: titleController.text.trim(),
                  body: bodyController.text.trim(),
                  category: selectedCategory,
                  isPinned: isPinned,
                  isScheduled: isScheduled,
                  createdBy: user.uid,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                await controller.createAnnouncement(announcement);
                if (ctx.mounted) Navigator.pop(ctx);
                ref.invalidate(announcementsStreamProvider(user.uid));
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Announcement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 12),
                TextField(controller: bodyController, decoration: const InputDecoration(labelText: 'Body'), maxLines: 4),
                const SizedBox(height: 12),
                DropdownButtonFormField<AnnouncementCategory>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: AnnouncementCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.name.replaceAll('_', ' ').toUpperCase()))).toList(),
                  onChanged: (v) { if (v != null) setDialogState(() => selectedCategory = v); },
                ),
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
                final controller = ref.read(announcementControllerProvider);
                final updated = announcement.copyWith(
                  title: titleController.text.trim(),
                  body: bodyController.text.trim(),
                  category: selectedCategory,
                  isPinned: isPinned,
                );
                await controller.updateAnnouncement(updated);
                if (ctx.mounted) Navigator.pop(ctx);
                ref.invalidate(announcementsStreamProvider(user.uid));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAnnouncement(String id, String orgId) async {
    final controller = ref.read(announcementControllerProvider);
    await controller.deleteAnnouncement(id);
    ref.invalidate(announcementsStreamProvider(orgId));
  }
}

class _AnnouncementCard extends StatelessWidget {
  final AnnouncementModel announcement;
  final DateFormat dateFormat;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AnnouncementCard({required this.announcement, required this.dateFormat, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          child: Icon(Icons.campaign, color: theme.colorScheme.primary),
        ),
        title: Text(announcement.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${announcement.category.name.toUpperCase()} \u2022 ${dateFormat.format(announcement.createdAt)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (announcement.isPinned) const Icon(Icons.push_pin, size: 16, color: Colors.red),
            IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: onEdit),
            IconButton(icon: const Icon(Icons.delete, size: 18), onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}
