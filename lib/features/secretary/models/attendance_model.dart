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
  });

  factory AttendanceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
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
      recordedAt: (data['recordedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      recordedBy: data['recordedBy'] ?? '',
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
    );
  }
}
