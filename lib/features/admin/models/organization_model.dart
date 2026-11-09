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
  final String subscriptionTier; // 'starter', 'pro', 'national', 'trial'
  final String subscriptionStatus; // 'active', 'pending_verification', 'expired'
  final DateTime? subscriptionExpiresAt;
  final bool isTrial;
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
    this.isTrial = false,
    this.licenseProofUrl,
    this.licensePaymentReference,
    this.licensePaymentBank,
    this.licensePaymentAmount,
    this.licenseSubmittedAt,
    this.licenseVerifiedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  static const int gracePeriodDays = 14;
  static const int trialDurationDays = 60;

  bool get isVerified => verificationStatus == 'verified';
  bool get isPendingVerification => verificationStatus == 'pending_verification';
  bool get isLicensePendingVerification =>
      subscriptionStatus == 'pending_verification';

  /// True if the current license or trial period is active (before expiry date)
  /// or pending verification of a submitted renewal slip.
  bool get isLicenseActive {
    if (subscriptionStatus == 'pending_verification') return true;
    if (subscriptionExpiresAt == null) return true; // Starter / permanent
    return DateTime.now().isBefore(subscriptionExpiresAt!);
  }

  /// True if past the base expiration date (in grace period or hard expired)
  bool get isLicenseExpired {
    if (subscriptionExpiresAt == null) return false;
    return DateTime.now().isAfter(subscriptionExpiresAt!);
  }

  /// True if the organization is currently within the 14-day grace period
  bool get isInGracePeriod {
    if (subscriptionExpiresAt == null) return false;
    final now = DateTime.now();
    final graceEnd =
        subscriptionExpiresAt!.add(const Duration(days: gracePeriodDays));
    return now.isAfter(subscriptionExpiresAt!) && now.isBefore(graceEnd);
  }

  /// Number of days remaining in the 14-day grace period
  int get gracePeriodDaysRemaining {
    if (subscriptionExpiresAt == null) return 0;
    final graceEnd =
        subscriptionExpiresAt!.add(const Duration(days: gracePeriodDays));
    final diff = graceEnd.difference(DateTime.now());
    if (diff.isNegative) return 0;
    final days = (diff.inHours / 24).ceil();
    return days > 0 ? days : 0;
  }

  /// True if the organization is beyond BOTH expiration and the 14-day grace period
  bool get isLicenseHardExpired {
    if (subscriptionExpiresAt == null) return false;
    final graceEnd =
        subscriptionExpiresAt!.add(const Duration(days: gracePeriodDays));
    return DateTime.now().isAfter(graceEnd);
  }

  /// True if the organization is in Read-Only mode (hard expired and no renewal pending)
  bool get isReadOnly => isLicenseHardExpired && !isLicensePendingVerification;

  /// True if renewal is due within 30 days and not yet expired
  bool get isRenewalDueSoon {
    if (subscriptionExpiresAt == null) return false;
    final days = licenseDaysRemaining;
    return days <= 30 && !isLicenseExpired;
  }

  int get licenseDaysRemaining {
    if (subscriptionExpiresAt == null) return 365;
    final diff = subscriptionExpiresAt!.difference(DateTime.now());
    if (diff.isNegative) return 0;
    final days = (diff.inHours / 24).ceil();
    return days > 0 ? days : 0;
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
      isTrial: data['isTrial'] == true || data['subscriptionTier'] == 'trial',
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
      'isTrial': isTrial,
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
    bool? isTrial,
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
      isTrial: isTrial ?? this.isTrial,
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
