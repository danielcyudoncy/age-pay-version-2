import 'package:cloud_firestore/cloud_firestore.dart';

enum DocumentCategory {
  constitution,
  meetingMinutes,
  reports,
  financialReports,
  membershipForms,
  policies,
  images,
  videos,
  otherDocuments,
}

enum DocumentStatus { active, archived }

class DocumentModel {
  final String id;
  final String organizationId;
  final String title;
  final String description;
  final DocumentCategory category;
  final String fileUrl;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final DocumentStatus status;
  final String uploadedBy;
  final DateTime uploadedAt;
  final DateTime updatedAt;

  const DocumentModel({
    required this.id,
    required this.organizationId,
    required this.title,
    required this.description,
    required this.category,
    required this.fileUrl,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    this.status = DocumentStatus.active,
    required this.uploadedBy,
    required this.uploadedAt,
    required this.updatedAt,
  });

  factory DocumentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DocumentModel(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: DocumentCategory.values.firstWhere(
        (e) => e.name == (data['category'] ?? 'otherDocuments'),
        orElse: () => DocumentCategory.otherDocuments,
      ),
      fileUrl: data['fileUrl'] ?? '',
      fileName: data['fileName'] ?? '',
      fileSize: (data['fileSize'] as num?)?.toInt() ?? 0,
      mimeType: data['mimeType'] ?? 'application/octet-stream',
      status: DocumentStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'active'),
        orElse: () => DocumentStatus.active,
      ),
      uploadedBy: data['uploadedBy'] ?? '',
      uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      'title': title,
      'description': description,
      'category': category.name,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'status': status.name,
      'uploadedBy': uploadedBy,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  DocumentModel copyWith({
    String? id,
    String? organizationId,
    String? title,
    String? description,
    DocumentCategory? category,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? mimeType,
    DocumentStatus? status,
    String? uploadedBy,
    DateTime? uploadedAt,
    DateTime? updatedAt,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      status: status ?? this.status,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
