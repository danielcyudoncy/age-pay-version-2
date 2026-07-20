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
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrganizationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrganizationModel(
      id: doc.id,
      name: data['name'] ?? '',
      slug: data['slug'] ?? '',
      description: data['description'] ?? '',
      contactEmail: data['contactEmail'] ?? '',
      contactPhone: data['contactPhone'] ?? '',
      address: data['address'] ?? '',
      isActive: data['isActive'] ?? true,
      openForJoin: data['openForJoin'] ?? true,
      memberCount: (data['memberCount'] is int) ? data['memberCount'] : 0,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
