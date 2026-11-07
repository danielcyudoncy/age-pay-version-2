import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/enums.dart';

class CashHandoverModel {
  final String id;
  final String organizationId;
  final String? branchId;
  final double amount;
  final String handedOverBy;
  final String handedOverById;
  final DateTime handedOverAt;
  final String? receivedBy;
  final String? receivedById;
  final DateTime? acknowledgedAt;
  final CashHandoverStatus status;
  final String? bankName;
  final String? bankAccountNumber;
  final String? depositSlipUrl;
  final String? notes;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CashHandoverModel({
    required this.id,
    required this.organizationId,
    this.branchId,
    required this.amount,
    required this.handedOverBy,
    required this.handedOverById,
    required this.handedOverAt,
    this.receivedBy,
    this.receivedById,
    this.acknowledgedAt,
    this.status = CashHandoverStatus.pending,
    this.bankName,
    this.bankAccountNumber,
    this.depositSlipUrl,
    this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CashHandoverModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final statusStr = data['status'] as String?;
    final CashHandoverStatus parsedStatus = CashHandoverStatus.values.firstWhere(
      (s) => s.name.toLowerCase() == (statusStr ?? '').toLowerCase(),
      orElse: () => CashHandoverStatus.pending,
    );

    return CashHandoverModel(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      branchId: data['branchId'] as String?,
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      handedOverBy: data['handedOverBy'] ?? '',
      handedOverById: data['handedOverById'] ?? '',
      handedOverAt: _parseDate(data['handedOverAt']),
      receivedBy: data['receivedBy'] as String?,
      receivedById: data['receivedById'] as String?,
      acknowledgedAt: data['acknowledgedAt'] != null
          ? _parseDate(data['acknowledgedAt'])
          : null,
      status: parsedStatus,
      bankName: data['bankName'] as String?,
      bankAccountNumber: data['bankAccountNumber'] as String?,
      depositSlipUrl: data['depositSlipUrl'] as String?,
      notes: data['notes'] as String?,
      createdBy: data['createdBy'] ?? '',
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      if (branchId != null) 'branchId': branchId,
      'amount': amount,
      'handedOverBy': handedOverBy,
      'handedOverById': handedOverById,
      'handedOverAt': Timestamp.fromDate(handedOverAt),
      if (receivedBy != null) 'receivedBy': receivedBy,
      if (receivedById != null) 'receivedById': receivedById,
      if (acknowledgedAt != null)
        'acknowledgedAt': Timestamp.fromDate(acknowledgedAt!),
      'status': status.name,
      if (bankName != null) 'bankName': bankName,
      if (bankAccountNumber != null) 'bankAccountNumber': bankAccountNumber,
      if (depositSlipUrl != null) 'depositSlipUrl': depositSlipUrl,
      if (notes != null) 'notes': notes,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  CashHandoverModel copyWith({
    String? id,
    String? organizationId,
    String? branchId,
    double? amount,
    String? handedOverBy,
    String? handedOverById,
    DateTime? handedOverAt,
    String? receivedBy,
    String? receivedById,
    DateTime? acknowledgedAt,
    CashHandoverStatus? status,
    String? bankName,
    String? bankAccountNumber,
    String? depositSlipUrl,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CashHandoverModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      branchId: branchId ?? this.branchId,
      amount: amount ?? this.amount,
      handedOverBy: handedOverBy ?? this.handedOverBy,
      handedOverById: handedOverById ?? this.handedOverById,
      handedOverAt: handedOverAt ?? this.handedOverAt,
      receivedBy: receivedBy ?? this.receivedBy,
      receivedById: receivedById ?? this.receivedById,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      status: status ?? this.status,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      depositSlipUrl: depositSlipUrl ?? this.depositSlipUrl,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
