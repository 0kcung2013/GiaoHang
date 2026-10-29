import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/review_model.dart';

/// Thông báo có thể hiển thị trực tiếp, không chứa chi tiết lỗi database.
class ReviewException implements Exception {
  const ReviewException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ReviewService {
  ReviewService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;
  static const maxCommentLength = 500;
  static const requestTimeout = Duration(seconds: 15);
  static const submitError =
      'Chưa xác nhận được đánh giá. Vui lòng kiểm tra kết nối và thử lại.';
  static const loadError =
      'Không tải được trạng thái đánh giá. Vui lòng thử lại.';

  Future<Map<String, dynamic>> submitCustomerDriverReview({
    required String orderId,
    required int rating,
    String? comment,
    List<String> tags = const [],
  }) =>
      _submit(orderId, ReviewDirection.customerToDriver, rating, comment, tags);

  Future<Map<String, dynamic>> submitDriverCustomerReview({
    required String orderId,
    required int rating,
    String? comment,
    List<String> tags = const [],
  }) =>
      _submit(orderId, ReviewDirection.driverToCustomer, rating, comment, tags);

  Future<Map<String, dynamic>> _submit(
    String orderId,
    String direction,
    int rating,
    String? comment,
    List<String> tags,
  ) async {
    final actor = _actor();
    final options = _options(direction);
    final text = comment?.trim();
    if (orderId.trim().isEmpty || rating < 1 || rating > 5) {
      throw const ReviewException('Vui lòng chọn số sao từ 1 đến 5.');
    }
    if ((text?.runes.length ?? 0) > maxCommentLength) {
      throw const ReviewException('Nhận xét tối đa 500 ký tự.');
    }
    if (tags.any((id) => !options.any((option) => option.id == id))) {
      throw const ReviewException('Nhãn đánh giá không hợp lệ.');
    }
    try {
      final result = await _supabase
          .rpc(
            direction == ReviewDirection.customerToDriver
                ? 'submit_customer_driver_review'
                : 'submit_driver_customer_review',
            params: {
              'p_order_id': orderId,
              'p_rating': rating,
              'p_comment': text == null || text.isEmpty ? null : text,
              'p_tags': tags.toSet().toList(),
            },
          )
          .timeout(requestTimeout);
      if (_actor() != actor ||
          result is! Map ||
          result['ok'] == false ||
          result['review_id'] is! String ||
          (result['review_id'] as String).trim().isEmpty ||
          result['direction'] != direction ||
          result['rating'] is! int ||
          (result['rating'] as int) < 1 ||
          (result['rating'] as int) > 5 ||
          (result['rating'] != rating && result['already_reviewed'] != true)) {
        throw const ReviewException(submitError);
      }
      return Map<String, dynamic>.from(result);
    } on Exception {
      // RPC có thể đã commit trước khi phản hồi bị mất. Chỉ xác nhận lại đúng
      // người gửi và chiều đánh giá, không ghi đè điểm đã lưu khi gửi lại.
      if (_supabase.auth.currentUser?.id == actor) {
        try {
          final existing = await getReviewByOrderId(
            orderId,
            direction: direction,
          );
          if (existing != null && _supabase.auth.currentUser?.id == actor) {
            return {
              'review_id': existing.id,
              'direction': existing.direction,
              'rating': existing.rating,
              'already_reviewed': true,
            };
          }
        } on Exception {
          // Giữ lỗi an toàn và cho phép thử lại sau khi kết nối phục hồi.
        }
      }
      throw const ReviewException(submitError);
    }
  }

  Future<ReviewModel?> getReviewByOrderId(
    String orderId, {
    String direction = ReviewDirection.customerToDriver,
  }) async {
    final actor = _actor();
    _options(direction);
    try {
      final row = await _supabase
          .from('reviews')
          .select()
          .eq('order_id', orderId)
          .eq('direction', direction)
          .eq('reviewer_id', actor)
          .maybeSingle()
          .timeout(requestTimeout);
      if (_supabase.auth.currentUser?.id != actor) {
        throw const ReviewException(loadError);
      }
      if (row == null) return null;
      final review = ReviewModel.fromJson(row);
      if (review.id.isEmpty ||
          review.orderId != orderId ||
          review.direction != direction ||
          review.reviewerId != actor ||
          review.rating < 1 ||
          review.rating > 5) {
        throw const ReviewException(loadError);
      }
      return review;
    } on Exception {
      throw const ReviewException(loadError);
    }
  }

  Future<void> createReview(ReviewModel review) async {
    await _submit(
      review.orderId,
      review.direction,
      review.rating,
      review.comment,
      review.tags,
    );
  }

  String _actor() {
    final id = _supabase.auth.currentUser?.id;
    if (id == null) {
      throw const ReviewException('Vui lòng đăng nhập lại để đánh giá.');
    }
    return id;
  }

  List<ReviewTagOption> _options(String direction) => switch (direction) {
    ReviewDirection.customerToDriver => customerDriverReviewTags,
    ReviewDirection.driverToCustomer => driverCustomerReviewTags,
    _ => throw const ReviewException('Chiều đánh giá không hợp lệ.'),
  };
}
