import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_version.dart';

class SystemSettingsModel {
  final String id;
  // Payment & Financial
  final String paymentEnvironment; // 'test' | 'live'
  final String paystackPublicKey;
  final String flutterwavePublicKey;
  final String feeBearer; // 'member' | 'organization'
  final String currency; // 'NGN'
  final double dualApprovalExpenseThreshold;

  // Platform Policies
  final bool requirePresidentApproval;
  final int maxUploadSizeBytes;
  final int sessionTimeoutMinutes;

  // Platform Subscription & Corporate Receiving Bank
  final String companyBankName;
  final String companyAccountName;
  final String companyAccountNumber;
  final double annualLicenseFee;

  // Communication & Notifications
  final bool pushNotificationsEnabled;
  final bool smsNotificationsEnabled;
  final String smsProvider; // 'Termii' | 'Twilio'
  final bool emailNotificationsEnabled;

  // Maintenance & System State
  final bool maintenanceMode;
  final String maintenanceMessage;

  // App Release & Distribution (In-App Direct Updates)
  final String latestAppVersion;
  final String minimumRequiredVersion;
  final String apkDownloadUrl;
  final String releaseNotes;
  final bool forceUpdate;

  final DateTime updatedAt;
  final String updatedBy;

  const SystemSettingsModel({
    this.id = 'global_config',
    this.paymentEnvironment = 'live',
    this.paystackPublicKey = '',
    this.flutterwavePublicKey = '',
    this.feeBearer = 'member',
    this.currency = 'NGN',
    this.dualApprovalExpenseThreshold = 50000.0,
    this.requirePresidentApproval = true,
    this.maxUploadSizeBytes = 10485760, // 10MB
    this.sessionTimeoutMinutes = 60,
    this.companyBankName = 'Zenith Bank',
    this.companyAccountName = 'AgePay Technologies Ltd',
    this.companyAccountNumber = '1012345678',
    this.annualLicenseFee = 35000.0,
    this.pushNotificationsEnabled = true,
    this.smsNotificationsEnabled = true,
    this.smsProvider = 'Termii',
    this.emailNotificationsEnabled = true,
    this.maintenanceMode = false,
    this.maintenanceMessage =
        'System is undergoing scheduled maintenance. Please check back shortly.',
    this.latestAppVersion = '1.0.0',
    this.minimumRequiredVersion = '1.0.0',
    this.apkDownloadUrl = '',
    this.releaseNotes = '',
    this.forceUpdate = false,
    required this.updatedAt,
    this.updatedBy = 'system',
  });

  bool get hasValidApkUrl =>
      apkDownloadUrl.trim().isNotEmpty &&
      apkDownloadUrl.trim().startsWith('http');

  /// Returns `true` if an update is available compared to [currentVersion].
  bool isUpdateAvailable(String currentVersion) =>
      hasValidApkUrl &&
      AppVersion.isVersionOlder(currentVersion, latestAppVersion);

  /// Returns `true` if this update is strictly required (force update).
  bool isUpdateRequired(String currentVersion) =>
      hasValidApkUrl &&
      (forceUpdate ||
          AppVersion.isVersionOlder(currentVersion, minimumRequiredVersion));

