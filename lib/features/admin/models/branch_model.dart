import 'package:cloud_firestore/cloud_firestore.dart';

class BranchModel {
  final String id;
  final String organizationId;
  final String name;
  final String state;
  final String city;
  final bool isNational;
  final String? bankName;
  final String? accountNumber;
  final String? accountName;
  final String? presidentId;
  final String? presidentName;
  final String? secretaryId;
  final String? secretaryName;
  final String? financialSecretaryId;
  final String? financialSecretaryName;
  final String? treasurerId;
  final String? treasurerName;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BranchModel({
    required this.id,
    required this.organizationId,
    required this.name,
    this.state = '',
    this.city = '',
    this.isNational = false,
    this.bankName,
    this.accountNumber,
    this.accountName,
    this.presidentId,
    this.presidentName,
    this.secretaryId,
    this.secretaryName,
    this.financialSecretaryId,
    this.financialSecretaryName,
    this.treasurerId,
    this.treasurerName,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BranchModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BranchModel(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      name: data['name'] ?? '',
      state: data['state'] ?? '',
      city: data['city'] ?? '',
      isNational: data['isNational'] ?? false,
      bankName: data['bankName'] as String?,
      accountNumber: data['accountNumber'] as String?,
      accountName: data['accountName'] as String?,
      presidentId: data['presidentId'],
      presidentName: data['presidentName'],
      secretaryId: data['secretaryId'],
      secretaryName: data['secretaryName'],
      financialSecretaryId: data['financialSecretaryId'],
      financialSecretaryName: data['financialSecretaryName'],
      treasurerId: data['treasurerId'],
      treasurerName: data['treasurerName'],
      isActive: data['isActive'] ?? true,
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      'name': name,
      'state': state,
      'city': city,
      'isNational': isNational,
      if (bankName != null) 'bankName': bankName,
      if (accountNumber != null) 'accountNumber': accountNumber,
      if (accountName != null) 'accountName': accountName,
      if (presidentId != null) 'presidentId': presidentId,
      if (presidentName != null) 'presidentName': presidentName,
      if (secretaryId != null) 'secretaryId': secretaryId,
      if (secretaryName != null) 'secretaryName': secretaryName,
      if (financialSecretaryId != null)
        'financialSecretaryId': financialSecretaryId,
      if (financialSecretaryName != null)
        'financialSecretaryName': financialSecretaryName,
      if (treasurerId != null) 'treasurerId': treasurerId,
      if (treasurerName != null) 'treasurerName': treasurerName,
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

  BranchModel copyWith({
    String? id,
    String? organizationId,
    String? name,
    String? state,
    String? city,
    bool? isNational,
    String? bankName,
    String? accountNumber,
    String? accountName,
    String? presidentId,
    String? presidentName,
    String? secretaryId,
    String? secretaryName,
    String? financialSecretaryId,
    String? financialSecretaryName,
    String? treasurerId,
    String? treasurerName,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BranchModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      name: name ?? this.name,
      state: state ?? this.state,
      city: city ?? this.city,
      isNational: isNational ?? this.isNational,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountName: accountName ?? this.accountName,
      presidentId: presidentId ?? this.presidentId,
      presidentName: presidentName ?? this.presidentName,
      secretaryId: secretaryId ?? this.secretaryId,
      secretaryName: secretaryName ?? this.secretaryName,
      financialSecretaryId:
          financialSecretaryId ?? this.financialSecretaryId,
      financialSecretaryName:
          financialSecretaryName ?? this.financialSecretaryName,
      treasurerId: treasurerId ?? this.treasurerId,
      treasurerName: treasurerName ?? this.treasurerName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
