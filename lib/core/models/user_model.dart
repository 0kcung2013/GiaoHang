class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    required this.role,
    this.avatarUrl,
    required this.createdAt,
    required this.preferredPaymentMethod,
    required this.notificationOrderUpdates,
    required this.notificationPromotions,
  });

  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String role;
  final String? avatarUrl;
  final DateTime createdAt;
  final String preferredPaymentMethod;
  final bool notificationOrderUpdates;
  final bool notificationPromotions;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      phone: json['phone']?.toString(),
      role: json['role']?.toString() ?? 'customer',
      avatarUrl: json['avatar_url']?.toString(),
      createdAt:
          _parseDateTime(json['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      preferredPaymentMethod:
          json['preferred_payment_method']?.toString() ?? 'cash',
      notificationOrderUpdates: json['notification_order_updates'] as bool? ?? true,
      notificationPromotions: json['notification_promotions'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'role': role,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
      'preferred_payment_method': preferredPaymentMethod,
      'notification_order_updates': notificationOrderUpdates,
      'notification_promotions': notificationPromotions,
    };
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.tryParse(value.toString());
  }
}