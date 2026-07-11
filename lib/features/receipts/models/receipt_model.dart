import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/enums.dart';

class ReceiptModel {
  final String id;
  final String receiptNumber;
  final String paymentId;
  final String memberId;
  final String memberName;
  final double amount;
  final PaymentMethod method;
  final DateTime paymentDate;
  final List<Map<String, dynamic>> allocatedObligations;
  final String? pdfUrl;
  final DateTime createdAt;

  const ReceiptModel({
    required this.id,
    required this.receiptNumber,
    required this.paymentId,
    required this.memberId,
    required this.memberName,
    required this.amount,
    required this.method,
    required this.paymentDate,
    required this.allocatedObligations,
    this.pdfUrl,
    required this.createdAt,
  });

  factory ReceiptModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReceiptModel(
      id: doc.id,
      receiptNumber: data['receiptNumber'] ?? '',
      paymentId: data['paymentId'] ?? '',
      memberId: data['memberId'] ?? '',
      memberName: data['memberName'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      method: PaymentMethod.values.firstWhere(
        (e) => e.name == (data['method'] ?? 'cash'),
        orElse: () => PaymentMethod.cash,
      ),
      paymentDate: _parseDate(data['paymentDate']),
      allocatedObligations: List<Map<String, dynamic>>.from(
        data['allocatedObligations'] ?? [],
      ),
      pdfUrl: data['pdfUrl'],
      createdAt: _parseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'receiptNumber': receiptNumber,
      'paymentId': paymentId,
      'memberId': memberId,
      'memberName': memberName,
      'amount': amount,
      'method': method.name,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'allocatedObligations': allocatedObligations,
      'pdfUrl': pdfUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  ReceiptModel copyWith({
    String? id,
    String? receiptNumber,
    String? paymentId,
    String? memberId,
    String? memberName,
    double? amount,
    PaymentMethod? method,
    DateTime? paymentDate,
    List<Map<String, dynamic>>? allocatedObligations,
    String? pdfUrl,
    DateTime? createdAt,
  }) {
    return ReceiptModel(
      id: id ?? this.id,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      paymentId: paymentId ?? this.paymentId,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      amount: amount ?? this.amount,
      method: method ?? this.method,
      paymentDate: paymentDate ?? this.paymentDate,
      allocatedObligations: allocatedObligations ?? this.allocatedObligations,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
