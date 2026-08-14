import 'package:delivery_app/core/utils/delivery_traffic_route_analyzer.dart';
import 'package:delivery_app/features/customer/screens/tracking/utils/tracking_traffic_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const route = [
    LatLng(10.7750, 106.6800),
    LatLng(10.7760, 106.6810),
    LatLng(10.7770, 106.6820),
    LatLng(10.7780, 106.6830),
  ];

  test('build captures one historical traffic evaluation for the route', () {
    final evaluatedAt = DateTime(2026, 8, 11, 17, 30);

    final snapshot = TrackingTrafficRouteSnapshot.build(
      routePoints: route,
      evaluatedAt: evaluatedAt,
    );

    expect(snapshot.routePoints, route);
    expect(snapshot.evaluatedAt, evaluatedAt);
    expect(snapshot.segments, isNotEmpty);
  });

  test('GPS progress clips stored segments without reclassifying colors', () {
    final clearSegment = DeliveryTrafficSegment(
      points: [route[0], route[1], route[2]],
      level: DeliveryTrafficLevel.clear,
      maxHistoricalMultiplier: 1.1,
    );
    final congestedSegment = DeliveryTrafficSegment(
      points: [route[2], route[3]],
      level: DeliveryTrafficLevel.congested,
      maxHistoricalMultiplier: 1.7,
    );
    final snapshot = TrackingTrafficRouteSnapshot(
      routePoints: route,
      segments: [clearSegment, congestedSegment],
      evaluatedAt: DateTime(2026, 8, 11, 17, 30),
    );

    final progress = TrackingTrafficRouteProgress(snapshot);
    final remaining = progress.advanceTo(route[2]);

    expect(remaining, hasLength(1));
    expect(remaining.single.level, DeliveryTrafficLevel.congested);
    expect(remaining.single.points, [route[2], route[3]]);
    expect(snapshot.segments.map((segment) => segment.level), [
      DeliveryTrafficLevel.clear,
      DeliveryTrafficLevel.congested,
    ]);
    expect(snapshot.segments.first.points, [route[0], route[1], route[2]]);
  });

  test('GPS jitter cannot restore traffic segments already passed', () {
    final snapshot = TrackingTrafficRouteSnapshot(
      routePoints: route,
      segments: [
        DeliveryTrafficSegment(
          points: [route[0], route[1], route[2]],
          level: DeliveryTrafficLevel.clear,
          maxHistoricalMultiplier: 1.1,
        ),
        DeliveryTrafficSegment(
          points: [route[2], route[3]],
          level: DeliveryTrafficLevel.congested,
          maxHistoricalMultiplier: 1.7,
        ),
      ],
      evaluatedAt: DateTime(2026, 8, 11, 17, 30),
    );
    final progress = TrackingTrafficRouteProgress(snapshot);

    progress.advanceTo(route[2]);
    final afterBackwardJitter = progress.advanceTo(route[1]);

    expect(afterBackwardJitter, hasLength(1));
    expect(afterBackwardJitter.single.level, DeliveryTrafficLevel.congested);
  });

  test('off-route detection distinguishes progress from a real reroute', () {
    final snapshot = TrackingTrafficRouteSnapshot(
      routePoints: route,
      segments: const [],
      evaluatedAt: DateTime(2026, 8, 11, 17, 30),
    );

    expect(snapshot.isOffRoute(route[1]), isFalse);
    expect(snapshot.isOffRoute(const LatLng(10.7900, 106.7000)), isTrue);
  });

  test('GPS midway along a sparse route segment does not trigger reroute', () {
    const sparseRoute = [LatLng(10.7750, 106.6800), LatLng(10.7750, 106.6900)];
    final snapshot = TrackingTrafficRouteSnapshot(
      routePoints: sparseRoute,
      segments: const [],
      evaluatedAt: DateTime(2026, 8, 11, 17, 30),
    );

    expect(snapshot.isOffRoute(const LatLng(10.7750, 106.6850)), isFalse);
  });

  test(
    'route refresh policy reloads only for a missing or off-route snapshot',
    () {
      final snapshot = TrackingTrafficRouteSnapshot(
        routePoints: route,
        segments: const [],
        evaluatedAt: DateTime(2026, 8, 11, 17, 30),
      );

      expect(
        TrackingRouteRefreshPolicy.shouldReload(
          snapshot: snapshot,
          current: route[1],
        ),
        isFalse,
      );
      expect(
        TrackingRouteRefreshPolicy.shouldReload(
          snapshot: snapshot,
          current: const LatLng(10.7900, 106.7000),
        ),
        isTrue,
      );
      expect(
        TrackingRouteRefreshPolicy.shouldReload(
          snapshot: null,
          current: route[1],
        ),
        isTrue,
      );
    },
  );

  group('route request gate', () {
    test(
      'duplicate pending request does not invalidate the active request',
      () {
        final gate = TrackingRouteRequestGate();
        final startedAt = DateTime(2026, 8, 11, 17, 30);

        final first = gate.tryStart(
          hash: 'delivering_route-a',
          hasAcceptedRoute: false,
          now: startedAt,
        );
        final duplicate = gate.tryStart(
          hash: 'delivering_route-a',
          hasAcceptedRoute: false,
          now: startedAt.add(const Duration(seconds: 1)),
        );

        expect(first, isNotNull);
        expect(duplicate, isNull);
        expect(gate.isCurrent(first!), isTrue);
      },
    );

    test(
      'failed request can retry the same route after the throttle window',
      () {
        final gate = TrackingRouteRequestGate();
        final startedAt = DateTime(2026, 8, 11, 17, 30);
        final first = gate.tryStart(
          hash: 'delivering_route-a',
          hasAcceptedRoute: false,
          now: startedAt,
        )!;

        gate.finish(first, accepted: false);
        final retry = gate.tryStart(
          hash: 'delivering_route-a',
          hasAcceptedRoute: false,
          now: startedAt.add(const Duration(seconds: 13)),
        );

        expect(retry, isNotNull);
        expect(retry!.generation, greaterThan(first.generation));
      },
    );

    test('accepted route suppresses an identical route request', () {
      final gate = TrackingRouteRequestGate();
      final startedAt = DateTime(2026, 8, 11, 17, 30);
      final first = gate.tryStart(
        hash: 'delivering_route-a',
        hasAcceptedRoute: false,
        now: startedAt,
      )!;

      gate.finish(first, accepted: true);

      expect(
        gate.tryStart(
          hash: 'delivering_route-a',
          hasAcceptedRoute: true,
          now: startedAt.add(const Duration(seconds: 13)),
        ),
        isNull,
      );
    });
  });
}
