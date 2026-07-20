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

  const UserModel({
    required this.uid,
    required this.organizationId,
    required this.email,
    required this.displayName,
    required this.phoneNumber,
    required this.role,
    required this.createdAt,
    this.isActive = true,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final uid = doc.id;
    return UserModel(
      uid: uid,
      organizationId: data['organizationId'] ?? uid,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == (data['role'] ?? 'member'),
        orElse: () => UserRole.member,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
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
    };
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
    );
  }
}
