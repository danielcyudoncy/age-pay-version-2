import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/notifications/models/notification_model.dart';
import 'package:cls/features/notifications/repositories/notification_repository.dart';
import 'package:cls/features/secretary/models/announcement_model.dart';

void main() {
  group('Executive Meeting Notification & Announcement Role Filtering', () {
    final repo = NotificationRepository();

    test('isNotificationForUser blocks ordinary members from executive notifications', () {
      final execNotif = NotificationModel(
        id: 'notif_1',
        title: 'Executive Meeting Scheduled',
        body: 'Details here',
        type: 'meeting',
        targetRole: 'executives',
        receivedAt: DateTime.now(),
      );

      // Ordinary member should NOT receive
      expect(
        repo.isNotificationForUser(execNotif, 'user_member', UserRole.member),
        isFalse,
      );

      // Executives should receive
      expect(
        repo.isNotificationForUser(execNotif, 'user_pres', UserRole.president),
        isTrue,
      );
      expect(
        repo.isNotificationForUser(execNotif, 'user_sec', UserRole.secretary),
        isTrue,
      );
      expect(
        repo.isNotificationForUser(execNotif, 'user_exec', UserRole.executiveMember),
        isTrue,
      );
      expect(
        repo.isNotificationForUser(execNotif, 'user_admin', UserRole.superAdmin),
        isTrue,
      );
    });

    test('isNotificationForUser allows ordinary members for general notifications', () {
      final generalNotif = NotificationModel(
        id: 'notif_2',
        title: 'General Meeting Scheduled',
        body: 'All members invited',
        type: 'meeting',
        targetRole: null,
        receivedAt: DateTime.now(),
      );

      expect(
        repo.isNotificationForUser(generalNotif, 'user_member', UserRole.member),
        isTrue,
      );
    });

    test('AnnouncementModel targetAudience and isExecutivesOnly work as intended', () {
      final now = DateTime(2026, 6, 1);
      final execAnnouncement = AnnouncementModel(
        id: 'ann_1',
        organizationId: 'org_1',
        title: 'Executive Meeting Notice',
        body: 'Confidential executive briefing',
        category: AnnouncementCategory.meeting,
        targetAudience: 'executives',
        createdBy: 'sec_1',
        createdAt: now,
        updatedAt: now,
      );

      final generalAnnouncement = AnnouncementModel(
        id: 'ann_2',
        organizationId: 'org_1',
        title: 'Monthly General Meeting',
        body: 'General meeting for all',
        category: AnnouncementCategory.meeting,
        targetAudience: 'all',
        createdBy: 'sec_1',
        createdAt: now,
        updatedAt: now,
      );

      expect(execAnnouncement.isExecutivesOnly, isTrue);
      expect(generalAnnouncement.isExecutivesOnly, isFalse);

      final firestoreMap = execAnnouncement.toFirestore();
      expect(firestoreMap['targetAudience'], equals('executives'));

      final list = [execAnnouncement, generalAnnouncement];
      final memberVisible = list.where((a) => !a.isExecutivesOnly).toList();
      expect(memberVisible.length, equals(1));
      expect(memberVisible.first.id, equals('ann_2'));
    });

    test('Legacy untagged executive meeting notification is blocked for ordinary members', () {
      final legacyNotif = NotificationModel(
        id: 'notif_legacy',
        title: 'Executive Meeting Scheduled: Budget Review',
        body: 'Executive officers session',
        type: 'meeting',
        targetRole: null, // Legacy notification had null targetRole
        receivedAt: DateTime.now(),
      );

      expect(
        repo.isNotificationForUser(legacyNotif, 'user_member', UserRole.member),
        isFalse,
      );
      expect(
        repo.isNotificationForUser(legacyNotif, 'user_pres', UserRole.president),
        isTrue,
      );
    });

    test('AnnouncementModel detects legacy executive meeting announcements without targetAudience', () {
      final now = DateTime(2026, 6, 1);
      final legacyAnnouncement = AnnouncementModel(
        id: 'ann_legacy',
        organizationId: 'org_1',
        title: '🏛️ Executive Meeting: Strategy 2026',
        body: 'An executive meeting session has been scheduled for all executive members.',
        category: AnnouncementCategory.meeting,
        targetAudience: 'all', // Missing/defaulted targetAudience
        createdBy: 'sec_1',
        createdAt: now,
        updatedAt: now,
      );

      expect(legacyAnnouncement.isExecutivesOnly, isTrue);
    });
  });
}
