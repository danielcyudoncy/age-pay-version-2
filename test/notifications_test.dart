// test/notifications_test.dart
import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/notifications/services/notification_service.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/notifications/models/notification_model.dart';
import 'package:cls/features/notifications/controllers/notification_provider.dart';
import 'package:cls/features/notifications/views/notifications_screen.dart';

class _MockFirebaseMessaging {
  final List<String> subscribedTopics = [];
  String? token = 'test-fcm-token';
  bool requestPermissionCalled = false;

  Future<NotificationSettings> requestPermission({
    bool alert = false,
    bool announcement = false,
    bool badge = false,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = false,
  }) async {
    requestPermissionCalled = true;
    return const NotificationSettings(
      authorizationStatus: AuthorizationStatus.authorized,
      alert: AppleNotificationSetting.enabled,
      announcement: AppleNotificationSetting.disabled,
      badge: AppleNotificationSetting.enabled,
      carPlay: AppleNotificationSetting.disabled,
      criticalAlert: AppleNotificationSetting.disabled,
      lockScreen: AppleNotificationSetting.enabled,
      notificationCenter: AppleNotificationSetting.enabled,
      showPreviews: AppleShowPreviewSetting.always,
      sound: AppleNotificationSetting.enabled,
      timeSensitive: AppleNotificationSetting.disabled,
    );
  }

  Future<String?> getToken({String? vapidKey}) async => token;

  Future<void> subscribeToTopic(String topic) async {
    if (!subscribedTopics.contains(topic)) {
      subscribedTopics.add(topic);
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    subscribedTopics.remove(topic);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Adapter that forwards FirebaseMessaging-style calls to our mock.
class _TestableNotificationService extends NotificationService {
  final _MockFirebaseMessaging _mock;
  final StreamController<RemoteMessage> _foregroundController;
  final StreamController<RemoteMessage> _openedController;

  _TestableNotificationService(this._mock)
    : _foregroundController = StreamController<RemoteMessage>.broadcast(),
      _openedController = StreamController<RemoteMessage>.broadcast(),
      super(messaging: null);

  @override
  Future<void> initialize() async {
    await _mock.requestPermission();
    await getToken();
  }

  @override
  Future<String?> getToken() => _mock.getToken();

  @override
  Future<void> subscribeToTopic(String topic) async {
    await _mock.subscribeToTopic(topic);
    if (!mockSubscribedTopics.contains(topic)) {
      _mock.subscribedTopics.add(topic);
    }
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    await _mock.unsubscribeFromTopic(topic);
    _mock.subscribedTopics.remove(topic);
  }

  @override
  Stream<RemoteMessage> get onForegroundMessage => _foregroundController.stream;

  @override
  Stream<RemoteMessage> get onMessageOpenedApp => _openedController.stream;

  void dispose() {
    _foregroundController.close();
    _openedController.close();
  }

  @override
  Future<void> unsubscribeFromAllTopics() async {
    final topics = List<String>.from(_mock.subscribedTopics);
    for (final topic in topics) {
      await unsubscribeFromTopic(topic);
    }
    _mock.subscribedTopics.clear();
  }

  List<String> get mockSubscribedTopics =>
      List.unmodifiable(_mock.subscribedTopics);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDate = DateTime(2026, 6, 15);

  final testUser = UserModel(
    uid: 'm1',
    organizationId: 'm1',
    email: 'test@test.com',
    displayName: 'Test Member',
    phoneNumber: '08012345678',
    role: UserRole.member,
    createdAt: testDate,
  );

  final testNotifications = [
    NotificationModel(
      id: 'n1',
      title: 'New Levy',
      body: 'A new monthly due has been created.',
      type: 'levy',
      receivedAt: testDate.subtract(const Duration(hours: 2)),
      read: false,
    ),
    NotificationModel(
      id: 'n2',
      title: 'Payment Approved',
      body: 'Your payment of ₦5,000 has been approved.',
      type: 'payment',
      receivedAt: testDate.subtract(const Duration(days: 1)),
      read: true,
    ),
    NotificationModel(
      id: 'n3',
      title: 'Reminder',
      body: 'Your monthly due is due tomorrow.',
      type: 'reminder',
      receivedAt: testDate.subtract(const Duration(minutes: 30)),
      read: false,
    ),
  ];

  group('NotificationService', () {
    test('initializes and gets topic subscriptions', () async {
      final mock = _MockFirebaseMessaging();
      final service = _TestableNotificationService(mock);

      await service.initialize();

      expect(mock.requestPermissionCalled, isTrue);
      expect(await service.getToken(), 'test-fcm-token');
    });

    test('subscribes member to correct topics', () async {
      final mock = _MockFirebaseMessaging();
      final service = _TestableNotificationService(mock);

      await service.subscribeToRoleTopics(UserRole.member, 'm1');

      expect(service.mockSubscribedTopics, contains('new_levies'));
      expect(service.mockSubscribedTopics, contains('general'));
      expect(service.mockSubscribedTopics, contains('member_m1'));
      expect(service.mockSubscribedTopics, contains('payment_reminders'));
    });

    test('subscribes treasurer to correct topics', () async {
      final mock = _MockFirebaseMessaging();
      final service = _TestableNotificationService(mock);

      await service.subscribeToRoleTopics(UserRole.treasurer, 't1');

      expect(service.mockSubscribedTopics, contains('new_levies'));
      expect(service.mockSubscribedTopics, contains('general'));
      expect(service.mockSubscribedTopics, contains('pending_payments'));
      expect(service.mockSubscribedTopics, contains('payment_notifications'));
      expect(service.mockSubscribedTopics, contains('member_activity'));
    });

    test('unsubscribes from all topics', () async {
      final mock = _MockFirebaseMessaging();
      final service = _TestableNotificationService(mock);

      await service.subscribeToTopic('new_levies');
      await service.subscribeToTopic('general');
      await service.subscribeToTopic('member_m1');

      expect(service.mockSubscribedTopics.length, 3);

      await service.unsubscribeFromAllTopics();

      expect(service.mockSubscribedTopics, isEmpty);
    });
  });

  group('NotificationsScreen', () {
    Widget buildScreen({List<NotificationModel> notifications = const []}) {
      final mock = _MockFirebaseMessaging();
      final service = _TestableNotificationService(mock);

      return ProviderScope(
        overrides: [
          notificationServiceProvider.overrideWith((ref) => service),
          notificationListProvider.overrideWith((ref) {
            final notifier = NotificationListNotifier(service);
            for (final n in notifications) {
              notifier.addNotification(n);
            }
            return notifier;
          }),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 1200)),
            child: NotificationsScreen(currentUser: testUser),
          ),
        ),
      );
    }

    testWidgets('renders notification list', (tester) async {
      await tester.pumpWidget(buildScreen(notifications: testNotifications));
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('New Levy'), findsOneWidget);
      expect(find.text('Payment Approved'), findsOneWidget);
      expect(find.text('Reminder'), findsOneWidget);
    });

    testWidgets('shows empty state when no notifications', (tester) async {
      await tester.pumpWidget(buildScreen(notifications: const []));
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('No notifications yet'), findsOneWidget);
    });

