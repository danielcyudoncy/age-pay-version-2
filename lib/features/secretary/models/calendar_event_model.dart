import 'package:cloud_firestore/cloud_firestore.dart';

enum CalendarEventType { meeting, contributionDeadline, communityEvent, birthday, holiday, reminder }

class CalendarEventModel {
  final String id;
  final String organizationId;
  final String title;
  final String description;
  final CalendarEventType type;
  final DateTime startDate;
  final DateTime endDate;
  final bool allDay;
  final String? location;
  final List<String> invitedMemberIds;
  final bool hasReminder;
  final DateTime? reminderAt;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CalendarEventModel({
    required this.id,
    required this.organizationId,
    required this.title,
    required this.description,
    required this.type,
    required this.startDate,
    required this.endDate,
    this.allDay = false,
    this.location,
    this.invitedMemberIds = const [],
    this.hasReminder = false,
    this.reminderAt,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CalendarEventModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CalendarEventModel(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      type: CalendarEventType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'event'),
        orElse: () => CalendarEventType.communityEvent,
      ),
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      allDay: data['allDay'] ?? false,
      location: data['location'],
      invitedMemberIds: List<String>.from(data['invitedMemberIds'] ?? []),
      hasReminder: data['hasReminder'] ?? false,
      reminderAt: data['reminderAt'] != null
          ? (data['reminderAt'] as Timestamp).toDate()
          : null,
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      'title': title,
      'description': description,
      'type': type.name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'allDay': allDay,
      'location': location,
      'invitedMemberIds': invitedMemberIds,
      'hasReminder': hasReminder,
      'reminderAt': reminderAt != null ? Timestamp.fromDate(reminderAt!) : null,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  CalendarEventModel copyWith({
    String? id,
    String? organizationId,
    String? title,
    String? description,
    CalendarEventType? type,
    DateTime? startDate,
    DateTime? endDate,
    bool? allDay,
    String? location,
    List<String>? invitedMemberIds,
    bool? hasReminder,
    DateTime? reminderAt,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CalendarEventModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      allDay: allDay ?? this.allDay,
      location: location ?? this.location,
      invitedMemberIds: invitedMemberIds ?? this.invitedMemberIds,
      hasReminder: hasReminder ?? this.hasReminder,
      reminderAt: reminderAt ?? this.reminderAt,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
