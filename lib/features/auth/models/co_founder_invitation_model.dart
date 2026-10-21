import 'package:cloud_firestore/cloud_firestore.dart';

class CoFounderInvitationModel {
  final String id;
  final String organizationId;
  final String organizationName;
  final String branchName;
  final String presidentUid;
  final String presidentName;
  final String presidentPhone;
  final String secretaryName;
  final String secretaryPhone;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime createdAt;
  final DateTime updatedAt;

  const CoFounderInvitationModel({
    required this.id,
    required this.organizationId,
    required this.organizationName,
    required this.branchName,
    required this.presidentUid,
    required this.presidentName,
    required this.presidentPhone,
    required this.secretaryName,
    required this.secretaryPhone,
    this.status = 'pending',
    required this.createdAt,
    required this.updatedAt,
  });

  factory CoFounderInvitationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CoFounderInvitationModel(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      organizationName: data['organizationName'] ?? '',
      branchName: data['branchName'] ?? '',
      presidentUid: data['presidentUid'] ?? '',
      presidentName: data['presidentName'] ?? '',
      presidentPhone: data['presidentPhone'] ?? '',
      secretaryName: data['secretaryName'] ?? '',
      secretaryPhone: data['secretaryPhone'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      'organizationName': organizationName,
      'branchName': branchName,
      'presidentUid': presidentUid,
      'presidentName': presidentName,
      'presidentPhone': presidentPhone,
      'secretaryName': secretaryName,
      'secretaryPhone': secretaryPhone,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  CoFounderInvitationModel copyWith({
    String? id,
    String? organizationId,
    String? organizationName,
    String? branchName,
    String? presidentUid,
    String? presidentName,
    String? presidentPhone,
    String? secretaryName,
    String? secretaryPhone,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CoFounderInvitationModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      organizationName: organizationName ?? this.organizationName,
      branchName: branchName ?? this.branchName,
      presidentUid: presidentUid ?? this.presidentUid,
      presidentName: presidentName ?? this.presidentName,
      presidentPhone: presidentPhone ?? this.presidentPhone,
      secretaryName: secretaryName ?? this.secretaryName,
      secretaryPhone: secretaryPhone ?? this.secretaryPhone,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
