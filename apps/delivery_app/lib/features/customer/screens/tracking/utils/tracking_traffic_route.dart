import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../../../../core/utils/delivery_traffic_route_analyzer.dart';

/// A stable historical-traffic evaluation anchored to one route geometry.
///
/// GPS progress may clip these segments, but it must not score them again.
class TrackingTrafficRouteSnapshot {
  TrackingTrafficRouteSnapshot({
    required List<LatLng> routePoints,
    required List<DeliveryTrafficSegment> segments,
    required this.evaluatedAt,
  }) : routePoints = List<LatLng>.unmodifiable(routePoints),
       segments = List<DeliveryTrafficSegment>.unmodifiable(
         segments.map(_immutableSegment),
       );

  factory TrackingTrafficRouteSnapshot.build({
    required List<LatLng> routePoints,
    required DateTime evaluatedAt,
  }) {
    final stableRoute = List<LatLng>.unmodifiable(routePoints);
    return TrackingTrafficRouteSnapshot(
      routePoints: stableRoute,
      segments: DeliveryTrafficRouteAnalyzer.analyze(
        routePoints: stableRoute,
        quotedAt: evaluatedAt,
      ),
      evaluatedAt: evaluatedAt,
    );
  }

  final List<LatLng> routePoints;
  final List<DeliveryTrafficSegment> segments;
  final DateTime evaluatedAt;

  bool isOffRoute(LatLng current, {double thresholdMeters = 150}) {
    if (routePoints.isEmpty) return true;
    if (routePoints.length == 1) {
      return const Distance().as(
            LengthUnit.Meter,
            current,
            routePoints.single,
          ) >
          thresholdMeters;
    }

    var closestMeters = double.infinity;
    for (var index = 0; index < routePoints.length - 1; index++) {
      final projection = _projectOnEdge(
        current,
        routePoints[index],
        routePoints[index + 1],
      );
      closestMeters = math.min(closestMeters, projection.distanceMeters);
    }
    return closestMeters > thresholdMeters;
  }
}

/// Monotonic progress through a snapshot. Backward GPS jitter cannot restore
/// segments that the driver has already passed.
class TrackingTrafficRouteProgress {
  TrackingTrafficRouteProgress(this.snapshot);

  final TrackingTrafficRouteSnapshot snapshot;
  int _segmentIndex = 0;
  int _edgeIndex = 0;
  double _edgeProgress = 0;

  List<DeliveryTrafficSegment> advanceTo(LatLng? current) {
    if (current == null || snapshot.segments.isEmpty) {
      return snapshot.segments;
    }

    _RouteCursor? closest;
    for (
      var segmentIndex = _segmentIndex;
      segmentIndex < snapshot.segments.length;
      segmentIndex++
    ) {
      final points = snapshot.segments[segmentIndex].points;
      if (points.length < 2) continue;
      final firstEdge = segmentIndex == _segmentIndex ? _edgeIndex : 0;
      for (
        var edgeIndex = firstEdge;
        edgeIndex < points.length - 1;
        edgeIndex++
      ) {
        final minimumProgress =
            segmentIndex == _segmentIndex && edgeIndex == _edgeIndex
            ? _edgeProgress
            : 0.0;
        final projection = _projectOnEdge(
          current,
          points[edgeIndex],
          points[edgeIndex + 1],
          minimumProgress: minimumProgress,
        );
        if (closest == null ||
            projection.distanceMeters < closest.projection.distanceMeters) {
          closest = _RouteCursor(
            segmentIndex: segmentIndex,
            edgeIndex: edgeIndex,
            projection: projection,
          );
        }
      }
    }

    if (closest == null) return const [];
    _segmentIndex = closest.segmentIndex;
    _edgeIndex = closest.edgeIndex;
    _edgeProgress = closest.projection.progress;
    return _remainingFrom(closest);
  }

  List<DeliveryTrafficSegment> _remainingFrom(_RouteCursor cursor) {
    final remaining = <DeliveryTrafficSegment>[];
    for (
      var segmentIndex = cursor.segmentIndex;
      segmentIndex < snapshot.segments.length;
      segmentIndex++
    ) {
      final segment = snapshot.segments[segmentIndex];
      final points = segmentIndex == cursor.segmentIndex
          ? <LatLng>[
              cursor.projection.point,
              ...segment.points.skip(cursor.edgeIndex + 1),
            ]
          : segment.points;
      final uniquePoints = _withoutAdjacentDuplicates(points);
      if (uniquePoints.length < 2) continue;
      remaining.add(
        DeliveryTrafficSegment(
          points: List<LatLng>.unmodifiable(uniquePoints),
          level: segment.level,
          maxHistoricalMultiplier: segment.maxHistoricalMultiplier,
        ),
      );
    }
    return List<DeliveryTrafficSegment>.unmodifiable(remaining);
  }
}

