class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    this.orderId,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final String? orderId;
  final DateTime createdAt;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      isRead: json['is_read'] as bool? ?? false,
      orderId: json['order_id']?.toString(),
      createdAt:
          _parseDateTime(json['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'body': body,
      'type': type,
      'is_read': isRead,
      'order_id': orderId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}