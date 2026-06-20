import 'dart:async';
import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/constants/enums.dart';

class NotificationService {
  final FirebaseMessaging? _messaging;

  final List<String> _subscribedTopics = [];

  NotificationService({FirebaseMessaging? messaging})
      : _messaging = messaging;

  FirebaseMessaging get _messagingInstance {
    return _messaging ?? FirebaseMessaging.instance;
  }

  /// Top-level background message handler.
  static Future<void> firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    log('Background message received: ${message.messageId}');
  }

  Future<void> initialize() async {
    // Request permissions (iOS)
    final settings = await _messagingInstance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    log('FCM permission status: ${settings.authorizationStatus}');

    // Get FCM token
    final token = await _messagingInstance.getToken();
    log('FCM Token: $token');

    // Configure foreground handlers
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('Foreground message received: ${message.messageId}');
      log('Title: ${message.notification?.title}');
      log('Body: ${message.notification?.body}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      log('Message opened from background: ${message.messageId}');
    });

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler);
  }

  Future<String?> getToken() async {
    return _messagingInstance.getToken();
  }

  Future<void> subscribeToTopic(String topic) async {
    await _messagingInstance.subscribeToTopic(topic);
    if (!_subscribedTopics.contains(topic)) {
      _subscribedTopics.add(topic);
    }
    log('Subscribed to topic: $topic');
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _messagingInstance.unsubscribeFromTopic(topic);
    _subscribedTopics.remove(topic);
    log('Unsubscribed from topic: $topic');
  }

  Future<void> subscribeToRoleTopics(UserRole role, String memberId) async {
    // ALL users
    await subscribeToTopic('new_levies');
    await subscribeToTopic('general');

    switch (role) {
      case UserRole.member:
        await subscribeToTopic('member_$memberId');
        await subscribeToTopic('payment_reminders');
        break;
      case UserRole.treasurer:
        await subscribeToTopic('pending_payments');
        await subscribeToTopic('payment_notifications');
        await subscribeToTopic('member_activity');
        break;
      case UserRole.president:
        await subscribeToTopic('executive_updates');
        await subscribeToTopic('all_payments');
        break;
      case UserRole.superAdmin:
        await subscribeToTopic('all_events');
        await subscribeToTopic('member_activity');
        break;
    }
  }

  Future<void> unsubscribeFromAllTopics() async {
    final topics = List<String>.from(_subscribedTopics);
    for (final topic in topics) {
      await unsubscribeFromTopic(topic);
    }
    _subscribedTopics.clear();
  }

  Stream<RemoteMessage> get onForegroundMessage {
    return FirebaseMessaging.onMessage;
  }

  Stream<RemoteMessage> get onMessageOpenedApp {
    return FirebaseMessaging.onMessageOpenedApp;
  }

  List<String> get subscribedTopics => List.unmodifiable(_subscribedTopics);
}
