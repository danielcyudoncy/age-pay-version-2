import 'package:cloud_firestore/cloud_firestore.dart';

class MeetingModel {
  final String id;
  final String title;
  final DateTime meetingDate;
  final String? minutesText;
  final String? minutesFileUrl;
  final String? minutesFileName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  const MeetingModel({
    required this.id,
    required this.title,
    required this.meetingDate,
    this.minutesText,
    this.minutesFileUrl,
    this.minutesFileName,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  factory MeetingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MeetingModel(
      id: doc.id,
      title: data['title'] ?? '',
      meetingDate:
          (data['meetingDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      minutesText: data['minutesText'],
      minutesFileUrl: data['minutesFileUrl'],
      minutesFileName: data['minutesFileName'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'meetingDate': Timestamp.fromDate(meetingDate),
      'minutesText': minutesText,
      'minutesFileUrl': minutesFileUrl,
      'minutesFileName': minutesFileName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
    };
  }

  MeetingModel copyWith({
    String? title,
    DateTime? meetingDate,
    String? minutesText,
    String? minutesFileUrl,
    String? minutesFileName,
    DateTime? updatedAt,
  }) {
    return MeetingModel(
      id: id,
      title: title ?? this.title,
      meetingDate: meetingDate ?? this.meetingDate,
      minutesText: minutesText ?? this.minutesText,
      minutesFileUrl: minutesFileUrl ?? this.minutesFileUrl,
      minutesFileName: minutesFileName ?? this.minutesFileName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy,
    );
  }

  bool get hasMinutes =>
      (minutesText?.trim().isNotEmpty ?? false) ||
      (minutesFileUrl?.isNotEmpty ?? false);
}