    testWidgets('renders pending approval notification with action details', (tester) async {
      final pendingNotif = NotificationModel(
        id: 'p1',
        title: 'New Member Registration',
        body: 'Emeka Anya has registered and is awaiting approval.',
        type: 'pending_approval',
        payload: 'user_emeka_123',
        targetRole: 'president',
        organizationId: 'org_test',
        receivedAt: testDate,
        read: false,
      );

      await tester.pumpWidget(buildScreen(notifications: [pendingNotif]));
      await tester.pumpAndSettle();

      expect(find.text('New Member Registration'), findsOneWidget);
      expect(find.text('Emeka Anya has registered and is awaiting approval.'), findsOneWidget);
      expect(find.byIcon(Icons.person_add_alt_1), findsOneWidget);
    });
  });

  group('NotificationModel serialization', () {
    test('serializes and deserializes correctly with multi-tenancy and targeting', () {
      final model = NotificationModel(
        id: 'notif_123',
        title: 'Test Notification',
        body: 'Test Body',
        type: 'pending_approval',
        payload: 'uid_456',
        organizationId: 'org_123',
        targetRole: 'president',
        targetUserId: 'user_789',
        receivedAt: DateTime(2026, 7, 1, 10, 30),
        read: false,
      );

      final map = model.toMap();
      expect(map['id'], 'notif_123');
      expect(map['organizationId'], 'org_123');
      expect(map['targetRole'], 'president');
      expect(map['targetUserId'], 'user_789');

      final fromMap = NotificationModel.fromMap(map, 'notif_123');
      expect(fromMap.id, 'notif_123');
      expect(fromMap.organizationId, 'org_123');
      expect(fromMap.targetRole, 'president');
      expect(fromMap.targetUserId, 'user_789');
      expect(fromMap.type, 'pending_approval');
      expect(fromMap.read, false);
    });
  });
}
