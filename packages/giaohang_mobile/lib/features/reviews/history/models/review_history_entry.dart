import '../../../../core/models/review_model.dart';

/// Dữ liệu hiển thị lịch sử; không nạp toàn bộ đơn hàng cho từng đánh giá.
class ReviewHistoryEntry {
  const ReviewHistoryEntry({
    required this.review,
    this.trackingCode,
    this.deliveryAddress,
  });

  final ReviewModel review;
  final String? trackingCode;
  final String? deliveryAddress;

  factory ReviewHistoryEntry.fromJson(Map<String, dynamic> json) {
    final order = json['order'] as Map<String, dynamic>?;
    return ReviewHistoryEntry(
      review: ReviewModel.fromJson(json),
      trackingCode: order?['tracking_code'] as String?,
      deliveryAddress: order?['delivery_address'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    ...review.toJson(),
    'order': {
      'tracking_code': trackingCode,
      'delivery_address': deliveryAddress,
    },
  };
}
