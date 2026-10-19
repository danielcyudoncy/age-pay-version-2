import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/meetings/controllers/meeting_provider.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/secretary/controllers/secretary_dashboard_provider.dart';
import '../models/attendance_model.dart';
import '../repositories/attendance_repository.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository();
});

final attendanceControllerProvider = Provider<AttendanceController>((ref) {
  return AttendanceController(ref.watch(attendanceRepositoryProvider));
});

final selectedAttendanceYearProvider = StateProvider<int>((ref) {
  return DateTime.now().year;
});

final organizationAttendanceStreamProvider =
    StreamProvider.autoDispose.family<List<AttendanceModel>, String>((ref, orgId) {
  return ref.watch(attendanceRepositoryProvider).getAttendanceForOrganization(orgId);
});

final annualAttendanceStatsProvider =
    Provider<AsyncValue<AnnualAttendanceStats>>((ref) {
  final authState = ref.watch(authProvider);
  final user = authState.valueOrNull;
  if (user == null) {
    return const AsyncValue.loading();
  }
  final orgId = user.organizationId.isNotEmpty ? user.organizationId : user.uid;
  final year = ref.watch(selectedAttendanceYearProvider);
  final meetingsAsync = ref.watch(meetingsStreamProvider);
  final membersAsync = ref.watch(membersStreamProvider);
  final attendanceAsync =
      ref.watch(organizationAttendanceStreamProvider(orgId));

  if (meetingsAsync.isLoading ||
      membersAsync.isLoading ||
      attendanceAsync.isLoading) {
    return const AsyncValue.loading();
  }
  if (meetingsAsync.hasError) {
    return AsyncValue.error(meetingsAsync.error!, meetingsAsync.stackTrace!);
  }
  if (membersAsync.hasError) {
    return AsyncValue.error(membersAsync.error!, membersAsync.stackTrace!);
  }
  if (attendanceAsync.hasError) {
    return AsyncValue.error(attendanceAsync.error!, attendanceAsync.stackTrace!);
  }

  final meetings = meetingsAsync.value ?? [];
  final rawMembers = membersAsync.value ?? [];
  final members = rawMembers.whereType<MemberModel>().toList();
  final attendances = attendanceAsync.value ?? [];

  // Filter meetings for the selected year and sort chronologically
  final yearMeetings = meetings
      .where((m) => m.meetingDate.year == year)
      .toList()
    ..sort((a, b) => a.meetingDate.compareTo(b.meetingDate));

  final totalMeetingsHeld = yearMeetings.length;

  // Build a lookup map: meetingId -> memberId -> AttendanceModel
  final Map<String, Map<String, AttendanceModel>> attendanceLookup = {};
  for (final att in attendances) {
    attendanceLookup.putIfAbsent(att.meetingId, () => {})[att.memberId] = att;
  }

  final List<MemberAnnualAttendance> memberSummaries = [];
  int perfectCount = 0;
  int lowCount = 0;
  double sumRates = 0.0;

  for (final member in members) {
    int present = 0;
    int late = 0;
    int absent = 0;
    int excused = 0;
    final List<MeetingAttendanceRecord> records = [];

    for (final meeting in yearMeetings) {
      final att = attendanceLookup[meeting.id]?[member.id];
      final status = att?.status ?? AttendanceStatus.absent;

      switch (status) {
        case AttendanceStatus.present:
          present++;
          break;
        case AttendanceStatus.late:
          late++;
          break;
        case AttendanceStatus.absent:
          absent++;
          break;
        case AttendanceStatus.excused:
          excused++;
          break;
      }

      records.add(MeetingAttendanceRecord(
        meetingId: meeting.id,
        meetingTitle: meeting.title,
        meetingDate: meeting.meetingDate,
        status: status,
      ));
    }

    final summary = MemberAnnualAttendance(
      memberId: member.id,
      memberName: member.fullName,
      profilePhotoUrl: member.profilePhotoUrl,
      totalMeetings: totalMeetingsHeld,
      presentCount: present,
      lateCount: late,
      absentCount: absent,
      excusedCount: excused,
      records: records,
    );

    memberSummaries.add(summary);
    final rate = summary.attendanceRate;
    sumRates += rate;
    if (totalMeetingsHeld > 0 && rate >= 100.0) {
      perfectCount++;
    } else if (totalMeetingsHeld > 0 && rate < 50.0) {
      lowCount++;
    }
  }

  // Sort member summaries by attendance rate descending, then alphabetically by name
  memberSummaries.sort((a, b) {
    final cmp = b.attendanceRate.compareTo(a.attendanceRate);
    if (cmp != 0) return cmp;
    return a.memberName.compareTo(b.memberName);
  });

  final avgRate = members.isNotEmpty && totalMeetingsHeld > 0
      ? (sumRates / members.length)
      : 0.0;

  return AsyncValue.data(AnnualAttendanceStats(
    year: year,
    totalMeetingsHeld: totalMeetingsHeld,
    totalMembers: members.length,
    averageAttendanceRate: avgRate,
    perfectAttendanceCount: perfectCount,
    lowAttendanceCount: lowCount,
    memberSummaries: memberSummaries,
  ));
});

class AttendanceController {
  final AttendanceRepository _repository;
  AttendanceController(this._repository);

  Future<String> recordAttendance(AttendanceModel attendance) {
    return _repository.recordAttendance(attendance);
  }

  Future<void> updateAttendance(AttendanceModel attendance) {
    return _repository.updateAttendance(attendance);
  }

  Future<void> deleteAttendance(String id) {
    return _repository.deleteAttendance(id);
  }
}
