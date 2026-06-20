import 'dart:async';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../data/services/notification_service.dart';
import '../models/notification_model.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationListNotifier extends StateNotifier<List<NotificationModel>> {
  StreamSubscription<RemoteMessage>? _subscription;

  NotificationListNotifier(NotificationService service) : super([]) {
    _subscription = service.onForegroundMessage.listen((message) {
      final notification = NotificationModel(
        id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: message.notification?.title ?? 'Notification',
        body: message.notification?.body ?? '',
        type: message.data['type'] ?? 'general',
        payload: message.data['payload'],
        receivedAt: DateTime.now(),
        imageUrl: message.notification?.android?.imageUrl,
      );
      addNotification(notification);
    });
  }

  void addNotification(NotificationModel notification) {
    state = [notification, ...state];
  }

  void markAsRead(String id) {
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(read: true) else n
    ];
  }

  void deleteNotification(String id) {
    state = state.where((n) => n.id != id).toList();
  }

  void refresh() {
    // No-op for in-memory list; allows pull-to-refresh gesture.
    log('Notification list refreshed');
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final notificationListProvider =
    StateNotifierProvider<NotificationListNotifier, List<NotificationModel>>(
        (ref) {
  final service = ref.watch(notificationServiceProvider);
  return NotificationListNotifier(service);
});

final notificationStreamProvider =
    StreamProvider<List<NotificationModel>>((ref) {
  final list = ref.watch(notificationListProvider);
  return Stream.value(list);
});

final unreadCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationListProvider);
  return notifications.where((n) => !n.read).length;
});

final initializeNotificationsProvider = FutureProvider<void>((ref) async {
  final service = ref.read(notificationServiceProvider);
  await service.initialize();
});
