import 'package:cloud_firestore/cloud_firestore.dart';

class MeetingModel {
  final String id;
  final String organizationId;
  final String title;
  final String venue;
  final DateTime meetingDate;
  final String? minutesText;
  final String? minutesFileUrl;
  final String? minutesFileName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String targetAudience; // 'all' | 'executives'
  final String scope; // 'national' | 'branch'
  final String? branchId;

  const MeetingModel({
    required this.id,
    this.organizationId = '',
    required this.title,
    this.venue = '',
    required this.meetingDate,
    this.minutesText,
    this.minutesFileUrl,
    this.minutesFileName,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.targetAudience = 'all',
    this.scope = 'branch',
    this.branchId,
  });

  factory MeetingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return MeetingModel(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      title: data['title'] ?? '',
      venue: data['venue'] ?? '',
      meetingDate:
          (data['meetingDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      minutesText: data['minutesText'],
      minutesFileUrl: data['minutesFileUrl'],
      minutesFileName: data['minutesFileName'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      targetAudience: data['targetAudience'] ?? 'all',
      scope: data['scope'] ?? 'branch',
      branchId: data['branchId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      'title': title,
      'venue': venue,
      'meetingDate': Timestamp.fromDate(meetingDate),
      'minutesText': minutesText,
      'minutesFileUrl': minutesFileUrl,
      'minutesFileName': minutesFileName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      'targetAudience': targetAudience,
      'scope': scope,
      if (branchId != null) 'branchId': branchId,
    };
  }

  MeetingModel copyWith({
    String? id,
    String? organizationId,
    String? title,
    String? venue,
    DateTime? meetingDate,
    String? minutesText,
    String? minutesFileUrl,
    String? minutesFileName,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? targetAudience,
    String? scope,
    String? branchId,
  }) {
    return MeetingModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      title: title ?? this.title,
      venue: venue ?? this.venue,
      meetingDate: meetingDate ?? this.meetingDate,
      minutesText: minutesText ?? this.minutesText,
      minutesFileUrl: minutesFileUrl ?? this.minutesFileUrl,
      minutesFileName: minutesFileName ?? this.minutesFileName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      targetAudience: targetAudience ?? this.targetAudience,
      scope: scope ?? this.scope,
      branchId: branchId ?? this.branchId,
    );
  }

  bool get hasMinutes =>
      (minutesText?.trim().isNotEmpty ?? false) ||
      (minutesFileUrl?.isNotEmpty ?? false);

  bool get isExecutivesOnly {
    final audience = targetAudience.trim().toLowerCase();
    if (audience == 'executives' || audience == 'executive') return true;
    final lowerTitle = title.trim().toLowerCase();
    if (lowerTitle.contains('executive meeting') ||
        lowerTitle.contains('executives only') ||
        lowerTitle.startsWith('executive')) {
      return true;
    }
    return false;
  }
}
