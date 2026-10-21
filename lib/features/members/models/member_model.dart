import 'package:cloud_firestore/cloud_firestore.dart';

class MemberModel {
  final String id;
  final String userId;
  final String fullName;
  final String email;
  final String phoneNumber;
  final DateTime dateOfBirth;
  final DateTime joinedDate;
  final bool isActive;
  final String status;
  final String? branchId;
  final String? branchName;
  final String? profilePhotoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MemberModel({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.dateOfBirth,
    required this.joinedDate,
    this.isActive = true,
    this.status = 'approved',
    this.branchId,
    this.branchName,
    this.profilePhotoUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MemberModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MemberModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      dateOfBirth: _parseDate(data['dateOfBirth']),
      joinedDate: _parseDate(data['joinedDate']),
      isActive: data['isActive'] ?? true,
      status: data['status'] ?? ((data['isActive'] == false) ? 'pending_approval' : 'approved'),
      branchId: data['branchId'],
      branchName: data['branchName'],
      profilePhotoUrl: data['profilePhotoUrl'],
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
      'joinedDate': Timestamp.fromDate(joinedDate),
      'isActive': isActive,
      'status': status,
      if (branchId != null) 'branchId': branchId,
      if (branchName != null) 'branchName': branchName,
      'profilePhotoUrl': profilePhotoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  MemberModel copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? email,
    String? phoneNumber,
    DateTime? dateOfBirth,
    DateTime? joinedDate,
    bool? isActive,
    String? status,
    String? branchId,
    String? branchName,
    String? profilePhotoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MemberModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      joinedDate: joinedDate ?? this.joinedDate,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
