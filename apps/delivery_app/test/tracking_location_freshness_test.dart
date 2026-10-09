import 'package:delivery_app/core/location/tracking_location_freshness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final startAt = DateTime.utc(2026, 10, 8, 14, 15, 29);
  final arrivedAt = DateTime.utc(2026, 10, 8, 14, 20);

  test('a profile can seed tracking before any timestamped GPS sample', () {
    final freshness = TrackingLocationFreshness();
    expect(
      freshness.acceptProfilePoll(startedAtRevision: freshness.revision),
      isTrue,
    );
    expect(freshness.acceptBroadcast(sampledAt: arrivedAt), isTrue);
  });

  test('stopping broadcasts does not make the departure GPS fresh again', () {
    final freshness = TrackingLocationFreshness();
    freshness.acceptPersisted(sampledAt: startAt);
    freshness.acceptBroadcast(sampledAt: arrivedAt);

    // Polling resumes after the six-second socket grace period, but the public
    // profile still contains the departure coordinates with no GPS timestamp.
    expect(
      freshness.acceptProfilePoll(startedAtRevision: freshness.revision),
      isFalse,
    );
    expect(freshness.acceptPersisted(sampledAt: startAt), isFalse);
    expect(freshness.acceptPersisted(sampledAt: null), isFalse);
    expect(
      freshness.acceptPersisted(
        sampledAt: arrivedAt.add(const Duration(seconds: 10)),
      ),
      isTrue,
    );
  });

  test(
    'a poll started before a broadcast cannot commit after that broadcast',
    () {
      final freshness = TrackingLocationFreshness();
      final startedAtRevision = freshness.revision;
      freshness.acceptBroadcast(sampledAt: arrivedAt);
      expect(
        freshness.acceptProfilePoll(startedAtRevision: startedAtRevision),
        isFalse,
      );
    },
  );

  test(
    'late broadcast and repeated persisted events cannot rewind newer GPS',
    () {
      final freshness = TrackingLocationFreshness();
      freshness.acceptPersisted(sampledAt: arrivedAt);
      expect(freshness.acceptBroadcast(sampledAt: startAt), isFalse);
      expect(freshness.acceptPersisted(sampledAt: arrivedAt), isFalse);
      expect(
        freshness.acceptBroadcast(
          sampledAt: arrivedAt.add(const Duration(seconds: 1)),
        ),
        isTrue,
      );
    },
  );
}
