import 'package:giaohang_mobile/core/models/review_model.dart';
import 'package:giaohang_mobile/features/reviews/history/data/review_history_repository.dart';
import 'package:giaohang_mobile/features/reviews/history/models/review_history_entry.dart';

ReviewHistoryEntry reviewHistoryFixture({int index = 0, int rating = 5}) =>
    ReviewHistoryEntry(
      review: ReviewModel(
        id: 'review-$index',
        orderId: 'order-$index',
        reviewerId: 'actor-1',
        driverId: 'driver-1',
        rating: rating,
        comment: index == 0
            ? 'Tài xế giao đúng hẹn, hàng được giữ cẩn thận. Cảm ơn anh!'
            : 'Dễ liên lạc, giao hàng nhanh chóng.',
        tags: index == 0 ? ['on_time', 'careful'] : ['easy_contact'],
        createdAt: DateTime(2026, 10, 27 - index, 14, 30),
      ),
      trackingCode: 'GH${260102700 - index}',
      deliveryAddress: index == 0
          ? '12 Nguyễn Huệ, Bến Nghé, Quận 1, TP. Hồ Chí Minh'
          : '89 Lê Văn Sỹ, Phường 13, Quận 3, TP. Hồ Chí Minh',
    );

class FakeReviewHistoryRepository implements ReviewHistoryRepository {
  List<ReviewHistoryEntry> entries = [
    reviewHistoryFixture(),
    reviewHistoryFixture(index: 1, rating: 4),
  ];
  bool fail = false;
  final calls = <({int? rating, int offset})>[];
  Future<List<ReviewHistoryEntry>> Function(int? rating, int offset)? onFetch;

  @override
  Future<List<ReviewHistoryEntry>> fetch({int? rating, int offset = 0}) async {
    calls.add((rating: rating, offset: offset));
    if (onFetch != null) return onFetch!(rating, offset);
    if (fail) throw Exception('Offline');
    return entries
        .where((entry) => rating == null || entry.review.rating == rating)
        .skip(offset)
        .take(ReviewHistoryRepository.pageSize)
        .toList();
  }
}
