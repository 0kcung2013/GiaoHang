class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.orderId,
    required this.reviewerId,
    required this.driverId,
    this.revieweeId,
    this.direction = ReviewDirection.customerToDriver,
    required this.rating,
    this.comment,
    this.tags = const [],
    required this.createdAt,
  });

  final String id;
  final String orderId;
  final String reviewerId;
  final String driverId;
  final String? revieweeId;
  final String direction;
  final int rating;
  final String? comment;
  final List<String> tags;
  final DateTime createdAt;

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      reviewerId: json['reviewer_id']?.toString() ?? '',
      driverId: json['driver_id']?.toString() ?? '',
      revieweeId: json['reviewee_id']?.toString(),
      direction:
          json['direction']?.toString() ?? ReviewDirection.customerToDriver,
      rating: _parseInt(json['rating']) ?? 0,
      comment: json['comment']?.toString(),
      tags: _parseTags(json['tags']),
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
      'reviewee_id': revieweeId,
      'direction': direction,
      'rating': rating,
      'comment': comment,
      'tags': tags,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static List<String> _parseTags(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
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

class ReviewDirection {
  static const customerToDriver = 'customer_to_driver';
  static const driverToCustomer = 'driver_to_customer';
}

class ReviewTagOption {
  const ReviewTagOption({required this.id, required this.label});
  final String id;
  final String label;
}

const customerDriverReviewTags = <ReviewTagOption>[
  ReviewTagOption(id: 'on_time', label: 'Đúng giờ'),
  ReviewTagOption(id: 'friendly', label: 'Thân thiện'),
  ReviewTagOption(id: 'careful', label: 'Cẩn thận với hàng'),
  ReviewTagOption(id: 'easy_contact', label: 'Dễ liên lạc'),
  ReviewTagOption(id: 'a_bit_late', label: 'Hơi trễ'),
  ReviewTagOption(id: 'bad_attitude', label: 'Thái độ chưa tốt'),
];

const driverCustomerReviewTags = <ReviewTagOption>[
  ReviewTagOption(id: 'polite', label: 'Lịch sự'),
  ReviewTagOption(id: 'on_time', label: 'Đúng hẹn'),
  ReviewTagOption(id: 'easy_find', label: 'Dễ tìm'),
  ReviewTagOption(id: 'clear_address', label: 'Địa chỉ rõ'),
  ReviewTagOption(id: 'no_answer', label: 'Không nghe máy'),
  ReviewTagOption(id: 'wrong_address', label: 'Địa chỉ sai'),
];
