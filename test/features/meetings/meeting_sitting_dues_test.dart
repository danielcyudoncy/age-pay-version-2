import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/meetings/models/meeting_model.dart';
import 'package:cls/features/payments/models/payment_model.dart';

void main() {
  group('MeetingModel Sitting Dues', () {
    final meetingTime = DateTime(2026, 11, 15, 12, 45);
    final now = DateTime(2026, 11, 15, 10, 0);

    test('defaults sittingDuesAmount to 0.0 and hasSittingDues to false', () {
      final meeting = MeetingModel(
        id: 'meet-1',
        title: 'Monthly Sitting',
        venue: 'Town Hall',
        meetingDate: meetingTime,
        createdAt: now,
        updatedAt: now,
        createdBy: 'user-1',
      );

      expect(meeting.sittingDuesAmount, 0.0);
      expect(meeting.hasSittingDues, false);
      expect(meeting.isSittingDuesWindowOpen(meetingTime), false);
    });

    test('sittingDuesAmount > 0 enables sitting dues and defines window', () {
      final meeting = MeetingModel(
        id: 'meet-2',
        title: 'Monthly Sitting with Dues',
        venue: 'Town Hall',
        meetingDate: meetingTime, // 12:45 PM
        createdAt: now,
        updatedAt: now,
        createdBy: 'user-1',
        sittingDuesAmount: 2000.0,
      );

      expect(meeting.sittingDuesAmount, 2000.0);
      expect(meeting.hasSittingDues, true);

      // Open time is 10 minutes before: 12:35 PM
      expect(meeting.sittingDuesOpenTime, DateTime(2026, 11, 15, 12, 35));
      // Close time is end of day 23:59:59
      expect(meeting.sittingDuesCloseTime, DateTime(2026, 11, 15, 23, 59, 59));

      // Before 12:35 PM -> Upcoming
      final at1230 = DateTime(2026, 11, 15, 12, 30);
      expect(meeting.isSittingDuesUpcoming(at1230), true);
      expect(meeting.isSittingDuesWindowOpen(at1230), false);
      expect(meeting.isSittingDuesClosed(at1230), false);

      // Exactly at 12:35 PM -> Open
      final at1235 = DateTime(2026, 11, 15, 12, 35);
      expect(meeting.isSittingDuesUpcoming(at1235), false);
      expect(meeting.isSittingDuesWindowOpen(at1235), true);
      expect(meeting.isSittingDuesClosed(at1235), false);

      // During meeting at 1:15 PM -> Open
      final at1315 = DateTime(2026, 11, 15, 13, 15);
      expect(meeting.isSittingDuesWindowOpen(at1315), true);

      // Late evening 11:30 PM -> Open
      final at2330 = DateTime(2026, 11, 15, 23, 30);
      expect(meeting.isSittingDuesWindowOpen(at2330), true);
      expect(meeting.isSittingDuesClosed(at2330), false);

      // Next day 00:01 AM -> Closed
      final nextDay = DateTime(2026, 11, 16, 0, 1);
      expect(meeting.isSittingDuesUpcoming(nextDay), false);
      expect(meeting.isSittingDuesWindowOpen(nextDay), false);
      expect(meeting.isSittingDuesClosed(nextDay), true);
    });

    test('toFirestore serializes sittingDuesAmount correctly', () {
      final meeting = MeetingModel(
        id: 'meet-3',
        organizationId: 'org-1',
        title: 'AGM Sitting',
        venue: 'Main Hall',
        meetingDate: meetingTime,
        createdAt: now,
        updatedAt: now,
        createdBy: 'sec-1',
        sittingDuesAmount: 3500.0,
      );

      final map = meeting.toFirestore();
      expect(map['sittingDuesAmount'], 3500.0);
    });

    test('copyWith updates sittingDuesAmount properly', () {
      final meeting = MeetingModel(
        id: 'meet-4',
        title: 'Meeting',
        venue: 'Hall',
        meetingDate: meetingTime,
        createdAt: now,
        updatedAt: now,
        createdBy: 'user-1',
      );

      expect(meeting.sittingDuesAmount, 0.0);
      final updated = meeting.copyWith(sittingDuesAmount: 1500.0);
      expect(updated.sittingDuesAmount, 1500.0);
      expect(updated.hasSittingDues, true);
    });
  });

  group('PaymentModel meetingId integration', () {
    test('serializes and deserializes meetingId correctly', () {
      final payment = PaymentModel(
        id: 'pay-1',
        memberId: 'mem-1',
        amount: 2000.0,
        method: PaymentMethod.cash,
        status: PaymentStatus.approved,
        allocations: const [
          PaymentAllocationModel(obligationId: 'ob-1', amount: 2000.0),
        ],
        notes: 'Sitting Dues: November Sitting',
        meetingId: 'meet-123',
        createdAt: DateTime(2026, 11, 15, 12, 40),
      );

      expect(payment.meetingId, 'meet-123');
      final map = payment.toFirestore();
      expect(map['meetingId'], 'meet-123');

      final updated = payment.copyWith(meetingId: 'meet-456');
      expect(updated.meetingId, 'meet-456');
    });
  });
}
