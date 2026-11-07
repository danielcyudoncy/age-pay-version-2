import 'package:cloud_firestore/cloud_firestore.dart';

class FiscalPeriodModel {
  final String id;
  final String organizationId;
  final String? branchId;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final double openingBalance;
  final double openingCashAtBank;
  final double openingCashInHand;
  final String? notes;
  final bool isActive;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FiscalPeriodModel({
    required this.id,
    required this.organizationId,
    this.branchId,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.openingBalance,
    this.openingCashAtBank = 0.0,
    this.openingCashInHand = 0.0,
    this.notes,
    this.isActive = true,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FiscalPeriodModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return FiscalPeriodModel(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      branchId: data['branchId'] as String?,
      title: data['title'] ?? '',
      startDate: _parseDate(data['startDate']),
      endDate: _parseDate(data['endDate']),
      openingBalance: (data['openingBalance'] as num?)?.toDouble() ?? 0.0,
      openingCashAtBank: (data['openingCashAtBank'] as num?)?.toDouble() ?? 0.0,
      openingCashInHand: (data['openingCashInHand'] as num?)?.toDouble() ?? 0.0,
      notes: data['notes'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      createdBy: data['createdBy'] ?? '',
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      if (branchId != null) 'branchId': branchId,
      'title': title,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'openingBalance': openingBalance,
      'openingCashAtBank': openingCashAtBank,
      'openingCashInHand': openingCashInHand,
      if (notes != null) 'notes': notes,
      'isActive': isActive,
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

  FiscalPeriodModel copyWith({
    String? id,
    String? organizationId,
    String? branchId,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    double? openingBalance,
    double? openingCashAtBank,
    double? openingCashInHand,
    String? notes,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FiscalPeriodModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      branchId: branchId ?? this.branchId,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      openingBalance: openingBalance ?? this.openingBalance,
      openingCashAtBank: openingCashAtBank ?? this.openingCashAtBank,
      openingCashInHand: openingCashInHand ?? this.openingCashInHand,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
