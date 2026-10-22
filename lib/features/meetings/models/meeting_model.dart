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
    );
  }

  bool get hasMinutes =>
      (minutesText?.trim().isNotEmpty ?? false) ||
      (minutesFileUrl?.isNotEmpty ?? false);

  bool get isExecutivesOnly => targetAudience == 'executives';
}
