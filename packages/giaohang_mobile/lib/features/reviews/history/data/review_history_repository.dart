import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/models/review_model.dart';
import '../../../../core/services/review_service.dart';
import '../models/review_history_entry.dart';
import '../review_history_strings.dart';

abstract interface class ReviewHistoryRepository {
  static const pageSize = 20;

  Future<List<ReviewHistoryEntry>> fetch({int? rating, int offset = 0});
}

class SupabaseReviewHistoryRepository implements ReviewHistoryRepository {
  SupabaseReviewHistoryRepository(this.client);

  final SupabaseClient client;

  @override
  Future<List<ReviewHistoryEntry>> fetch({int? rating, int offset = 0}) async {
    final actor = client.auth.currentUser?.id;
    if (actor == null ||
        offset < 0 ||
        (rating != null && (rating < 1 || rating > 5))) {
      throw const ReviewException(ReviewHistoryStrings.loadError);
    }
    try {
      var query = client
          .from('reviews')
          .select(
            'id,order_id,reviewer_id,driver_id,reviewee_id,direction,'
            'rating,comment,tags,created_at,'
            'order:orders!reviews_order_id_fkey(tracking_code,delivery_address)',
          )
          .eq('reviewer_id', actor)
          .eq('direction', ReviewDirection.customerToDriver);
      if (rating != null) query = query.eq('rating', rating);
      final rows = await query
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .range(offset, offset + ReviewHistoryRepository.pageSize - 1)
          .timeout(ReviewService.requestTimeout);
      if (client.auth.currentUser?.id != actor) {
        throw const ReviewException(ReviewHistoryStrings.loadError);
      }
      final entries = rows.map(ReviewHistoryEntry.fromJson).toList();
      if (entries.any((entry) {
        final review = entry.review;
        return review.id.isEmpty ||
            review.orderId.isEmpty ||
            review.reviewerId != actor ||
            review.direction != ReviewDirection.customerToDriver ||
            review.rating < 1 ||
            review.rating > 5 ||
            (rating != null && review.rating != rating);
      })) {
        throw const ReviewException(ReviewHistoryStrings.loadError);
      }
      return entries;
    } on Exception {
      throw const ReviewException(ReviewHistoryStrings.loadError);
    }
  }
}
