import 'package:cloud_firestore/cloud_firestore.dart';

enum CallStatus {
  calling,
  active,
  ended,
  rejected,
  missed,
}

class CallSessionModel {
  final String id;
  final String organizationId;
  final String? branchId;
  final String callerId;
  final String callerName;
  final String callerRole;
  final String receiverId;
  final String receiverName;
  final String? receiverPhone;
  final CallStatus status;
  final String callType; // 'audio'
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? endedAt;

  const CallSessionModel({
    required this.id,
    required this.organizationId,
    this.branchId,
    required this.callerId,
    required this.callerName,
    required this.callerRole,
    required this.receiverId,
    required this.receiverName,
    this.receiverPhone,
    this.status = CallStatus.calling,
    this.callType = 'audio',
    required this.createdAt,
    this.updatedAt,
    this.endedAt,
  });

  factory CallSessionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final statusStr = data['status'] as String? ?? 'calling';
    final parsedStatus = CallStatus.values.firstWhere(
      (s) => s.name.toLowerCase() == statusStr.toLowerCase(),
      orElse: () => CallStatus.calling,
    );

    return CallSessionModel(
      id: doc.id,
      organizationId: data['organizationId'] as String? ?? '',
      branchId: data['branchId'] as String?,
      callerId: data['callerId'] as String? ?? '',
      callerName: data['callerName'] as String? ?? 'Member',
      callerRole: data['callerRole'] as String? ?? 'member',
      receiverId: data['receiverId'] as String? ?? '',
      receiverName: data['receiverName'] as String? ?? 'Member',
      receiverPhone: data['receiverPhone'] as String?,
      status: parsedStatus,
      callType: data['callType'] as String? ?? 'audio',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'organizationId': organizationId,
      if (branchId != null) 'branchId': branchId,
      'callerId': callerId,
      'callerName': callerName,
      'callerRole': callerRole,
      'receiverId': receiverId,
      'receiverName': receiverName,
      if (receiverPhone != null) 'receiverPhone': receiverPhone,
      'status': status.name,
      'callType': callType,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      if (endedAt != null) 'endedAt': Timestamp.fromDate(endedAt!),
    };
  }

  CallSessionModel copyWith({
    String? id,
    String? organizationId,
    String? branchId,
    String? callerId,
    String? callerName,
    String? callerRole,
    String? receiverId,
    String? receiverName,
    String? receiverPhone,
    CallStatus? status,
    String? callType,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? endedAt,
  }) {
    return CallSessionModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      branchId: branchId ?? this.branchId,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      callerRole: callerRole ?? this.callerRole,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      receiverPhone: receiverPhone ?? this.receiverPhone,
      status: status ?? this.status,
      callType: callType ?? this.callType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }
}

