// test/helpers/notification_test_helper.dart
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationTestHelper {
  static RemoteMessage simulateNotification({
    String? type,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    String? messageId,
  }) {
    return RemoteMessage(
      messageId:
          messageId ?? 'test-msg-${DateTime.now().millisecondsSinceEpoch}',
      notification: RemoteNotification(
        title: title ?? 'Test Title',
        body: body ?? 'Test Body',
      ),
      data: {'type': ?type, ...?data},
    );
  }
}
