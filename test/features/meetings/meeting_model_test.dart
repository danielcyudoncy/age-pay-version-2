import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/meetings/models/meeting_model.dart';

void main() {
  group('MeetingModel', () {
    final now = DateTime(2026, 10, 22, 10, 0);

    test('defaults targetAudience to "all"', () {
      final meeting = MeetingModel(
        id: 'meet-1',
        title: 'General Assembly',
        venue: 'Town Hall',
        meetingDate: now,
        createdAt: now,
        updatedAt: now,
        createdBy: 'user-1',
      );

      expect(meeting.targetAudience, 'all');
      expect(meeting.isExecutivesOnly, false);
      expect(meeting.hasMinutes, false);
    });

    test('isExecutivesOnly returns true when targetAudience is "executives"', () {
      final meeting = MeetingModel(
        id: 'meet-2',
        title: 'Executive Committee Meeting',
        venue: 'Board Room',
        meetingDate: now,
        createdAt: now,
        updatedAt: now,
        createdBy: 'pres-1',
        targetAudience: 'executives',
      );

      expect(meeting.targetAudience, 'executives');
      expect(meeting.isExecutivesOnly, true);
    });

    test('toFirestore includes targetAudience', () {
      final meeting = MeetingModel(
        id: 'meet-3',
        organizationId: 'org-1',
        title: 'Budget Review',
        venue: 'Online',
        meetingDate: now,
        createdAt: now,
        updatedAt: now,
        createdBy: 'user-1',
        targetAudience: 'executives',
      );

      final map = meeting.toFirestore();
      expect(map['organizationId'], 'org-1');
      expect(map['title'], 'Budget Review');
      expect(map['venue'], 'Online');
      expect(map['targetAudience'], 'executives');
      expect(map['meetingDate'], isA<Timestamp>());
    });

    test('copyWith updates targetAudience properly', () {
      final meeting = MeetingModel(
        id: 'meet-4',
        title: 'All Hands',
        venue: 'Main Hall',
        meetingDate: now,
        createdAt: now,
        updatedAt: now,
        createdBy: 'user-1',
      );

      expect(meeting.isExecutivesOnly, false);

      final updated = meeting.copyWith(targetAudience: 'executives');
      expect(updated.targetAudience, 'executives');
      expect(updated.isExecutivesOnly, true);
      expect(updated.title, 'All Hands');
    });
  });

  group('UserRole & UserModel isExecutive', () {
    test('non-executive role returns isExecutive = false', () {
      expect(UserRole.member.isExecutive, false);

      final memberUser = UserModel(
        uid: 'u1',
        organizationId: 'org1',
        email: 'member@test.com',
        displayName: 'John Doe',
        phoneNumber: '+1234567890',
        role: UserRole.member,
        createdAt: DateTime.now(),
      );
      expect(memberUser.isExecutive, false);
    });

    test('executive roles return isExecutive = true', () {
      expect(UserRole.president.isExecutive, true);
      expect(UserRole.vicePresident.isExecutive, true);
      expect(UserRole.secretary.isExecutive, true);
      expect(UserRole.viceSecretary.isExecutive, true);
      expect(UserRole.treasurer.isExecutive, true);
      expect(UserRole.financialSecretary.isExecutive, true);
      expect(UserRole.superAdmin.isExecutive, true);

      final presUser = UserModel(
        uid: 'u2',
        organizationId: 'org1',
        email: 'pres@test.com',
        displayName: 'Jane President',
        phoneNumber: '+1234567891',
        role: UserRole.president,
        createdAt: DateTime.now(),
      );
      expect(presUser.isExecutive, true);
    });
  });
}
