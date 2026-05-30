class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.orderId,
    required this.reviewerId,
    required this.driverId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  final String id;
  final String orderId;
  final String reviewerId;
  final String driverId;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      reviewerId: json['reviewer_id']?.toString() ?? '',
      driverId: json['driver_id']?.toString() ?? '',
      rating: _parseInt(json['rating']) ?? 0,
      comment: json['comment']?.toString(),
      createdAt:
          _parseDateTime(json['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'reviewer_id': reviewerId,
      'driver_id': driverId,
      'rating': rating,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}