class TrackingRouteRefreshPolicy {
  TrackingRouteRefreshPolicy._();

  static bool shouldReload({
    required TrackingTrafficRouteSnapshot? snapshot,
    required LatLng current,
  }) {
    return snapshot == null || snapshot.isOffRoute(current);
  }
}

class TrackingRouteRequestToken {
  const TrackingRouteRequestToken({
    required this.generation,
    required this.hash,
  });

  final int generation;
  final String hash;
}

/// Serializes route requests without letting duplicate GPS events invalidate an
/// in-flight request. A hash becomes accepted only after a route is available.
class TrackingRouteRequestGate {
  TrackingRouteRequestGate({
    this.minimumInterval = const Duration(seconds: 12),
  });

  final Duration minimumInterval;
  int _generation = 0;
  String? _pendingHash;
  String? _acceptedHash;
  DateTime? _lastStartedAt;

  TrackingRouteRequestToken? tryStart({
    required String hash,
    required bool hasAcceptedRoute,
    required DateTime now,
  }) {
    if (_pendingHash == hash) return null;
    if (hasAcceptedRoute && _acceptedHash == hash) return null;
    final lastStartedAt = _lastStartedAt;
    if (hasAcceptedRoute &&
        lastStartedAt != null &&
        now.difference(lastStartedAt) < minimumInterval) {
      return null;
    }

    final token = TrackingRouteRequestToken(
      generation: ++_generation,
      hash: hash,
    );
    _pendingHash = hash;
    _lastStartedAt = now;
    return token;
  }

  bool isCurrent(TrackingRouteRequestToken token) {
    return token.generation == _generation && _pendingHash == token.hash;
  }

  void finish(TrackingRouteRequestToken token, {required bool accepted}) {
    if (!isCurrent(token)) return;
    if (accepted) _acceptedHash = token.hash;
    _pendingHash = null;
  }
}

class _RouteCursor {
  const _RouteCursor({
    required this.segmentIndex,
    required this.edgeIndex,
    required this.projection,
  });

  final int segmentIndex;
  final int edgeIndex;
  final _EdgeProjection projection;
}

class _EdgeProjection {
  const _EdgeProjection({
    required this.point,
    required this.progress,
    required this.distanceMeters,
  });

  final LatLng point;
  final double progress;
  final double distanceMeters;
}

_EdgeProjection _projectOnEdge(
  LatLng current,
  LatLng start,
  LatLng end, {
  double minimumProgress = 0,
}) {
  const metersPerDegree = 111320.0;
  final longitudeScale =
      metersPerDegree * math.cos(current.latitude * math.pi / 180);
  final pointX = (current.longitude - start.longitude) * longitudeScale;
  final pointY = (current.latitude - start.latitude) * metersPerDegree;
  final edgeX = (end.longitude - start.longitude) * longitudeScale;
  final edgeY = (end.latitude - start.latitude) * metersPerDegree;
  final squaredLength = edgeX * edgeX + edgeY * edgeY;
  final rawProgress = squaredLength == 0
      ? 0.0
      : (pointX * edgeX + pointY * edgeY) / squaredLength;
  final progress = rawProgress.clamp(minimumProgress, 1.0).toDouble();
  final projectedX = edgeX * progress;
  final projectedY = edgeY * progress;

  return _EdgeProjection(
    point: LatLng(
      start.latitude + (end.latitude - start.latitude) * progress,
      start.longitude + (end.longitude - start.longitude) * progress,
    ),
    progress: progress,
    distanceMeters: math.sqrt(
      math.pow(pointX - projectedX, 2) + math.pow(pointY - projectedY, 2),
    ),
  );
}

DeliveryTrafficSegment _immutableSegment(DeliveryTrafficSegment segment) {
  return DeliveryTrafficSegment(
    points: List<LatLng>.unmodifiable(segment.points),
    level: segment.level,
    maxHistoricalMultiplier: segment.maxHistoricalMultiplier,
  );
}

List<LatLng> _withoutAdjacentDuplicates(List<LatLng> points) {
  final unique = <LatLng>[];
  for (final point in points) {
    if (unique.isEmpty ||
        unique.last.latitude != point.latitude ||
        unique.last.longitude != point.longitude) {
      unique.add(point);
    }
  }
  return unique;
}
