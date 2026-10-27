import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/enums.dart';

class LevyModel {
  final String id;
  final String organizationId;
  final String title;
  final String description;
  final ObligationType type;
  final double amountPerMember;
  final String? targetGroup; // 'all', 'executives', or member ID list
  final String scope; // 'national' | 'branch'
  final String? branchId;
  final DateTime dueDate;
  final String createdBy;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LevyModel({
    required this.id,
    this.organizationId = '',
    required this.title,
    required this.description,
    required this.type,
    required this.amountPerMember,
    this.targetGroup,
    this.scope = 'branch',
    this.branchId,
    required this.dueDate,
    required this.createdBy,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LevyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LevyModel(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      type: ObligationType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'monthlyDue'),
        orElse: () => ObligationType.monthlyDue,
      ),
      amountPerMember: (data['amountPerMember'] as num?)?.toDouble() ?? 0.0,
      targetGroup: data['targetGroup'],
      scope: data['scope'] ?? 'branch',
      branchId: data['branchId'],
      dueDate: _parseDate(data['dueDate']),
      createdBy: data['createdBy'] ?? '',
      isActive: data['isActive'] ?? true,
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      'title': title,
      'description': description,
      'type': type.name,
      'amountPerMember': amountPerMember,
      'targetGroup': targetGroup,
      'scope': scope,
      if (branchId != null) 'branchId': branchId,
      'dueDate': Timestamp.fromDate(dueDate),
      'createdBy': createdBy,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  LevyModel copyWith({
    String? id,
    String? organizationId,
    String? title,
    String? description,
    ObligationType? type,
    double? amountPerMember,
    String? targetGroup,
    String? scope,
    String? branchId,
    DateTime? dueDate,
    String? createdBy,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LevyModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      amountPerMember: amountPerMember ?? this.amountPerMember,
      targetGroup: targetGroup ?? this.targetGroup,
      scope: scope ?? this.scope,
      branchId: branchId ?? this.branchId,
      dueDate: dueDate ?? this.dueDate,
      createdBy: createdBy ?? this.createdBy,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LevyModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
