import 'package:cloud_firestore/cloud_firestore.dart';

enum AnnouncementCategory {
  general,
  emergency,
  contribution,
  meeting,
  event,
  election,
  financialNotice,
}

class AnnouncementModel {
  final String id;
  final String organizationId;
  final String title;
  final String body;
  final AnnouncementCategory category;
  final bool isPinned;
  final bool isScheduled;
  final DateTime? scheduledAt;
  final DateTime? announcementDate;
  final List<String> attachments;
  final String createdBy;
  final String targetAudience;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isExecutivesOnly {
    final audience = targetAudience.trim().toLowerCase();
    if (audience == 'executives' || audience == 'executive') return true;
    final lowerTitle = title.trim().toLowerCase();
    if (lowerTitle.contains('executive meeting') ||
        lowerTitle.contains('executives only') ||
        lowerTitle.contains('🏛️ executive') ||
        lowerTitle.contains('executive committee')) {
      return true;
    }
    final lowerBody = body.trim().toLowerCase();
    if (lowerBody.contains('executive meeting session') ||
        lowerBody.contains('all executive officers') ||
        lowerBody.contains('for all executive members')) {
      return true;
    }
    return false;
  }

  const AnnouncementModel({
    required this.id,
    required this.organizationId,
    required this.title,
    required this.body,
    required this.category,
    this.isPinned = false,
    this.isScheduled = false,
    this.scheduledAt,
    this.announcementDate,
    this.attachments = const [],
    required this.createdBy,
    this.targetAudience = 'all',
    required this.createdAt,
    required this.updatedAt,
  });

  factory AnnouncementModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AnnouncementModel(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      category: AnnouncementCategory.values.firstWhere(
        (e) => e.name == (data['category'] ?? 'general'),
        orElse: () => AnnouncementCategory.general,
      ),
      isPinned: data['isPinned'] ?? false,
      isScheduled: data['isScheduled'] ?? false,
      scheduledAt: data['scheduledAt'] != null
          ? (data['scheduledAt'] as Timestamp).toDate()
          : null,
      announcementDate: data['announcementDate'] != null
          ? (data['announcementDate'] as Timestamp).toDate()
          : null,
      attachments: List<String>.from(data['attachments'] ?? []),
      createdBy: data['createdBy'] ?? '',
      targetAudience: data['targetAudience'] ?? 'all',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      'title': title,
      'body': body,
      'category': category.name,
      'isPinned': isPinned,
      'isScheduled': isScheduled,
      'scheduledAt': scheduledAt != null ? Timestamp.fromDate(scheduledAt!) : null,
      'announcementDate': announcementDate != null
          ? Timestamp.fromDate(announcementDate!)
          : null,
      'attachments': attachments,
      'createdBy': createdBy,
      'targetAudience': targetAudience,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  AnnouncementModel copyWith({
    String? id,
    String? organizationId,
    String? title,
    String? body,
    AnnouncementCategory? category,
    bool? isPinned,
    bool? isScheduled,
    DateTime? scheduledAt,
    DateTime? announcementDate,
    List<String>? attachments,
    String? createdBy,
    String? targetAudience,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AnnouncementModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      isPinned: isPinned ?? this.isPinned,
      isScheduled: isScheduled ?? this.isScheduled,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      announcementDate: announcementDate ?? this.announcementDate,
      attachments: attachments ?? this.attachments,
      createdBy: createdBy ?? this.createdBy,
      targetAudience: targetAudience ?? this.targetAudience,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
