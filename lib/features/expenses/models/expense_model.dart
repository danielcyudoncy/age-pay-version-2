import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/enums.dart';

class ExpenseModel {
  final String id;
  final String organizationId;
  final String title;
  final String description;
  final double amount;
  final ExpenseCategory category;
  final String? receiptUrl;
  final String createdBy;
  final DateTime expenseDate;
  final ExpenseStatus status;
  final Map<String, dynamic> approvals;
  final String? rejectionReason;
  final String? rejectedBy;
  final DateTime? rejectedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExpenseModel({
    required this.id,
    this.organizationId = '',
    required this.title,
    required this.description,
    required this.amount,
    required this.category,
    this.receiptUrl,
    required this.createdBy,
    required this.expenseDate,
    this.status = ExpenseStatus.pendingApproval,
    this.approvals = const {},
    this.rejectionReason,
    this.rejectedBy,
    this.rejectedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExpenseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final statusStr = data['status'] as String?;
    final ExpenseStatus parsedStatus;
    if (statusStr != null) {
      parsedStatus = ExpenseStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == statusStr.trim().toLowerCase(),
        orElse: () => ExpenseStatus.approved,
      );
    } else {
      // Legacy expenses without a status field default to approved
      parsedStatus = ExpenseStatus.approved;
    }

    final rawApprovals = data['approvals'];
    final Map<String, dynamic> parsedApprovals =
        (rawApprovals is Map) ? Map<String, dynamic>.from(rawApprovals) : {};

    return ExpenseModel(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      category: ExpenseCategory.values.firstWhere(
        (e) => e.name == (data['category'] ?? 'miscellaneous'),
        orElse: () => ExpenseCategory.miscellaneous,
      ),
      receiptUrl: data['receiptUrl'],
      createdBy: data['createdBy'] ?? '',
      expenseDate: _parseDate(data['expenseDate']),
      status: parsedStatus,
      approvals: parsedApprovals,
      rejectionReason: data['rejectionReason'],
      rejectedBy: data['rejectedBy'],
      rejectedAt: data['rejectedAt'] != null ? _parseDate(data['rejectedAt']) : null,
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      'title': title,
      'description': description,
      'amount': amount,
      'category': category.name,
      'receiptUrl': receiptUrl,
      'createdBy': createdBy,
      'expenseDate': Timestamp.fromDate(expenseDate),
      'status': status.name,
      'approvals': approvals,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (rejectedBy != null) 'rejectedBy': rejectedBy,
      if (rejectedAt != null) 'rejectedAt': Timestamp.fromDate(rejectedAt!),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  // --- Multi-Executive Approval Helpers ---

  static String? roleToApprovalKey(UserRole role) {
    switch (role) {
      case UserRole.president:
      case UserRole.vicePresident:
        return 'president';
      case UserRole.financialSecretary:
        return 'financialSecretary';
      case UserRole.secretary:
      case UserRole.viceSecretary:
        return 'secretary';
      default:
        return null;
    }
  }

  bool get isApproved => status == ExpenseStatus.approved;
  bool get isPending => status == ExpenseStatus.pendingApproval;
  bool get isRejected => status == ExpenseStatus.rejected;

  bool get isPresidentApproved =>
      approvals['president'] == true ||
      (approvals['president'] is Map &&
          approvals['president']['approved'] == true);

  bool get isFinancialSecretaryApproved =>
      approvals['financialSecretary'] == true ||
      (approvals['financialSecretary'] is Map &&
          approvals['financialSecretary']['approved'] == true);

  bool get isSecretaryApproved =>
      approvals['secretary'] == true ||
      (approvals['secretary'] is Map &&
          approvals['secretary']['approved'] == true);

  bool get isFullyApproved =>
      isPresidentApproved && isFinancialSecretaryApproved && isSecretaryApproved;

  int get approvedCount =>
      (isPresidentApproved ? 1 : 0) +
      (isFinancialSecretaryApproved ? 1 : 0) +
      (isSecretaryApproved ? 1 : 0);

  bool isRoleApproved(UserRole role) {
    final key = roleToApprovalKey(role);
    if (key == null) return false;
    return approvals[key] == true ||
        (approvals[key] is Map && approvals[key]['approved'] == true);
  }

  ExpenseModel copyWith({
    String? id,
    String? organizationId,
    String? title,
    String? description,
    double? amount,
    ExpenseCategory? category,
    String? receiptUrl,
    String? createdBy,
    DateTime? expenseDate,
    ExpenseStatus? status,
    Map<String, dynamic>? approvals,
    String? rejectionReason,
    String? rejectedBy,
    DateTime? rejectedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      createdBy: createdBy ?? this.createdBy,
      expenseDate: expenseDate ?? this.expenseDate,
      status: status ?? this.status,
      approvals: approvals ?? this.approvals,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
