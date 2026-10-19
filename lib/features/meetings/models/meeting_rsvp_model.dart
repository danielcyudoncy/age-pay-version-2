import 'package:cloud_firestore/cloud_firestore.dart';

enum MeetingRsvpStatus {
  attending,
  late,
  excused;

  String get displayName {
    switch (this) {
      case MeetingRsvpStatus.attending:
        return 'Coming';
      case MeetingRsvpStatus.late:
        return 'Coming Late';
      case MeetingRsvpStatus.excused:
        return 'Not Coming (Excused)';
    }
  }
}

class MeetingRsvpModel {
  final String id;
  final String organizationId;
  final String meetingId;
  final String memberId;
  final String memberName;
  final MeetingRsvpStatus status;
  final String reason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  const MeetingRsvpModel({
    required this.id,
    required this.organizationId,
    required this.meetingId,
    required this.memberId,
    required this.memberName,
    required this.status,
    this.reason = '',
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  factory MeetingRsvpModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final createdTimestamp = data['createdAt'] as Timestamp?;
    final updatedTimestamp = data['updatedAt'] as Timestamp?;

    final now = DateTime.now();

    return MeetingRsvpModel(
      id: doc.id,
      organizationId: data['organizationId'] as String? ?? '',
      meetingId: data['meetingId'] as String? ?? '',
      memberId: data['memberId'] as String? ?? '',
      memberName: data['memberName'] as String? ?? 'Member',
      status: MeetingRsvpStatus.values.firstWhere(
        (e) => e.name == (data['status'] as String? ?? 'attending'),
        orElse: () => MeetingRsvpStatus.attending,
      ),
      reason: data['reason'] as String? ?? '',
      createdAt: createdTimestamp != null ? createdTimestamp.toDate() : now,
      updatedAt: updatedTimestamp != null ? updatedTimestamp.toDate() : now,
      createdBy: data['createdBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'organizationId': organizationId,
      'meetingId': meetingId,
      'memberId': memberId,
      'memberName': memberName,
      'status': status.name,
      'reason': reason,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
    };
  }

  MeetingRsvpModel copyWith({
    String? id,
    String? organizationId,
    String? meetingId,
    String? memberId,
    String? memberName,
    MeetingRsvpStatus? status,
    String? reason,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return MeetingRsvpModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      meetingId: meetingId ?? this.meetingId,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
