import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_mobile/features/reviews/history/models/review_history_entry.dart';
import 'package:giaohang_mobile/features/reviews/history/providers/review_history_provider.dart';

import 'helpers/review_history_fixtures.dart';

void main() {
  test(
    'a slow previous filter cannot replace the newly selected rating',
    () async {
      final pending = Completer<List<ReviewHistoryEntry>>();
      final repository = FakeReviewHistoryRepository()
        ..onFetch = (rating, _) async => rating == null
            ? pending.future
            : [reviewHistoryFixture(rating: rating)];
      final controller = ReviewHistoryController(repository);
      addTearDown(controller.dispose);
      await controller.selectRating(1);
      pending.complete([reviewHistoryFixture()]);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.rating, 1);
      expect(controller.state.entries.single.review.rating, 1);
    },
  );

  test(
    'failed pagination retains entries and retries the same offset once',
    () async {
      final repository = FakeReviewHistoryRepository()
        ..entries = List.generate(
          21,
          (index) => reviewHistoryFixture(index: index),
        );
      final controller = ReviewHistoryController(repository);
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.entries, hasLength(20));
      repository.fail = true;
      await controller.loadMore();
      expect(controller.state.failed, isTrue);
      expect(controller.state.entries, hasLength(20));
      repository.fail = false;
      await Future.wait([controller.retry(), controller.loadMore()]);
      expect(controller.state.entries, hasLength(21));
      expect(controller.state.hasMore, isFalse);
      expect(repository.calls.map((call) => call.offset), [0, 20, 20]);
    },
  );

  test(
    'refresh keeps the selected filter and restarts at the first page',
    () async {
      final repository = FakeReviewHistoryRepository();
      final controller = ReviewHistoryController(repository);
      addTearDown(controller.dispose);
      await controller.selectRating(4);
      await controller.refresh();
      expect(repository.calls.last, (rating: 4, offset: 0));
      expect(controller.state.entries.single.review.rating, 4);
    },
  );
}
