import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/models/user_model.dart';
import '../controllers/notification_provider.dart';
import '../widgets/notification_widgets.dart';

class NotificationsScreen extends ConsumerWidget {
  final UserModel currentUser;

  const NotificationsScreen({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationListProvider);
    final unreadCount = ref.watch(unreadCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Notifications'),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Badge(
                label: Text('$unreadCount'),
                child: const SizedBox(width: 16, height: 16),
              ),
            ],
          ],
        ),
        actions: [
          if (notifications.isNotEmpty)
            TextButton(
              onPressed: () {
                for (final n in notifications.where((n) => !n.read)) {
                  ref.read(notificationListProvider.notifier).markAsRead(n.id);
                }
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(notificationListProvider.notifier).refresh();
        },
        child: notifications.isEmpty
            ? EmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return NotificationCard(
                    notification: notification,
                    onTap: () => ref
                        .read(notificationListProvider.notifier)
                        .markAsRead(notification.id),
                    onDismiss: () => ref
                        .read(notificationListProvider.notifier)
                        .deleteNotification(notification.id),
                  );
                },
              ),
      ),
    );
  }
}


