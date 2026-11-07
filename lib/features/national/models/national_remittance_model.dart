import 'package:cloud_firestore/cloud_firestore.dart';

class NationalRemittanceModel {
  final String id;
  final String organizationId;
  final String? branchId;
  final String branchName;
  final String levyId;
  final String levyTitle;
  final double totalCollected;
  final double amountRemitted;
  final double unremittedBalance;
  final DateTime? remittedAt;
  final String remittedBy;
  final String? recipientRef;
  final String? notes;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NationalRemittanceModel({
    required this.id,
    required this.organizationId,
    this.branchId,
    this.branchName = '',
    required this.levyId,
    required this.levyTitle,
    required this.totalCollected,
    required this.amountRemitted,
    required this.unremittedBalance,
    this.remittedAt,
    this.remittedBy = '',
    this.recipientRef,
    this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NationalRemittanceModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return NationalRemittanceModel(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      branchId: data['branchId'] as String?,
      branchName: data['branchName'] ?? '',
      levyId: data['levyId'] ?? '',
      levyTitle: data['levyTitle'] ?? '',
      totalCollected: (data['totalCollected'] as num?)?.toDouble() ?? 0.0,
      amountRemitted: (data['amountRemitted'] as num?)?.toDouble() ?? 0.0,
      unremittedBalance: (data['unremittedBalance'] as num?)?.toDouble() ?? 0.0,
      remittedAt: data['remittedAt'] != null ? _parseDate(data['remittedAt']) : null,
      remittedBy: data['remittedBy'] ?? '',
      recipientRef: data['recipientRef'] as String?,
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
      'branchName': branchName,
      'levyId': levyId,
      'levyTitle': levyTitle,
      'totalCollected': totalCollected,
      'amountRemitted': amountRemitted,
      'unremittedBalance': unremittedBalance,
      if (remittedAt != null) 'remittedAt': Timestamp.fromDate(remittedAt!),
      'remittedBy': remittedBy,
      if (recipientRef != null) 'recipientRef': recipientRef,
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

  NationalRemittanceModel copyWith({
    String? id,
    String? organizationId,
    String? branchId,
    String? branchName,
    String? levyId,
    String? levyTitle,
    double? totalCollected,
    double? amountRemitted,
    double? unremittedBalance,
    DateTime? remittedAt,
    String? remittedBy,
    String? recipientRef,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NationalRemittanceModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      levyId: levyId ?? this.levyId,
      levyTitle: levyTitle ?? this.levyTitle,
      totalCollected: totalCollected ?? this.totalCollected,
      amountRemitted: amountRemitted ?? this.amountRemitted,
      unremittedBalance: unremittedBalance ?? this.unremittedBalance,
      remittedAt: remittedAt ?? this.remittedAt,
      remittedBy: remittedBy ?? this.remittedBy,
      recipientRef: recipientRef ?? this.recipientRef,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
