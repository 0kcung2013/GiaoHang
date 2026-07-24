import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/review_model.dart';

class ReviewService {
  ReviewService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const String _table = 'reviews';

  /// Khách → tài xế
  Future<Map<String, dynamic>> submitCustomerDriverReview({
    required String orderId,
    required int rating,
    String? comment,
    List<String> tags = const [],
  }) async {
    try {
      final result = await _supabase.rpc(
        'submit_customer_driver_review',
        params: {
          'p_order_id': orderId,
          'p_rating': rating,
          'p_comment': comment,
          'p_tags': tags,
        },
      );
      if (result is Map) return Map<String, dynamic>.from(result);
      return {'ok': true};
    } catch (error) {
      throw Exception('Không gửi được đánh giá: $error');
    }
  }

  /// Tài xế → khách
  Future<Map<String, dynamic>> submitDriverCustomerReview({
    required String orderId,
    required int rating,
    String? comment,
    List<String> tags = const [],
  }) async {
    try {
      final result = await _supabase.rpc(
        'submit_driver_customer_review',
        params: {
          'p_order_id': orderId,
          'p_rating': rating,
          'p_comment': comment,
          'p_tags': tags,
        },
      );
      if (result is Map) return Map<String, dynamic>.from(result);
      return {'ok': true};
    } catch (error) {
      throw Exception('Không gửi được đánh giá khách: $error');
    }
  }

  Future<ReviewModel?> getReviewByOrderId(
    String orderId, {
    String direction = ReviewDirection.customerToDriver,
  }) async {
    try {
      var query = _supabase
          .from(_table)
          .select()
          .eq('order_id', orderId)
          .eq('direction', direction);

      final response = await query.maybeSingle();
      if (response == null) return null;
      return ReviewModel.fromJson(response);
    } catch (error) {
      // Fallback schema cũ (chưa có cột direction)
      try {
        final response = await _supabase
            .from(_table)
            .select()
            .eq('order_id', orderId)
            .maybeSingle();
        if (response == null) return null;
        return ReviewModel.fromJson(response);
      } catch (_) {
        throw Exception('Failed to load review by order id: $error');
      }
    }
  }

  Future<void> createReview(ReviewModel review) async {
    await submitCustomerDriverReview(
      orderId: review.orderId,
      rating: review.rating,
      comment: review.comment,
      tags: review.tags,
    );
  }
}
