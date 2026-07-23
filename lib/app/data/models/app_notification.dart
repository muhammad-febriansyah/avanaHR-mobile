class AppNotification {
  final int id;
  final String type;
  final Map<String, dynamic> payload;
  final bool isRead;
  final String? createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.payload,
    required this.isRead,
    this.createdAt,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        payload: payload,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );

  /// Best-effort human title from the notification payload.
  String get title {
    if (payload['title'] is String) return payload['title'];
    if (payload['message'] is String) return payload['message'];
    return type.replaceAll('.', ' ');
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'],
        type: json['type'] ?? '',
        payload: json['payload'] is Map ? Map<String, dynamic>.from(json['payload']) : {},
        isRead: json['is_read'] ?? false,
        createdAt: json['created_at'],
      );
}
