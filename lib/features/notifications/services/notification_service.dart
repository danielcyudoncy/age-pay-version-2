import 'dart:async';
import 'dart:developer';

import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../../core/constants/enums.dart';

class NotificationService {
  final FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin? _localNotifications;

  final List<String> _subscribedTopics = [];

  NotificationService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _messaging = messaging,
        _localNotifications = localNotifications;

  FirebaseMessaging get _messagingInstance {
    return _messaging ?? FirebaseMessaging.instance;
  }

  FlutterLocalNotificationsPlugin get _localNotificationsInstance {
    return _localNotifications ?? FlutterLocalNotificationsPlugin();
  }

  static const AndroidNotificationChannel defaultChannel =
      AndroidNotificationChannel(
    'agepay_high_importance_channel',
    'AgePay Notifications',
    description:
        'Urgent notifications with sound, banners, and app icon badges for community announcements, dues, and payments.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  static const AndroidNotificationChannel incomingCallChannel =
      AndroidNotificationChannel(
    'agepay_incoming_call_channel',
    'Incoming Calls',
    description:
        'Urgent ringing alerts for incoming real-time audio calls.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  /// Top-level background message handler.
  static Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    log('Background message received: ${message.messageId}');
  }

  Future<void> initialize() async {
    // 1. Initialize Flutter Local Notifications for sound, status bar, and app icon badge
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsDarwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    try {
      await _localNotificationsInstance.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (response) {
          log('Notification tapped with payload: ${response.payload}');
        },
      );

      final androidPlugin = _localNotificationsInstance
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(defaultChannel);
        await androidPlugin.createNotificationChannel(incomingCallChannel);
        await androidPlugin.requestNotificationsPermission();
      }
    } catch (e) {
      log('Local notifications initialization note: $e');
    }

    // 2. Request FCM permissions & set foreground presentation options
    try {
      final settings = await _messagingInstance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      log('FCM permission status: ${settings.authorizationStatus}');

      await _messagingInstance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      log('FCM permission setup note: $e');
    }

    // 3. Get FCM token
    try {
      final token = await _messagingInstance.getToken();
      log('FCM Token: $token');
    } catch (e) {
      log('FCM token fetch note: $e');
    }

    // 4. Configure foreground handlers
    try {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        log('Foreground message received: ${message.messageId}');
        final title = message.notification?.title ??
            message.data['title'] ??
            'AgePay Notification';
        final body = message.notification?.body ?? message.data['body'] ?? '';
        if (title.isNotEmpty || body.isNotEmpty) {
          showNotification(
            title: title,
            body: body,
            payload: message.data['payload'],
          );
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        log('Message opened from background: ${message.messageId}');
      });
    } catch (e) {
      log('FCM stream listener note: $e');
    }
  }

  /// Displays a heads-up system notification with high importance, default sound,
  /// vibration, and app icon badge. Also triggers an immediate in-app sound.
  Future<void> showNotification({
    int? id,
    required String title,
    required String body,
    String? payload,
  }) async {
    // 1. Play immediate in-app sound and haptic vibration feedback
    try {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.mediumImpact();
    } catch (_) {}

    // 2. Trigger OS notification tray banner, ringtone, and app icon badge
    try {
      final notifId =
          id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);
      const androidDetails = AndroidNotificationDetails(
        'agepay_high_importance_channel',
        'AgePay Notifications',
        channelDescription:
            'Urgent notifications with sound, banners, and app icon badges for community announcements, dues, and payments.',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        channelShowBadge: true,
        icon: '@mipmap/ic_launcher',
      );
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _localNotificationsInstance.show(
        id: notifId,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      log('Local notification display note: $e');
    }
  }

  /// Displays a high-priority heads-up call banner with full-screen intent and ringtone
  Future<void> showCallNotification({
    required String callId,
    required String callerName,
    required String callerRole,
  }) async {
    try {
      final notifId = callId.hashCode.remainder(100000).abs();
      const androidDetails = AndroidNotificationDetails(
        'agepay_incoming_call_channel',
        'Incoming Calls',
        channelDescription:
            'Urgent ringing alerts for incoming real-time audio calls.',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.call,
        fullScreenIntent: true,
        ongoing: true,
        autoCancel: false,
        playSound: true,
        enableVibration: true,
        channelShowBadge: true,
        icon: '@mipmap/ic_launcher',
      );
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _localNotificationsInstance.show(
        id: notifId,
        title: 'Incoming Audio Call',
        body: '$callerName ($callerRole) is calling...',
        notificationDetails: details,
        payload: callId,
      );
    } catch (e) {
      log('Call notification display note: $e');
    }
  }

  /// Cancels any active incoming call notification
  Future<void> cancelCallNotification(String callId) async {
    try {
      final notifId = callId.hashCode.remainder(100000).abs();
      await _localNotificationsInstance.cancel(id: notifId);
    } catch (_) {}
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
      case UserRole.publicRelationsOfficer:
        await subscribeToTopic('executive_updates');
        await subscribeToTopic('all_events');
        break;
      case UserRole.provost:
        await subscribeToTopic('executive_updates');
        await subscribeToTopic('member_activity');
        break;
      case UserRole.vicePresident:
      case UserRole.secretary:
      case UserRole.viceSecretary:
      case UserRole.viceTreasurer:
      case UserRole.financialSecretary:
      case UserRole.auditor:
      case UserRole.executiveMember:
      case UserRole.committeeChair:
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
    try {
      return FirebaseMessaging.onMessage;
    } catch (_) {
      return const Stream.empty();
    }
  }

  Stream<RemoteMessage> get onMessageOpenedApp {
    try {
      return FirebaseMessaging.onMessageOpenedApp;
    } catch (_) {
      return const Stream.empty();
    }
  }

  List<String> get subscribedTopics => List.unmodifiable(_subscribedTopics);
}
