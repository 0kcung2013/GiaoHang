import '../../risk_reports/models/risk_journey.dart';
import '../../support_orders/models/support_order.dart';
import '../models/archived_journey_order.dart';
import 'journey_archive_repository.dart';

/// In-memory cache owned by one monitoring screen, not shared across users.
/// Retain a few recently opened orders and coalesce in-flight requests.
class CachedJourneyArchiveRepository implements JourneyArchiveRepository {
  CachedJourneyArchiveRepository(this.delegate, {this.capacity = 8});
  final JourneyArchiveRepository delegate;
  final int capacity;
  final _journeys = <String, Future<RiskJourney>>{};
  final _events = <String, Future<List<SupportOrderStatusLog>>>{};

  void invalidate(String orderId) {
    _journeys.remove(orderId);
    _events.remove(orderId);
  }

  @override
  Future<List<ArchivedJourneyOrder>> fetchArchives() =>
      delegate.fetchArchives();
  @override
  Future<RiskJourney> fetchJourney(String orderId) =>
      _read(_journeys, orderId, () => delegate.fetchJourney(orderId));
  @override
  Future<List<SupportOrderStatusLog>> fetchEvents(String orderId) =>
      _read(_events, orderId, () => delegate.fetchEvents(orderId));

  Future<T> _read<T>(
    Map<String, Future<T>> cache,
    String id,
    Future<T> Function() load,
  ) {
    final existing = cache.remove(id);
    if (existing != null) {
      cache[id] = existing;
      return existing;
    }
    final request = Future<T>.sync(load);
    cache[id] = request;
    while (cache.length > capacity) {
      cache.remove(cache.keys.first);
    }
    request.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {
        // A stale failed request must not remove a newer explicit refresh.
        if (identical(cache[id], request)) cache.remove(id);
      },
    );
    return request;
  }
}
