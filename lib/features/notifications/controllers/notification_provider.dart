import 'dart:async';

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
  final String? _userId;
  final dynamic _role;
  final String? _branchId;
  final bool _isNationalExecutive;

  NotificationListNotifier(
    NotificationService service, {
    NotificationRepository? repository,
    String? organizationId,
    String? userId,
    dynamic role,
    String? branchId,
    bool isNationalExecutive = false,
  })  : _repository = repository,
        _organizationId = organizationId,
        _userId = userId,
        _role = role,
        _branchId = branchId,
        _isNationalExecutive = isNationalExecutive,
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
        targetBranchId: message.data['targetBranchId'],
      );
      addNotification(notification);
    });

    _subscribeToFirestore();
  }

  void _subscribeToFirestore() {
    _firestoreSubscription?.cancel();
    if (_repository == null || _userId == null) return;

    _firestoreSubscription = _repository
        .streamNotifications(
          organizationId: _organizationId ?? '',
          userId: _userId,
          role: _role,
          branchId: _branchId,
          isNationalExecutive: _isNationalExecutive,
        )
        .listen((firestoreNotifications) {
          state = firestoreNotifications;
        });
  }

  void addNotification(NotificationModel notification) {
    if (state.any((n) => n.id == notification.id)) return;
    if (_repository != null &&
        !_repository.isNotificationForUser(notification, _userId, _role)) {
      return;
    }
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
    _subscribeToFirestore();
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

      if (user == null) {
        return NotificationListNotifier(service);
      }

      return NotificationListNotifier(
        service,
        repository: repository,
        organizationId: user.organizationId,
        userId: user.uid,
        role: user.role,
        branchId: user.branchId,
        isNationalExecutive: user.isNationalExecutive,
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
