class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type; // 'levy', 'payment', 'reminder', 'general'
  final String? payload; // JSON string with extra data
  final DateTime receivedAt;
  final bool read;
  final String? imageUrl;

  final String organizationId;
  final String? targetRole;
  final String? targetUserId;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.payload,
    required this.receivedAt,
    this.read = false,
    this.imageUrl,
    this.organizationId = '',
    this.targetRole,
    this.targetUserId,
  });

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    String? type,
    String? payload,
    DateTime? receivedAt,
    bool? read,
    String? imageUrl,
    String? organizationId,
    String? targetRole,
    String? targetUserId,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      payload: payload ?? this.payload,
      receivedAt: receivedAt ?? this.receivedAt,
      read: read ?? this.read,
      imageUrl: imageUrl ?? this.imageUrl,
      organizationId: organizationId ?? this.organizationId,
      targetRole: targetRole ?? this.targetRole,
      targetUserId: targetUserId ?? this.targetUserId,
    );
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map, [String? id]) {
    final rawDate = map['receivedAt'] ?? map['createdAt'];
    final DateTime date;
    if (rawDate is DateTime) {
      date = rawDate;
    } else if (rawDate != null && rawDate.runtimeType.toString().contains('Timestamp')) {
      date = (rawDate as dynamic).toDate();
    } else if (rawDate is String) {
      date = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      date = DateTime.now();
    }

    return NotificationModel(
      id: id ?? map['id'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? 'general',
      payload: map['payload'],
      receivedAt: date,
      read: map['read'] ?? map['isRead'] ?? false,
      imageUrl: map['imageUrl'],
      organizationId: map['organizationId'] ?? '',
      targetRole: map['targetRole'],
      targetUserId: map['targetUserId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      if (payload != null) 'payload': payload,
      'receivedAt': receivedAt.toIso8601String(),
      'read': read,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'organizationId': organizationId,
      if (targetRole != null) 'targetRole': targetRole,
      if (targetUserId != null) 'targetUserId': targetUserId,
    };
  }
}
