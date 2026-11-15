import 'package:cloud_firestore/cloud_firestore.dart';
import 'meeting_resolution_model.dart';

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

  // Minutes Adoption Protocol
  final bool isAdopted;
  final DateTime? adoptedAt;
  final String? movedBy;
  final String? secondedBy;
  final String? adoptionNotes;

  // Resolutions & Matters Arising
  final List<MeetingResolutionModel> resolutions;

  // Sitting Dues / Contributions
  final double sittingDuesAmount;

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
    this.isAdopted = false,
    this.adoptedAt,
    this.movedBy,
    this.secondedBy,
    this.adoptionNotes,
    this.resolutions = const [],
    this.sittingDuesAmount = 0.0,
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
      isAdopted: data['isAdopted'] as bool? ?? false,
      adoptedAt: (data['adoptedAt'] as Timestamp?)?.toDate(),
      movedBy: data['movedBy'] as String?,
      secondedBy: data['secondedBy'] as String?,
      adoptionNotes: data['adoptionNotes'] as String?,
      resolutions: (data['resolutions'] as List<dynamic>?)
              ?.map((e) =>
                  MeetingResolutionModel.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      sittingDuesAmount:
          (data['sittingDuesAmount'] as num?)?.toDouble() ?? 0.0,
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
      'isAdopted': isAdopted,
      if (adoptedAt != null) 'adoptedAt': Timestamp.fromDate(adoptedAt!),
      if (movedBy != null && movedBy!.isNotEmpty) 'movedBy': movedBy,
      if (secondedBy != null && secondedBy!.isNotEmpty)
        'secondedBy': secondedBy,
      if (adoptionNotes != null && adoptionNotes!.isNotEmpty)
        'adoptionNotes': adoptionNotes,
      'resolutions': resolutions.map((r) => r.toMap()).toList(),
      'sittingDuesAmount': sittingDuesAmount,
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
    bool? isAdopted,
    DateTime? adoptedAt,
    String? movedBy,
    String? secondedBy,
    String? adoptionNotes,
    List<MeetingResolutionModel>? resolutions,
    double? sittingDuesAmount,
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
      isAdopted: isAdopted ?? this.isAdopted,
      adoptedAt: adoptedAt ?? this.adoptedAt,
      movedBy: movedBy ?? this.movedBy,
      secondedBy: secondedBy ?? this.secondedBy,
      adoptionNotes: adoptionNotes ?? this.adoptionNotes,
      resolutions: resolutions ?? this.resolutions,
      sittingDuesAmount: sittingDuesAmount ?? this.sittingDuesAmount,
    );
  }

  bool get hasMinutes =>
      (minutesText?.trim().isNotEmpty ?? false) ||
      (minutesFileUrl?.isNotEmpty ?? false);

  bool get isNational => scope == 'national' || branchId == 'national';

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

  /// True if a positive sitting dues amount has been assigned to this sitting.
  bool get hasSittingDues => sittingDuesAmount > 0;

  /// The sitting dues payment window opens 10 minutes before the scheduled meeting.
  DateTime get sittingDuesOpenTime =>
      meetingDate.subtract(const Duration(minutes: 10));

  /// The sitting dues payment window closes at 12:00 Midnight of the meeting day.
  DateTime get sittingDuesCloseTime =>
      DateTime(meetingDate.year, meetingDate.month, meetingDate.day, 23, 59, 59);

  /// True if the current time is within the active sitting dues window
  /// (between 10 minutes before the meeting and 12:00 Midnight).
  bool isSittingDuesWindowOpen([DateTime? now]) {
    if (!hasSittingDues) return false;
    final current = now ?? DateTime.now();
    return !current.isBefore(sittingDuesOpenTime) &&
        !current.isAfter(sittingDuesCloseTime);
  }

  /// True if the current time is still prior to the 10-minute pre-meeting window.
  bool isSittingDuesUpcoming([DateTime? now]) {
    if (!hasSittingDues) return false;
    final current = now ?? DateTime.now();
    return current.isBefore(sittingDuesOpenTime);
  }

  /// True if the meeting day has ended (after 12:00 Midnight) and collection is locked.
  bool isSittingDuesClosed([DateTime? now]) {
    if (!hasSittingDues) return false;
    final current = now ?? DateTime.now();
    return current.isAfter(sittingDuesCloseTime);
  }
}
