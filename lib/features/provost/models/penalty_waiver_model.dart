import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/enums.dart';

class PenaltyWaiverModel {
  final String id;
  final String organizationId;
  final String obligationId;
  final String memberId;
  final String memberName;
  final String penaltyTitle;
  final double amount;
  final PenaltyInfractionType infractionType;
  final String reason;
  final String requestedBy;
  final DateTime requestedAt;
  final PenaltyWaiverStatus status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? rejectionReason;

  const PenaltyWaiverModel({
    required this.id,
    required this.organizationId,
    required this.obligationId,
    required this.memberId,
    required this.memberName,
    required this.penaltyTitle,
    required this.amount,
    required this.infractionType,
    required this.reason,
    required this.requestedBy,
    required this.requestedAt,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
  });

  factory PenaltyWaiverModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final infractionStr = data['infractionType'] as String? ?? 'custom';
    final infraction = PenaltyInfractionType.values.firstWhere(
      (e) => e.name.toLowerCase() == infractionStr.toLowerCase(),
      orElse: () => PenaltyInfractionType.custom,
    );

    final statusStr = data['status'] as String? ?? 'pendingApproval';
    final status = PenaltyWaiverStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == statusStr.toLowerCase(),
      orElse: () => PenaltyWaiverStatus.pendingApproval,
    );

    return PenaltyWaiverModel(
      id: doc.id,
      organizationId: data['organizationId'] as String? ?? '',
      obligationId: data['obligationId'] as String? ?? '',
      memberId: data['memberId'] as String? ?? '',
      memberName: data['memberName'] as String? ?? '',
      penaltyTitle: data['penaltyTitle'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      infractionType: infraction,
      reason: data['reason'] as String? ?? '',
      requestedBy: data['requestedBy'] as String? ?? '',
      requestedAt: _parseDate(data['requestedAt']),
      status: status,
      reviewedBy: data['reviewedBy'] as String?,
      reviewedAt: data['reviewedAt'] != null ? _parseDate(data['reviewedAt']) : null,
      rejectionReason: data['rejectionReason'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      'obligationId': obligationId,
      'memberId': memberId,
      'memberName': memberName,
      'penaltyTitle': penaltyTitle,
      'amount': amount,
      'infractionType': infractionType.name,
      'reason': reason,
      'requestedBy': requestedBy,
      'requestedAt': Timestamp.fromDate(requestedAt),
      'status': status.name,
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
    };
  }

  PenaltyWaiverModel copyWith({
    String? id,
    String? organizationId,
    String? obligationId,
    String? memberId,
    String? memberName,
    String? penaltyTitle,
    double? amount,
    PenaltyInfractionType? infractionType,
    String? reason,
    String? requestedBy,
    DateTime? requestedAt,
    PenaltyWaiverStatus? status,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? rejectionReason,
  }) {
    return PenaltyWaiverModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      obligationId: obligationId ?? this.obligationId,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      penaltyTitle: penaltyTitle ?? this.penaltyTitle,
      amount: amount ?? this.amount,
      infractionType: infractionType ?? this.infractionType,
      reason: reason ?? this.reason,
      requestedBy: requestedBy ?? this.requestedBy,
      requestedAt: requestedAt ?? this.requestedAt,
      status: status ?? this.status,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
