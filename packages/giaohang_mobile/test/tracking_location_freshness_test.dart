import 'package:giaohang_mobile/core/location/tracking_location_freshness.dart';
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
    var receivedAt = arrivedAt;
    final freshness = TrackingLocationFreshness(clock: () => receivedAt);
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
    receivedAt = receivedAt.add(const Duration(seconds: 7));
    expect(
      freshness.acceptPersisted(
        sampledAt: arrivedAt.add(const Duration(seconds: 10)),
      ),
      isTrue,
    );
  });

  test('active broadcast wins over a delayed database write timestamp', () {
    var now = arrivedAt;
    final freshness = TrackingLocationFreshness(clock: () => now);
    freshness.acceptBroadcast(sampledAt: arrivedAt);
    now = now.add(const Duration(seconds: 1));
    expect(freshness.acceptPersisted(sampledAt: now), isFalse);
    expect(freshness.latestSampleAt, arrivedAt);
    now = now.add(const Duration(seconds: 6));
    expect(freshness.acceptPersisted(sampledAt: now), isTrue);
  });

  test('duplicates do not replay movement or change the accepted cadence', () {
    final freshness = TrackingLocationFreshness();
    freshness.acceptBroadcast(sampledAt: arrivedAt);
    freshness.acceptBroadcast(
      sampledAt: arrivedAt.add(const Duration(milliseconds: 250)),
    );
    final revision = freshness.revision;
    expect(freshness.sampleInterval, const Duration(milliseconds: 250));
    expect(freshness.acceptBroadcast(sampledAt: arrivedAt), isFalse);
    expect(
      freshness.acceptBroadcast(
        sampledAt: arrivedAt.add(const Duration(milliseconds: 250)),
      ),
      isFalse,
    );
    expect(freshness.revision, revision);
    expect(freshness.sampleInterval, const Duration(milliseconds: 250));
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
