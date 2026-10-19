import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/features/meetings/models/meeting_rsvp_model.dart';

void main() {
  group('MeetingRsvpModel Tests', () {
    final now = DateTime(2026, 10, 19, 10, 0);

    test('creates MeetingRsvpModel with all required AGENTS.md fields', () {
      final rsvp = MeetingRsvpModel(
        id: 'meet123_member456',
        organizationId: 'org_alpha',
        meetingId: 'meet123',
        memberId: 'member456',
        memberName: 'Emeka Okafor',
        status: MeetingRsvpStatus.excused,
        reason: 'Out of town for business trip',
        createdAt: now,
        updatedAt: now,
        createdBy: 'member456',
      );

      expect(rsvp.id, 'meet123_member456');
      expect(rsvp.organizationId, 'org_alpha');
      expect(rsvp.meetingId, 'meet123');
      expect(rsvp.memberId, 'member456');
      expect(rsvp.memberName, 'Emeka Okafor');
      expect(rsvp.status, MeetingRsvpStatus.excused);
      expect(rsvp.reason, 'Out of town for business trip');
      expect(rsvp.createdAt, now);
      expect(rsvp.updatedAt, now);
      expect(rsvp.createdBy, 'member456');
    });

    test('MeetingRsvpStatus display names match business terminology', () {
      expect(MeetingRsvpStatus.attending.displayName, 'Coming');
      expect(MeetingRsvpStatus.late.displayName, 'Coming Late');
      expect(MeetingRsvpStatus.excused.displayName, 'Not Coming (Excused)');
    });

    test('toFirestore serializes correctly', () {
      final rsvp = MeetingRsvpModel(
        id: 'meet1_mem1',
        organizationId: 'org_1',
        meetingId: 'meet1',
        memberId: 'mem1',
        memberName: 'Chioma Adeyemi',
        status: MeetingRsvpStatus.attending,
        reason: '',
        createdAt: now,
        updatedAt: now,
        createdBy: 'mem1',
      );

      final map = rsvp.toFirestore();
      expect(map['id'], 'meet1_mem1');
      expect(map['organizationId'], 'org_1');
      expect(map['meetingId'], 'meet1');
      expect(map['memberId'], 'mem1');
      expect(map['memberName'], 'Chioma Adeyemi');
      expect(map['status'], 'attending');
      expect(map['reason'], '');
      expect(map['createdBy'], 'mem1');
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['updatedAt'], isA<Timestamp>());
    });

    test('copyWith updates fields while preserving immutability', () {
      final rsvp = MeetingRsvpModel(
        id: 'meet1_mem1',
        organizationId: 'org_1',
        meetingId: 'meet1',
        memberId: 'mem1',
        memberName: 'Member 1',
        status: MeetingRsvpStatus.attending,
        reason: '',
        createdAt: now,
        updatedAt: now,
        createdBy: 'mem1',
      );

      final updated = rsvp.copyWith(
        status: MeetingRsvpStatus.excused,
        reason: 'Family emergency',
        updatedAt: DateTime(2026, 10, 19, 12, 0),
      );

      expect(updated.id, 'meet1_mem1');
      expect(updated.status, MeetingRsvpStatus.excused);
      expect(updated.reason, 'Family emergency');
      expect(updated.updatedAt, DateTime(2026, 10, 19, 12, 0));
      expect(rsvp.status, MeetingRsvpStatus.attending); // original unmodified
    });
  });
}
