import 'package:flutter_test/flutter_test.dart';
import 'package:cls/features/secretary/models/attendance_model.dart';

void main() {
  group('AttendanceModel Tests', () {
    final now = DateTime(2026, 3, 15);

    test('AttendanceModel initializes correctly and copyWith works', () {
      final model = AttendanceModel(
        id: 'att_1',
        organizationId: 'org_1',
        meetingId: 'meet_1',
        memberId: 'mem_1',
        memberName: 'Emeka Okafor',
        status: AttendanceStatus.present,
        recordedAt: now,
        recordedBy: 'sec_1',
      );

      expect(model.id, 'att_1');
      expect(model.status, AttendanceStatus.present);
      expect(model.createdAt, now);
      expect(model.updatedAt, now);

      final updated = model.copyWith(status: AttendanceStatus.late);
      expect(updated.status, AttendanceStatus.late);
      expect(updated.id, 'att_1');
    });

    test('toFirestore returns valid map', () {
      final model = AttendanceModel(
        id: 'att_2',
        organizationId: 'org_1',
        meetingId: 'meet_1',
        memberId: 'mem_2',
        memberName: 'Chidi Nwosu',
        status: AttendanceStatus.absent,
        recordedAt: now,
        recordedBy: 'sec_1',
      );

      final map = model.toFirestore();
      expect(map['organizationId'], 'org_1');
      expect(map['meetingId'], 'meet_1');
      expect(map['memberId'], 'mem_2');
      expect(map['status'], 'absent');
      expect(map['recordedBy'], 'sec_1');
    });
  });

  group('MemberAnnualAttendance Calculation Tests', () {
    test('Calculates attendanceRate correctly with mixed statuses', () {
      final now = DateTime(2026, 1, 10);
      final records = [
        MeetingAttendanceRecord(
          meetingId: 'm1',
          meetingTitle: 'January Meeting',
          meetingDate: now,
          status: AttendanceStatus.present,
        ),
        MeetingAttendanceRecord(
          meetingId: 'm2',
          meetingTitle: 'February Meeting',
          meetingDate: now.add(const Duration(days: 30)),
          status: AttendanceStatus.late,
        ),
        MeetingAttendanceRecord(
          meetingId: 'm3',
          meetingTitle: 'March Meeting',
          meetingDate: now.add(const Duration(days: 60)),
          status: AttendanceStatus.absent,
        ),
        MeetingAttendanceRecord(
          meetingId: 'm4',
          meetingTitle: 'April Meeting',
          meetingDate: now.add(const Duration(days: 90)),
          status: AttendanceStatus.present,
        ),
      ];

      final summary = MemberAnnualAttendance(
        memberId: 'mem_1',
        memberName: 'Tunde Bakare',
        totalMeetings: 4,
        presentCount: 2,
        lateCount: 1,
        absentCount: 1,
        records: records,
      );

      expect(summary.attendedCount, 3); // 2 present + 1 late
      expect(summary.totalMeetings, 4);
      expect(summary.attendanceRate, 75.0); // 3 / 4 * 100 = 75%
    });

    test('Calculates 0% attendanceRate when totalMeetings is 0', () {
      const summary = MemberAnnualAttendance(
        memberId: 'mem_2',
        memberName: 'New Member',
        totalMeetings: 0,
        presentCount: 0,
        lateCount: 0,
        absentCount: 0,
        records: [],
      );

      expect(summary.attendedCount, 0);
      expect(summary.attendanceRate, 0.0);
    });

    test('Calculates 100% attendanceRate for perfect attendance', () {
      final now = DateTime(2026, 1, 10);
      final records = List.generate(
        10,
        (i) => MeetingAttendanceRecord(
          meetingId: 'm_$i',
          meetingTitle: 'Meeting $i',
          meetingDate: now.add(Duration(days: i * 30)),
          status: AttendanceStatus.present,
        ),
      );

      final summary = MemberAnnualAttendance(
        memberId: 'mem_3',
        memberName: 'Amaka Eze',
        totalMeetings: 10,
        presentCount: 10,
        lateCount: 0,
        absentCount: 0,
        records: records,
      );

      expect(summary.attendedCount, 10);
      expect(summary.attendanceRate, 100.0);
    });
  });

  group('AnnualAttendanceStats Tests', () {
    test('Constructs stats object accurately', () {
      const stats = AnnualAttendanceStats(
        year: 2026,
        totalMeetingsHeld: 12,
        totalMembers: 50,
        averageAttendanceRate: 84.5,
        perfectAttendanceCount: 15,
        lowAttendanceCount: 3,
        memberSummaries: [],
      );

      expect(stats.year, 2026);
      expect(stats.totalMeetingsHeld, 12);
      expect(stats.totalMembers, 50);
      expect(stats.averageAttendanceRate, 84.5);
      expect(stats.perfectAttendanceCount, 15);
      expect(stats.lowAttendanceCount, 3);
    });
  });
}
