import 'package:cloud_firestore/cloud_firestore.dart';

class OrganizationModel {
  final String id;
  final String name;
  final String slug;
  final String description;
  final String contactEmail;
  final String contactPhone;
  final String address;
  final bool isActive;
  final bool openForJoin;
  final int memberCount;
  final String? bankName;
  final String? accountNumber;
  final String? accountName;
  final String verificationStatus; // 'verified', 'pending_verification', 'rejected'
  final String? cacNumber;
  final String? townUnionName;
  final String? townUnionContact;
  final String? founderNinOrBvn;
  final String? secretaryNinOrBvn;
  final bool isBankVerified;
  final String? bankAccountType;
  final bool bankVerificationOverridden;
  final String? bankVerificationOverrideReason;
  final String? bankVerificationOverriddenBy;
  final DateTime? bankVerificationOverriddenAt;
  final String subscriptionTier; // 'starter', 'pro', 'national'
  final String subscriptionStatus; // 'active', 'pending_verification', 'expired'
  final DateTime? subscriptionExpiresAt;
  final String? licenseProofUrl;
  final String? licensePaymentReference;
  final String? licensePaymentBank;
  final double? licensePaymentAmount;
  final DateTime? licenseSubmittedAt;
  final String? licenseVerifiedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrganizationModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description = '',
    this.contactEmail = '',
    this.contactPhone = '',
    this.address = '',
    this.isActive = true,
    this.openForJoin = true,
    this.memberCount = 0,
    this.bankName,
    this.accountNumber,
    this.accountName,
    this.verificationStatus = 'verified',
    this.cacNumber,
    this.townUnionName,
    this.townUnionContact,
    this.founderNinOrBvn,
    this.secretaryNinOrBvn,
    this.isBankVerified = false,
    this.bankAccountType,
    this.bankVerificationOverridden = false,
    this.bankVerificationOverrideReason,
    this.bankVerificationOverriddenBy,
    this.bankVerificationOverriddenAt,
    this.subscriptionTier = 'starter',
    this.subscriptionStatus = 'active',
    this.subscriptionExpiresAt,
    this.licenseProofUrl,
    this.licensePaymentReference,
    this.licensePaymentBank,
    this.licensePaymentAmount,
    this.licenseSubmittedAt,
    this.licenseVerifiedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isVerified => verificationStatus == 'verified';
  bool get isPendingVerification => verificationStatus == 'pending_verification';
  bool get isLicensePendingVerification =>
      subscriptionStatus == 'pending_verification';
  bool get isLicenseActive {
    if (subscriptionStatus == 'pending_verification') return false;
    if (subscriptionExpiresAt == null) return true; // Starter / permanent
    return DateTime.now().isBefore(subscriptionExpiresAt!);
  }
  bool get isLicenseExpired {
    if (subscriptionExpiresAt == null) return false;
    return DateTime.now().isAfter(subscriptionExpiresAt!);
  }
  int get licenseDaysRemaining {
    if (subscriptionExpiresAt == null) return 365;
    final diff = subscriptionExpiresAt!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  factory OrganizationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final active = data['isActive'] ?? true;
    final defaultStatus = active ? 'verified' : 'pending_verification';
    return OrganizationModel(
      id: doc.id,
      name: data['name'] ?? '',
      slug: data['slug'] ?? '',
      description: data['description'] ?? '',
      contactEmail: data['contactEmail'] ?? '',
      contactPhone: data['contactPhone'] ?? '',
      address: data['address'] ?? '',
      isActive: active,
      openForJoin: data['openForJoin'] ?? true,
      memberCount: (data['memberCount'] is int) ? data['memberCount'] : 0,
      bankName: data['bankName'] as String?,
      accountNumber: data['accountNumber'] as String?,
      accountName: data['accountName'] as String?,
      verificationStatus: data['verificationStatus'] ?? defaultStatus,
      cacNumber: data['cacNumber'] as String?,
      townUnionName: data['townUnionName'] as String?,
      townUnionContact: data['townUnionContact'] as String?,
      founderNinOrBvn: data['founderNinOrBvn'] as String?,
      secretaryNinOrBvn: data['secretaryNinOrBvn'] as String?,
      isBankVerified: data['isBankVerified'] ?? false,
      bankAccountType: data['bankAccountType'] as String?,
      bankVerificationOverridden:
          data['bankVerificationOverridden'] as bool? ?? false,
      bankVerificationOverrideReason:
          data['bankVerificationOverrideReason'] as String?,
      bankVerificationOverriddenBy:
          data['bankVerificationOverriddenBy'] as String?,
      bankVerificationOverriddenAt: data['bankVerificationOverriddenAt'] != null
          ? _parseDate(data['bankVerificationOverriddenAt'])
          : null,
      subscriptionTier: data['subscriptionTier'] ?? 'starter',
      subscriptionStatus: data['subscriptionStatus'] ?? 'active',
      subscriptionExpiresAt: data['subscriptionExpiresAt'] != null
          ? _parseDate(data['subscriptionExpiresAt'])
          : null,
      licenseProofUrl: data['licenseProofUrl'] as String?,
      licensePaymentReference: data['licensePaymentReference'] as String?,
      licensePaymentBank: data['licensePaymentBank'] as String?,
      licensePaymentAmount: (data['licensePaymentAmount'] is num)
          ? (data['licensePaymentAmount'] as num).toDouble()
          : null,
      licenseSubmittedAt: data['licenseSubmittedAt'] != null
          ? _parseDate(data['licenseSubmittedAt'])
          : null,
      licenseVerifiedBy: data['licenseVerifiedBy'] as String?,
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'slug': slug,
      'description': description,
      'contactEmail': contactEmail,
      'contactPhone': contactPhone,
      'address': address,
      'isActive': isActive,
      'openForJoin': openForJoin,
      'memberCount': memberCount,
      if (bankName != null) 'bankName': bankName,
      if (accountNumber != null) 'accountNumber': accountNumber,
      if (accountName != null) 'accountName': accountName,
      'verificationStatus': verificationStatus,
      if (cacNumber != null) 'cacNumber': cacNumber,
      if (townUnionName != null) 'townUnionName': townUnionName,
      if (townUnionContact != null) 'townUnionContact': townUnionContact,
      if (founderNinOrBvn != null) 'founderNinOrBvn': founderNinOrBvn,
      if (secretaryNinOrBvn != null) 'secretaryNinOrBvn': secretaryNinOrBvn,
      'isBankVerified': isBankVerified,
      if (bankAccountType != null) 'bankAccountType': bankAccountType,
      'bankVerificationOverridden': bankVerificationOverridden,
      if (bankVerificationOverrideReason != null)
        'bankVerificationOverrideReason': bankVerificationOverrideReason,
      if (bankVerificationOverriddenBy != null)
        'bankVerificationOverriddenBy': bankVerificationOverriddenBy,
      if (bankVerificationOverriddenAt != null)
        'bankVerificationOverriddenAt':
            Timestamp.fromDate(bankVerificationOverriddenAt!),
      'subscriptionTier': subscriptionTier,
      'subscriptionStatus': subscriptionStatus,
      if (subscriptionExpiresAt != null)
        'subscriptionExpiresAt': Timestamp.fromDate(subscriptionExpiresAt!),
      if (licenseProofUrl != null) 'licenseProofUrl': licenseProofUrl,
      if (licensePaymentReference != null)
        'licensePaymentReference': licensePaymentReference,
      if (licensePaymentBank != null) 'licensePaymentBank': licensePaymentBank,
      if (licensePaymentAmount != null)
        'licensePaymentAmount': licensePaymentAmount,
      if (licenseSubmittedAt != null)
        'licenseSubmittedAt': Timestamp.fromDate(licenseSubmittedAt!),
      if (licenseVerifiedBy != null) 'licenseVerifiedBy': licenseVerifiedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  OrganizationModel copyWith({
    String? id,
    String? name,
    String? slug,
    String? description,
    String? contactEmail,
    String? contactPhone,
    String? address,
    bool? isActive,
    bool? openForJoin,
    int? memberCount,
    String? bankName,
    String? accountNumber,
    String? accountName,
    String? verificationStatus,
    String? cacNumber,
    String? townUnionName,
    String? townUnionContact,
    String? founderNinOrBvn,
    String? secretaryNinOrBvn,
    bool? isBankVerified,
    String? bankAccountType,
    bool? bankVerificationOverridden,
    String? bankVerificationOverrideReason,
    String? bankVerificationOverriddenBy,
    DateTime? bankVerificationOverriddenAt,
    String? subscriptionTier,
    String? subscriptionStatus,
    DateTime? subscriptionExpiresAt,
    String? licenseProofUrl,
    String? licensePaymentReference,
    String? licensePaymentBank,
    double? licensePaymentAmount,
    DateTime? licenseSubmittedAt,
    String? licenseVerifiedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrganizationModel(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      address: address ?? this.address,
      isActive: isActive ?? this.isActive,
      openForJoin: openForJoin ?? this.openForJoin,
      memberCount: memberCount ?? this.memberCount,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountName: accountName ?? this.accountName,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      cacNumber: cacNumber ?? this.cacNumber,
      townUnionName: townUnionName ?? this.townUnionName,
      townUnionContact: townUnionContact ?? this.townUnionContact,
      founderNinOrBvn: founderNinOrBvn ?? this.founderNinOrBvn,
      secretaryNinOrBvn: secretaryNinOrBvn ?? this.secretaryNinOrBvn,
      isBankVerified: isBankVerified ?? this.isBankVerified,
      bankAccountType: bankAccountType ?? this.bankAccountType,
      bankVerificationOverridden:
          bankVerificationOverridden ?? this.bankVerificationOverridden,
      bankVerificationOverrideReason:
          bankVerificationOverrideReason ?? this.bankVerificationOverrideReason,
      bankVerificationOverriddenBy:
          bankVerificationOverriddenBy ?? this.bankVerificationOverriddenBy,
      bankVerificationOverriddenAt:
          bankVerificationOverriddenAt ?? this.bankVerificationOverriddenAt,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionExpiresAt:
          subscriptionExpiresAt ?? this.subscriptionExpiresAt,
      licenseProofUrl: licenseProofUrl ?? this.licenseProofUrl,
      licensePaymentReference:
          licensePaymentReference ?? this.licensePaymentReference,
      licensePaymentBank: licensePaymentBank ?? this.licensePaymentBank,
      licensePaymentAmount: licensePaymentAmount ?? this.licensePaymentAmount,
      licenseSubmittedAt: licenseSubmittedAt ?? this.licenseSubmittedAt,
      licenseVerifiedBy: licenseVerifiedBy ?? this.licenseVerifiedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
