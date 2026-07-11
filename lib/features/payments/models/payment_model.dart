import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/enums.dart';

class PaymentAllocationModel {
  final String obligationId;
  final double amount;

  const PaymentAllocationModel({
    required this.obligationId,
    required this.amount,
  });

  factory PaymentAllocationModel.fromMap(Map<String, dynamic> map) {
    return PaymentAllocationModel(
      obligationId: map['obligationId'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {'obligationId': obligationId, 'amount': amount};
  }
}

class PaymentModel {
  final String id;
  final String memberId;
  final double amount;
  final PaymentMethod method;
  final PaymentStatus status;
  final List<PaymentAllocationModel> allocations;
  final String? receiptUrl;
  final String? transferProofUrl;
  final String? paystackReference;
  final String? notes;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final DateTime createdAt;

  const PaymentModel({
    required this.id,
    required this.memberId,
    required this.amount,
    required this.method,
    this.status = PaymentStatus.pending,
    required this.allocations,
    this.receiptUrl,
    this.transferProofUrl,
    this.paystackReference,
    this.notes,
    this.verifiedBy,
    this.verifiedAt,
    required this.createdAt,
  });

  factory PaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentModel(
      id: doc.id,
      memberId: data['memberId'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      method: PaymentMethod.values.firstWhere(
        (e) => e.name == (data['method'] ?? 'cash'),
        orElse: () => PaymentMethod.cash,
      ),
      status: PaymentStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'pending'),
        orElse: () => PaymentStatus.pending,
      ),
      allocations: ((data['allocations'] ?? []) as List)
          .map((a) => PaymentAllocationModel.fromMap(a as Map<String, dynamic>))
          .toList(),
      receiptUrl: data['receiptUrl'],
      transferProofUrl: data['transferProofUrl'],
      paystackReference: data['paystackReference'],
      notes: data['notes'],
      verifiedBy: data['verifiedBy'],
      verifiedAt: data['verifiedAt'] != null
          ? _parseDate(data['verifiedAt'])
          : null,
      createdAt: _parseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'memberId': memberId,
      'amount': amount,
      'method': method.name,
      'status': status.name,
      'allocations': allocations.map((a) => a.toMap()).toList(),
      'receiptUrl': receiptUrl,
      'transferProofUrl': transferProofUrl,
      'paystackReference': paystackReference,
      'notes': notes,
      'verifiedBy': verifiedBy,
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  PaymentModel copyWith({
    String? id,
    String? memberId,
    double? amount,
    PaymentMethod? method,
    PaymentStatus? status,
    List<PaymentAllocationModel>? allocations,
    String? receiptUrl,
    String? transferProofUrl,
    String? paystackReference,
    String? notes,
    String? verifiedBy,
    DateTime? verifiedAt,
    DateTime? createdAt,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      memberId: memberId ?? this.memberId,
      amount: amount ?? this.amount,
      method: method ?? this.method,
      status: status ?? this.status,
      allocations: allocations ?? this.allocations,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      transferProofUrl: transferProofUrl ?? this.transferProofUrl,
      paystackReference: paystackReference ?? this.paystackReference,
      notes: notes ?? this.notes,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
