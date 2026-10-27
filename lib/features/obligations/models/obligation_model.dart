import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/enums.dart';

class ObligationModel {
  final String id;
  final String organizationId;
  final String memberId;
  final String levyId;
  final ObligationType type;
  final String title;
  final String description;
  final double amount;
  final double paidAmount;
  final double outstandingBalance;
  final ObligationStatus status;
  final DateTime dueDate;
  final DateTime createdAt;
  final DateTime? settledAt;
  final String? meetingId;
  final PenaltyInfractionType? infractionType;
  final bool isWaived;
  final String? waiverReason;
  final String? waivedBy;
  final DateTime? waivedAt;
  final PenaltyWaiverStatus? waiverStatus;
  final String scope; // 'national' | 'branch'
  final String? branchId;

  const ObligationModel({
    required this.id,
    this.organizationId = '',
    required this.memberId,
    required this.levyId,
    required this.type,
    required this.title,
    required this.description,
    required this.amount,
    this.paidAmount = 0.0,
    this.outstandingBalance = 0.0,
    this.status = ObligationStatus.unpaid,
    required this.dueDate,
    required this.createdAt,
    this.settledAt,
    this.meetingId,
    this.infractionType,
    this.isWaived = false,
    this.waiverReason,
    this.waivedBy,
    this.waivedAt,
    this.waiverStatus,
    this.scope = 'branch',
    this.branchId,
  });

  bool get isPaid => status == ObligationStatus.paid || outstandingBalance <= 0;

  factory ObligationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final totalAmount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final paidAmount = (data['paidAmount'] as num?)?.toDouble() ?? 0.0;
    final isWaived = data['isWaived'] == true;
    final status = ObligationStatus.values.firstWhere(
      (e) => e.name == (data['status'] ?? 'unpaid'),
      orElse: () => ObligationStatus.unpaid,
    );
    final rawOutstanding = (data['outstandingBalance'] as num?)?.toDouble();
    final calculatedOutstanding =
        (totalAmount - paidAmount).clamp(0.0, double.infinity);
    final outstandingBalance =
        (isWaived || status == ObligationStatus.paid || paidAmount >= totalAmount)
            ? 0.0
            : (rawOutstanding != null && rawOutstanding <= calculatedOutstanding
                ? rawOutstanding
                : calculatedOutstanding);

    final infractionStr = data['infractionType'] as String?;
    final PenaltyInfractionType? infractionType = infractionStr != null
        ? PenaltyInfractionType.values.firstWhere(
            (e) => e.name == infractionStr,
            orElse: () => PenaltyInfractionType.custom,
          )
        : null;

    final waiverStatusStr = data['waiverStatus'] as String?;
    final PenaltyWaiverStatus? waiverStatus = waiverStatusStr != null
        ? PenaltyWaiverStatus.values.firstWhere(
            (e) => e.name == waiverStatusStr,
            orElse: () => PenaltyWaiverStatus.pendingApproval,
          )
        : null;

    return ObligationModel(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      memberId: data['memberId'] ?? '',
      levyId: data['levyId'] ?? '',
      type: ObligationType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'monthlyDue'),
        orElse: () => ObligationType.monthlyDue,
      ),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      amount: totalAmount,
      paidAmount: paidAmount,
      outstandingBalance: outstandingBalance,
      status: status,
      dueDate: _parseDate(data['dueDate']),
      createdAt: _parseDate(data['createdAt']),
      settledAt: data['settledAt'] != null
          ? _parseDate(data['settledAt'])
          : null,
      meetingId: data['meetingId'] as String?,
      infractionType: infractionType,
      isWaived: isWaived,
      waiverReason: data['waiverReason'] as String?,
      waivedBy: data['waivedBy'] as String?,
      waivedAt: data['waivedAt'] != null ? _parseDate(data['waivedAt']) : null,
      waiverStatus: waiverStatus,
      scope: data['scope'] ?? 'branch',
      branchId: data['branchId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      'memberId': memberId,
      'levyId': levyId,
      'type': type.name,
      'title': title,
      'description': description,
      'amount': amount,
      'paidAmount': paidAmount,
      'outstandingBalance': isWaived ? 0.0 : outstandingBalance,
      'status': status.name,
      'dueDate': Timestamp.fromDate(dueDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'settledAt': settledAt != null ? Timestamp.fromDate(settledAt!) : null,
      'meetingId': meetingId,
      'infractionType': infractionType?.name,
      'isWaived': isWaived,
      'waiverReason': waiverReason,
      'waivedBy': waivedBy,
      'waivedAt': waivedAt != null ? Timestamp.fromDate(waivedAt!) : null,
      'waiverStatus': waiverStatus?.name,
      'scope': scope,
      if (branchId != null) 'branchId': branchId,
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  ObligationModel copyWith({
    String? id,
    String? organizationId,
    String? memberId,
    String? levyId,
    ObligationType? type,
    String? title,
    String? description,
    double? amount,
    double? paidAmount,
    double? outstandingBalance,
    ObligationStatus? status,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? settledAt,
    String? meetingId,
    PenaltyInfractionType? infractionType,
    bool? isWaived,
    String? waiverReason,
    String? waivedBy,
    DateTime? waivedAt,
    PenaltyWaiverStatus? waiverStatus,
    String? scope,
    String? branchId,
  }) {
    final newStatus = status ?? this.status;
    final newPaid = paidAmount ?? this.paidAmount;
    final newAmount = amount ?? this.amount;
    final newWaived = isWaived ?? this.isWaived;
    final resolvedOutstanding = outstandingBalance ??
        ((newWaived || newStatus == ObligationStatus.paid || newPaid >= newAmount)
            ? 0.0
            : this.outstandingBalance);

    return ObligationModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      memberId: memberId ?? this.memberId,
      levyId: levyId ?? this.levyId,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: newAmount,
      paidAmount: newPaid,
      outstandingBalance: resolvedOutstanding,
      status: newStatus,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      settledAt: settledAt ?? this.settledAt,
      meetingId: meetingId ?? this.meetingId,
      infractionType: infractionType ?? this.infractionType,
      isWaived: newWaived,
      waiverReason: waiverReason ?? this.waiverReason,
      waivedBy: waivedBy ?? this.waivedBy,
      waivedAt: waivedAt ?? this.waivedAt,
      waiverStatus: waiverStatus ?? this.waiverStatus,
      scope: scope ?? this.scope,
      branchId: branchId ?? this.branchId,
    );
  }
}
