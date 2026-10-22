import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/enums.dart';

class ObligationModel {
  final String id;
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

  const ObligationModel({
    required this.id,
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
  });

  factory ObligationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final totalAmount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final paidAmount = (data['paidAmount'] as num?)?.toDouble() ?? 0.0;
    final status = ObligationStatus.values.firstWhere(
      (e) => e.name == (data['status'] ?? 'unpaid'),
      orElse: () => ObligationStatus.unpaid,
    );
    final rawOutstanding = (data['outstandingBalance'] as num?)?.toDouble();
    final calculatedOutstanding =
        (totalAmount - paidAmount).clamp(0.0, double.infinity);
    final outstandingBalance =
        (status == ObligationStatus.paid || paidAmount >= totalAmount)
            ? 0.0
            : (rawOutstanding != null && rawOutstanding <= calculatedOutstanding
                ? rawOutstanding
                : calculatedOutstanding);

    return ObligationModel(
      id: doc.id,
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
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'memberId': memberId,
      'levyId': levyId,
      'type': type.name,
      'title': title,
      'description': description,
      'amount': amount,
      'paidAmount': paidAmount,
      'outstandingBalance': outstandingBalance,
      'status': status.name,
      'dueDate': Timestamp.fromDate(dueDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'settledAt': settledAt != null ? Timestamp.fromDate(settledAt!) : null,
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  ObligationModel copyWith({
    String? id,
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
  }) {
    final newStatus = status ?? this.status;
    final newPaid = paidAmount ?? this.paidAmount;
    final newAmount = amount ?? this.amount;
    final resolvedOutstanding = outstandingBalance ??
        ((newStatus == ObligationStatus.paid || newPaid >= newAmount)
            ? 0.0
            : this.outstandingBalance);

    return ObligationModel(
      id: id ?? this.id,
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
    );
  }
}
