class OrderStatusLogModel {
  const OrderStatusLogModel({
    required this.id,
    required this.orderId,
    required this.status,
    required this.title,
    this.description,
    this.loggedBy,
    required this.createdAt,
  });

  final String id;
  final String orderId;
  final String status;
  final String title;
  final String? description;
  final String? loggedBy;
  final DateTime createdAt;

  factory OrderStatusLogModel.fromJson(Map<String, dynamic> json) {
    return OrderStatusLogModel(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      loggedBy: json['logged_by']?.toString(),
      createdAt:
          _parseDateTime(json['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'status': status,
      'title': title,
      'description': description,
      'logged_by': loggedBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}