  factory SystemSettingsModel.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists || doc.data() == null) {
      return SystemSettingsModel.defaults();
    }
    final data = doc.data() as Map<String, dynamic>;
    return SystemSettingsModel(
      id: doc.id,
      paymentEnvironment: data['paymentEnvironment'] ?? 'live',
      paystackPublicKey: data['paystackPublicKey'] ?? '',
      flutterwavePublicKey: data['flutterwavePublicKey'] ?? '',
      feeBearer: data['feeBearer'] ?? 'member',
      currency: data['currency'] ?? 'NGN',
      dualApprovalExpenseThreshold:
          (data['dualApprovalExpenseThreshold'] as num?)?.toDouble() ?? 50000.0,
      requirePresidentApproval: data['requirePresidentApproval'] ?? true,
      maxUploadSizeBytes: (data['maxUploadSizeBytes'] as int?) ?? 10485760,
      sessionTimeoutMinutes: (data['sessionTimeoutMinutes'] as int?) ?? 60,
      companyBankName: data['companyBankName'] ?? 'Zenith Bank',
      companyAccountName: data['companyAccountName'] ?? 'AgePay Technologies Ltd',
      companyAccountNumber: data['companyAccountNumber'] ?? '1012345678',
      annualLicenseFee:
          (data['annualLicenseFee'] as num?)?.toDouble() ?? 35000.0,
      pushNotificationsEnabled: data['pushNotificationsEnabled'] ?? true,
      smsNotificationsEnabled: data['smsNotificationsEnabled'] ?? true,
      smsProvider: data['smsProvider'] ?? 'Termii',
      emailNotificationsEnabled: data['emailNotificationsEnabled'] ?? true,
      maintenanceMode: data['maintenanceMode'] ?? false,
      maintenanceMessage: data['maintenanceMessage'] ??
          'System is undergoing scheduled maintenance. Please check back shortly.',
      latestAppVersion: data['latestAppVersion'] as String? ?? '1.0.0',
      minimumRequiredVersion:
          data['minimumRequiredVersion'] as String? ?? '1.0.0',
      apkDownloadUrl: data['apkDownloadUrl'] as String? ?? '',
      releaseNotes: data['releaseNotes'] as String? ?? '',
      forceUpdate: data['forceUpdate'] as bool? ?? false,
      updatedAt: _parseDate(data['updatedAt']),
      updatedBy: data['updatedBy'] ?? 'system',
    );
  }

  factory SystemSettingsModel.defaults() {
    return SystemSettingsModel(
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'paymentEnvironment': paymentEnvironment,
      'paystackPublicKey': paystackPublicKey,
      'flutterwavePublicKey': flutterwavePublicKey,
      'feeBearer': feeBearer,
      'currency': currency,
      'dualApprovalExpenseThreshold': dualApprovalExpenseThreshold,
      'requirePresidentApproval': requirePresidentApproval,
      'maxUploadSizeBytes': maxUploadSizeBytes,
      'sessionTimeoutMinutes': sessionTimeoutMinutes,
      'companyBankName': companyBankName,
      'companyAccountName': companyAccountName,
      'companyAccountNumber': companyAccountNumber,
      'annualLicenseFee': annualLicenseFee,
      'pushNotificationsEnabled': pushNotificationsEnabled,
      'smsNotificationsEnabled': smsNotificationsEnabled,
      'smsProvider': smsProvider,
      'emailNotificationsEnabled': emailNotificationsEnabled,
      'maintenanceMode': maintenanceMode,
      'maintenanceMessage': maintenanceMessage,
      'latestAppVersion': latestAppVersion,
      'minimumRequiredVersion': minimumRequiredVersion,
      'apkDownloadUrl': apkDownloadUrl,
      'releaseNotes': releaseNotes,
      'forceUpdate': forceUpdate,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'updatedBy': updatedBy,
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  SystemSettingsModel copyWith({
    String? id,
    String? paymentEnvironment,
    String? paystackPublicKey,
    String? flutterwavePublicKey,
    String? feeBearer,
    String? currency,
    double? dualApprovalExpenseThreshold,
    bool? requirePresidentApproval,
    int? maxUploadSizeBytes,
    int? sessionTimeoutMinutes,
    String? companyBankName,
    String? companyAccountName,
    String? companyAccountNumber,
    double? annualLicenseFee,
    bool? pushNotificationsEnabled,
    bool? smsNotificationsEnabled,
    String? smsProvider,
    bool? emailNotificationsEnabled,
    bool? maintenanceMode,
    String? maintenanceMessage,
    String? latestAppVersion,
    String? minimumRequiredVersion,
    String? apkDownloadUrl,
    String? releaseNotes,
    bool? forceUpdate,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return SystemSettingsModel(
      id: id ?? this.id,
      paymentEnvironment: paymentEnvironment ?? this.paymentEnvironment,
      paystackPublicKey: paystackPublicKey ?? this.paystackPublicKey,
      flutterwavePublicKey: flutterwavePublicKey ?? this.flutterwavePublicKey,
      feeBearer: feeBearer ?? this.feeBearer,
      currency: currency ?? this.currency,
      dualApprovalExpenseThreshold:
          dualApprovalExpenseThreshold ?? this.dualApprovalExpenseThreshold,
      requirePresidentApproval:
          requirePresidentApproval ?? this.requirePresidentApproval,
      maxUploadSizeBytes: maxUploadSizeBytes ?? this.maxUploadSizeBytes,
      sessionTimeoutMinutes:
          sessionTimeoutMinutes ?? this.sessionTimeoutMinutes,
      companyBankName: companyBankName ?? this.companyBankName,
      companyAccountName: companyAccountName ?? this.companyAccountName,
      companyAccountNumber: companyAccountNumber ?? this.companyAccountNumber,
      annualLicenseFee: annualLicenseFee ?? this.annualLicenseFee,
      pushNotificationsEnabled:
          pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      smsNotificationsEnabled:
          smsNotificationsEnabled ?? this.smsNotificationsEnabled,
      smsProvider: smsProvider ?? this.smsProvider,
      emailNotificationsEnabled:
          emailNotificationsEnabled ?? this.emailNotificationsEnabled,
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      maintenanceMessage: maintenanceMessage ?? this.maintenanceMessage,
      latestAppVersion: latestAppVersion ?? this.latestAppVersion,
      minimumRequiredVersion:
          minimumRequiredVersion ?? this.minimumRequiredVersion,
      apkDownloadUrl: apkDownloadUrl ?? this.apkDownloadUrl,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      forceUpdate: forceUpdate ?? this.forceUpdate,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
