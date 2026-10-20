import 'dart:async';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../auth/controllers/auth_provider.dart';
import '../services/notification_service.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

class NotificationListNotifier extends StateNotifier<List<NotificationModel>> {
  StreamSubscription<RemoteMessage>? _subscription;
  StreamSubscription<List<NotificationModel>>? _firestoreSubscription;
  final NotificationRepository? _repository;
  final String? _organizationId;

  NotificationListNotifier(
    NotificationService service, {
    NotificationRepository? repository,
    String? organizationId,
    String? userId,
    dynamic role,
  })  : _repository = repository,
        _organizationId = organizationId,
        super([]) {
    // 1. Foreground push message listener
    _subscription = service.onForegroundMessage.listen((message) {
      final notification = NotificationModel(
        id:
            message.messageId ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: message.notification?.title ?? 'Notification',
        body: message.notification?.body ?? '',
        type: message.data['type'] ?? 'general',
        payload: message.data['payload'],
        receivedAt: DateTime.now(),
        imageUrl: message.notification?.android?.imageUrl,
        organizationId: organizationId ?? '',
      );
      addNotification(notification);
    });

    // 2. Real-time Firestore notification stream
    if (_repository != null &&
        organizationId != null &&
        organizationId.isNotEmpty) {
      _firestoreSubscription = _repository
          .streamNotifications(
            organizationId: organizationId,
            userId: userId,
            role: role,
          )
          .listen((firestoreNotifications) {
            final Map<String, NotificationModel> map = {};
            for (final n in state) {
              map[n.id] = n;
            }
            for (final n in firestoreNotifications) {
              map[n.id] = n;
            }
            final list = map.values.toList()
              ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
            state = list;
          });
    }
  }

  void addNotification(NotificationModel notification) {
    if (state.any((n) => n.id == notification.id)) return;
    state = [notification, ...state];
  }

  Future<void> markAsRead(String id) async {
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(read: true) else n,
    ];
    await _repository?.markAsRead(id);
  }

  Future<void> markAllAsRead() async {
    state = [for (final n in state) n.copyWith(read: true)];
    final orgId = _organizationId;
    if (orgId != null && orgId.isNotEmpty) {
      await _repository?.markAllAsRead(organizationId: orgId);
    }
  }

  Future<void> deleteNotification(String id) async {
    state = state.where((n) => n.id != id).toList();
    await _repository?.deleteNotification(id);
  }

  void refresh() {
    log('Notification list refreshed');
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _firestoreSubscription?.cancel();
    super.dispose();
  }
}

final notificationListProvider =
    StateNotifierProvider<NotificationListNotifier, List<NotificationModel>>((
      ref,
    ) {
      final service = ref.watch(notificationServiceProvider);
      final repository = ref.watch(notificationRepositoryProvider);
      final authState = ref.watch(authProvider);
      final user = authState.valueOrNull;

      return NotificationListNotifier(
        service,
        repository: repository,
        organizationId: user?.organizationId,
        userId: user?.uid,
        role: user?.role,
      );
    });

final notificationStreamProvider = StreamProvider<List<NotificationModel>>((
  ref,
) {
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
