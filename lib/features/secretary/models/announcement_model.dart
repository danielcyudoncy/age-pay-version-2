import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/enums.dart';

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
  final String? targetBranchId;
  final String? targetBranchName;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isExecutivesOnly {
    final audience = targetAudience.trim().toLowerCase();
    if (audience == 'executives' ||
        audience == 'executive' ||
        audience == 'allexecutives' ||
        audience == 'all_executives' ||
        audience == 'branchexecutives' ||
        audience == 'branch_executives' ||
        audience == 'nationalexecutives' ||
        audience == 'national_executives') {
      return true;
    }
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

  String get audienceLabel {
    final audience = targetAudience.trim().toLowerCase();
    final branch = (targetBranchName != null && targetBranchName!.isNotEmpty)
        ? targetBranchName!
        : 'Branch';
    if (audience == 'nationalexecutives' || audience == 'national_executives') {
      return 'National Executives';
    } else if (audience == 'allexecutives' ||
        audience == 'all_executives' ||
        audience == 'executives' ||
        audience == 'executive') {
      return 'All Executives';
    } else if (audience == 'branchexecutives' ||
        audience == 'branch_executives') {
      return '$branch (Executives)';
    } else if (audience == 'branch') {
      return '$branch (All Members)';
    } else if (targetBranchName != null && targetBranchName!.isNotEmpty) {
      return targetBranchName!;
    }
    return 'Everyone';
  }

  bool isVisibleTo(dynamic user) {
    if (user == null) return false;

    final String? userBranchId = user.branchId as String?;
    final String? userBranchName = user.branchName as String?;
    final bool isUserExec = (user.isExecutive == true);
    final bool isNationalExec = (user.isNationalExecutive == true);
    bool isSuperAdmin = false;
    try {
      isSuperAdmin = user.role == UserRole.superAdmin ||
          user.role?.toString() == 'UserRole.superAdmin' ||
          user.role?.toString() == 'superAdmin';
    } catch (_) {}

    final effectiveTargetBranchId = targetBranchId?.trim();
    final effectiveTargetBranchName = targetBranchName?.trim();

    // 1. Strict branch boundary:
    // If announcement is targeted to a specific branch, a member of another branch
    // must NEVER see it, even if they are superAdmin or the creator.
    if (effectiveTargetBranchId != null &&
        effectiveTargetBranchId.isNotEmpty &&
        userBranchId != null &&
        userBranchId.isNotEmpty &&
        userBranchId != effectiveTargetBranchId) {
      return false;
    }

    if (effectiveTargetBranchName != null &&
        effectiveTargetBranchName.isNotEmpty &&
        userBranchName != null &&
        userBranchName.isNotEmpty &&
        userBranchName.toLowerCase() != effectiveTargetBranchName.toLowerCase()) {
      return false;
    }

    final audience = targetAudience.trim().toLowerCase();

    // 2. Meeting announcements boundary:
    // Meeting announcements are strictly branch-scoped unless explicitly targeted to national or all executives.
    final bool isMeetingAnnouncement =
        category == AnnouncementCategory.meeting ||
            title.startsWith('📅 Upcoming Meeting:') ||
            title.startsWith('🏛️ Executive Meeting:') ||
            title.toLowerCase().contains('upcoming meeting') ||
            title.toLowerCase().contains('executive meeting') ||
            title.toLowerCase().contains('branch meeting') ||
            body.toLowerCase().contains('meeting session has been scheduled');

    if (isMeetingAnnouncement) {
      final isExplicitNational = audience == 'national' ||
          audience == 'nationalexecutives' ||
          audience == 'national_executives' ||
          audience == 'allexecutives' ||
          audience == 'all_executives';

      if (!isExplicitNational) {
        // If user belongs to a branch, the meeting announcement MUST belong to their branch:
        if (userBranchId != null && userBranchId.isNotEmpty) {
          if (effectiveTargetBranchId == null ||
              effectiveTargetBranchId.isEmpty ||
              effectiveTargetBranchId != userBranchId) {
            return false;
          }
        } else {
          // If user has no branch assignment, local meeting announcements are not visible:
          return false;
        }
      }
    }

    // 3. National Executives only
    if (audience == 'nationalexecutives' || audience == 'national_executives') {
      return isNationalExec || (isSuperAdmin && userBranchId == null);
    }

    // 4. All Executives
    if (audience == 'allexecutives' ||
        audience == 'all_executives' ||
        audience == 'executives' ||
        audience == 'executive') {
      return isUserExec || isNationalExec;
    }

    // 5. Specific Branch Executives
    if (audience == 'branchexecutives' || audience == 'branch_executives') {
      if (effectiveTargetBranchId != null &&
          effectiveTargetBranchId.isNotEmpty) {
        return userBranchId == effectiveTargetBranchId && isUserExec;
      }
      if (userBranchId != null &&
          userBranchId.isNotEmpty &&
          createdBy.isNotEmpty &&
          createdBy != user.uid) {
        return false;
      }
      return isUserExec;
    }

    // 6. Specific Branch (All members in branch)
    if (audience == 'branch') {
      if (effectiveTargetBranchId != null &&
          effectiveTargetBranchId.isNotEmpty) {
        return userBranchId == effectiveTargetBranchId;
      }
      if (userBranchId != null &&
          userBranchId.isNotEmpty &&
          createdBy.isNotEmpty &&
          createdBy != user.uid) {
        return false;
      }
      return true;
    }

    // 7. If target branch is set on general audience
    if (effectiveTargetBranchId != null &&
        effectiveTargetBranchId.isNotEmpty) {
      if (userBranchId != effectiveTargetBranchId) return false;
    }

    // 8. Super admin / creator bypass for remaining non-branch-mismatched announcements
    if (isSuperAdmin &&
        (userBranchId == null ||
            effectiveTargetBranchId == userBranchId)) {
      return true;
    }

    if (createdBy.isNotEmpty &&
        createdBy == user.uid &&
        (effectiveTargetBranchId == null ||
            effectiveTargetBranchId == userBranchId)) {
      return true;
    }

    // 9. Legacy heuristic check
    if (isExecutivesOnly && !isUserExec && !isNationalExec) {
      return false;
    }

    return true;
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
    this.targetBranchId,
    this.targetBranchName,
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
      targetBranchId:
          (data['targetBranchId'] ?? data['branchId']) as String?,
      targetBranchName:
          (data['targetBranchName'] ?? data['branchName']) as String?,
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
      if (targetBranchId != null) 'targetBranchId': targetBranchId,
      if (targetBranchName != null) 'targetBranchName': targetBranchName,
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
    String? targetBranchId,
    String? targetBranchName,
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
      targetBranchId: targetBranchId ?? this.targetBranchId,
      targetBranchName: targetBranchName ?? this.targetBranchName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
