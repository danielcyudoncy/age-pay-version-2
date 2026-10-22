import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/enums.dart';

class UserModel {
  final String uid;
  final String organizationId;
  final String email;
  final String displayName;
  final String phoneNumber;
  final UserRole role;
  final DateTime createdAt;
  final bool isActive;
  final AccountStatus status;
  final String? branchId;
  final String? branchName;
  final UserRole? requestedRole;
  final String? coFounderName;
  final String? coFounderPhone;
  final MemberDuesStanding duesStanding;
  final double? openingBalance;

  const UserModel({
    required this.uid,
    required this.organizationId,
    required this.email,
    required this.displayName,
    required this.phoneNumber,
    required this.role,
    required this.createdAt,
    this.isActive = true,
    this.status = AccountStatus.approved,
    this.branchId,
    this.branchName,
    this.requestedRole,
    this.coFounderName,
    this.coFounderPhone,
    this.duesStanding = MemberDuesStanding.newMember,
    this.openingBalance,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final uid = doc.id;
    final statusStr = data['status'] as String?;
    final AccountStatus parsedStatus;
    if (statusStr != null) {
      final normalized = statusStr.replaceAll('_', '').trim().toLowerCase();
      parsedStatus = AccountStatus.values.firstWhere(
        (s) => s.name.toLowerCase() == normalized,
        orElse: () => (data['isActive'] == false)
            ? AccountStatus.pendingApproval
            : AccountStatus.approved,
      );
    } else {
      parsedStatus = (data['isActive'] == false)
          ? AccountStatus.pendingApproval
          : AccountStatus.approved;
    }

    final requestedRoleStr = data['requestedRole'] as String?;
    final UserRole? parsedReqRole = requestedRoleStr != null
        ? UserRole.values.firstWhere(
            (r) => r.name.toLowerCase() == requestedRoleStr.trim().toLowerCase(),
            orElse: () => UserRole.member,
          )
        : null;

    final rawRole = (data['role'] ?? 'member').toString().trim().toLowerCase();
    final parsedRole = UserRole.values.firstWhere(
      (e) => e.name.toLowerCase() == rawRole,
      orElse: () => UserRole.member,
    );

    final standingStr = data['duesStanding'] as String?;
    final MemberDuesStanding parsedStanding = standingStr != null
        ? MemberDuesStanding.values.firstWhere(
            (s) => s.name.toLowerCase() == standingStr.trim().toLowerCase(),
            orElse: () => MemberDuesStanding.newMember,
          )
        : MemberDuesStanding.newMember;

    return UserModel(
      uid: uid,
      organizationId: data['organizationId'] ?? uid,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      role: parsedRole,
      createdAt: _parseDate(data['createdAt']),
      isActive: data['isActive'] ?? true,
      status: parsedStatus,
      branchId: data['branchId'],
      branchName: data['branchName'],
      requestedRole: parsedReqRole,
      coFounderName: data['coFounderName'],
      coFounderPhone: data['coFounderPhone'],
      duesStanding: parsedStanding,
      openingBalance: (data['openingBalance'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'role': role.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
      'status': status.name,
      'duesStanding': duesStanding.name,
      if (openingBalance != null) 'openingBalance': openingBalance,
      if (branchId != null) 'branchId': branchId,
      if (branchName != null) 'branchName': branchName,
      if (requestedRole != null) 'requestedRole': requestedRole!.name,
      if (coFounderName != null) 'coFounderName': coFounderName,
      if (coFounderPhone != null) 'coFounderPhone': coFounderPhone,
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  UserModel copyWith({
    String? uid,
    String? organizationId,
    String? email,
    String? displayName,
    String? phoneNumber,
    UserRole? role,
    DateTime? createdAt,
    bool? isActive,
    AccountStatus? status,
    String? branchId,
    String? branchName,
    UserRole? requestedRole,
    String? coFounderName,
    String? coFounderPhone,
    MemberDuesStanding? duesStanding,
    double? openingBalance,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      organizationId: organizationId ?? this.organizationId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      requestedRole: requestedRole ?? this.requestedRole,
      coFounderName: coFounderName ?? this.coFounderName,
      coFounderPhone: coFounderPhone ?? this.coFounderPhone,
      duesStanding: duesStanding ?? this.duesStanding,
      openingBalance: openingBalance ?? this.openingBalance,
    );
  }

  bool get isExecutive => role.isExecutive;
}
