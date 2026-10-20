import 'package:cloud_firestore/cloud_firestore.dart';

class BranchModel {
  final String id;
  final String organizationId;
  final String name;
  final String state;
  final String city;
  final String? presidentId;
  final String? presidentName;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BranchModel({
    required this.id,
    required this.organizationId,
    required this.name,
    this.state = '',
    this.city = '',
    this.presidentId,
    this.presidentName,
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
      presidentId: data['presidentId'],
      presidentName: data['presidentName'],
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
      if (presidentId != null) 'presidentId': presidentId,
      if (presidentName != null) 'presidentName': presidentName,
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
    String? presidentId,
    String? presidentName,
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
      presidentId: presidentId ?? this.presidentId,
      presidentName: presidentName ?? this.presidentName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
