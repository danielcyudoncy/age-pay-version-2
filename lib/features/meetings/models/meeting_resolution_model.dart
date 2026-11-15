class MeetingResolutionModel {
  final String id;
  final String title;
  final String? assigneeName;
  final DateTime? dueDate;
  final bool isCompleted;
  final DateTime? completedAt;
  final String? completedBy;

  const MeetingResolutionModel({
    required this.id,
    required this.title,
    this.assigneeName,
    this.dueDate,
    this.isCompleted = false,
    this.completedAt,
    this.completedBy,
  });

  factory MeetingResolutionModel.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic raw) {
      if (raw == null) return null;
      if (raw is DateTime) return raw;
      if (raw.runtimeType.toString().contains('Timestamp')) {
        return (raw as dynamic).toDate();
      }
      if (raw is String) return DateTime.tryParse(raw);
      return null;
    }

    return MeetingResolutionModel(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      assigneeName: map['assigneeName'] as String?,
      dueDate: parseDate(map['dueDate']),
      isCompleted: map['isCompleted'] as bool? ?? false,
      completedAt: parseDate(map['completedAt']),
      completedBy: map['completedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      if (assigneeName != null && assigneeName!.isNotEmpty)
        'assigneeName': assigneeName,
      if (dueDate != null) 'dueDate': dueDate!.toIso8601String(),
      'isCompleted': isCompleted,
      if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      if (completedBy != null && completedBy!.isNotEmpty)
        'completedBy': completedBy,
    };
  }

  MeetingResolutionModel copyWith({
    String? id,
    String? title,
    String? assigneeName,
    DateTime? dueDate,
    bool? isCompleted,
    DateTime? completedAt,
    String? completedBy,
  }) {
    return MeetingResolutionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      assigneeName: assigneeName ?? this.assigneeName,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
    );
  }
}
