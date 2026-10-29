import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/review_history_repository.dart';
import '../models/review_history_entry.dart';

final reviewHistoryRepositoryProvider = Provider<ReviewHistoryRepository>(
  (ref) => SupabaseReviewHistoryRepository(Supabase.instance.client),
);

final reviewHistoryProvider =
    StateNotifierProvider.autoDispose<
      ReviewHistoryController,
      ReviewHistoryState
    >(
      (ref) =>
          ReviewHistoryController(ref.watch(reviewHistoryRepositoryProvider)),
    );

class ReviewHistoryState {
  const ReviewHistoryState({
    this.entries = const [],
    this.rating,
    this.loading = true,
    this.loadingMore = false,
    this.hasMore = false,
    this.failed = false,
  });

  final List<ReviewHistoryEntry> entries;
  final int? rating;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final bool failed;
}

class ReviewHistoryController extends StateNotifier<ReviewHistoryState> {
  ReviewHistoryController(this.repository) : super(const ReviewHistoryState()) {
    refresh();
  }

  final ReviewHistoryRepository repository;
  int _revision = 0;
  int _offset = 0;

  Future<void> refresh() => _load(rating: state.rating);

  Future<void> selectRating(int? rating) async {
    if (state.rating == rating) return;
    await _load(rating: rating);
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    await _load(rating: state.rating, more: true);
  }

  Future<void> retry() => state.entries.isEmpty ? refresh() : loadMore();

  Future<void> _load({int? rating, bool more = false}) async {
    final revision = ++_revision;
    final previous = more ? state.entries : <ReviewHistoryEntry>[];
    if (!more) _offset = 0;
    state = ReviewHistoryState(
      entries: previous,
      rating: rating,
      loading: !more,
      loadingMore: more,
      hasMore: more,
    );
    try {
      final rows = await repository.fetch(rating: rating, offset: _offset);
      if (!mounted || revision != _revision) return;
      _offset += rows.length;
      state = ReviewHistoryState(
        entries: List.unmodifiable(
          {
            for (final entry in [...previous, ...rows]) entry.review.id: entry,
          }.values,
        ),
        rating: rating,
        loading: false,
        hasMore: rows.length == ReviewHistoryRepository.pageSize,
      );
    } catch (_) {
      if (!mounted || revision != _revision) return;
      state = ReviewHistoryState(
        entries: previous,
        rating: rating,
        loading: false,
        hasMore: more,
        failed: true,
      );
    }
  }
}
