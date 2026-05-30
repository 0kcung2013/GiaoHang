import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/review_model.dart';

class ReviewService {
  ReviewService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const String _table = 'reviews';

  Future<void> createReview(ReviewModel review) async {
    try {
      final payload = Map<String, dynamic>.from(review.toJson());
      _removeEmptyGeneratedId(payload);

      await _supabase.from(_table).insert(payload);
    } catch (error) {
      throw Exception('Failed to create review: $error');
    }
  }

  Future<ReviewModel?> getReviewByOrderId(
    String orderId,
    String reviewerId,
  ) async {
    try {
      final response = await _supabase
          .from(_table)
          .select()
          .eq('order_id', orderId)
          .eq('reviewer_id', reviewerId)
          .maybeSingle();

      if (response == null) return null;
      return ReviewModel.fromJson(response);
    } catch (error) {
      throw Exception('Failed to load review by order id: $error');
    }
  }

  void _removeEmptyGeneratedId(Map<String, dynamic> json) {
    if ((json['id'] as String?)?.isEmpty ?? true) {
      json.remove('id');
    }
  }
}