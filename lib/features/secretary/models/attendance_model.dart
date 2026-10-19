import 'package:cloud_firestore/cloud_firestore.dart';

enum AttendanceStatus { present, absent, late, excused }

class AttendanceModel {
  final String id;
  final String organizationId;
  final String meetingId;
  final String memberId;
  final String memberName;
  final AttendanceStatus status;
  final DateTime? checkInTime;
  final String? notes;
  final DateTime recordedAt;
  final String recordedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AttendanceModel({
    required this.id,
    required this.organizationId,
    required this.meetingId,
    required this.memberId,
    required this.memberName,
    required this.status,
    this.checkInTime,
    this.notes,
    required this.recordedAt,
    required this.recordedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? recordedAt,
        updatedAt = updatedAt ?? recordedAt;

  factory AttendanceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final recAt = (data['recordedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    return AttendanceModel(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      meetingId: data['meetingId'] ?? '',
      memberId: data['memberId'] ?? '',
      memberName: data['memberName'] ?? '',
      status: AttendanceStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'absent'),
        orElse: () => AttendanceStatus.absent,
      ),
      checkInTime: data['checkInTime'] != null
          ? (data['checkInTime'] as Timestamp).toDate()
          : null,
      notes: data['notes'],
      recordedAt: recAt,
      recordedBy: data['recordedBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? recAt,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? recAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      'meetingId': meetingId,
      'memberId': memberId,
      'memberName': memberName,
      'status': status.name,
      'checkInTime': checkInTime != null ? Timestamp.fromDate(checkInTime!) : null,
      'notes': notes,
      'recordedAt': Timestamp.fromDate(recordedAt),
      'recordedBy': recordedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  AttendanceModel copyWith({
    String? id,
    String? organizationId,
    String? meetingId,
    String? memberId,
    String? memberName,
    AttendanceStatus? status,
    DateTime? checkInTime,
    String? notes,
    DateTime? recordedAt,
    String? recordedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AttendanceModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      meetingId: meetingId ?? this.meetingId,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      status: status ?? this.status,
      checkInTime: checkInTime ?? this.checkInTime,
      notes: notes ?? this.notes,
      recordedAt: recordedAt ?? this.recordedAt,
      recordedBy: recordedBy ?? this.recordedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class MeetingAttendanceRecord {
  final String meetingId;
  final String meetingTitle;
  final DateTime meetingDate;
  final AttendanceStatus status;

  const MeetingAttendanceRecord({
    required this.meetingId,
    required this.meetingTitle,
    required this.meetingDate,
    required this.status,
  });
}

class MemberAnnualAttendance {
  final String memberId;
  final String memberName;
  final String? profilePhotoUrl;
  final int totalMeetings;
  final int presentCount;
  final int lateCount;
  final int absentCount;
  final int excusedCount;
  final List<MeetingAttendanceRecord> records;

  const MemberAnnualAttendance({
    required this.memberId,
    required this.memberName,
    this.profilePhotoUrl,
    required this.totalMeetings,
    required this.presentCount,
    required this.lateCount,
    required this.absentCount,
    this.excusedCount = 0,
    required this.records,
  });

  int get attendedCount => presentCount + lateCount;

  double get attendanceRate {
    if (totalMeetings == 0) return 0.0;
    return (attendedCount / totalMeetings) * 100.0;
  }
}

class AnnualAttendanceStats {
  final int year;
  final int totalMeetingsHeld;
  final int totalMembers;
  final double averageAttendanceRate;
  final int perfectAttendanceCount;
  final int lowAttendanceCount;
  final List<MemberAnnualAttendance> memberSummaries;

  const AnnualAttendanceStats({
    required this.year,
    required this.totalMeetingsHeld,
    required this.totalMembers,
    required this.averageAttendanceRate,
    required this.perfectAttendanceCount,
    required this.lowAttendanceCount,
    required this.memberSummaries,
  });
}
