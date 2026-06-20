class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type; // 'levy', 'payment', 'reminder', 'general'
  final String? payload; // JSON string with extra data
  final DateTime receivedAt;
  final bool read;
  final String? imageUrl;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.payload,
    required this.receivedAt,
    this.read = false,
    this.imageUrl,
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
    );
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? 'general',
      payload: map['payload'],
      receivedAt: map['receivedAt'] is DateTime
          ? map['receivedAt']
          : DateTime.tryParse(map['receivedAt'] ?? '') ?? DateTime.now(),
      read: map['read'] ?? false,
      imageUrl: map['imageUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'payload': payload,
      'receivedAt': receivedAt.toIso8601String(),
      'read': read,
      'imageUrl': imageUrl,
    };
  }
}
