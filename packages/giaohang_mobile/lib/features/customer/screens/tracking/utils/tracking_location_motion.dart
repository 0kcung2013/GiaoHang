import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

class TrackingRouteProjection {
  const TrackingRouteProjection({
    required this.point,
    required this.distanceAlongRoute,
    required this.bearingDegrees,
  });

  final LatLng point;
  final double distanceAlongRoute;
  final double bearingDegrees;
}

/// Chính sách hiển thị vị trí tài xế trên map khách.
///
/// Realtime là nguồn chính. Polling chỉ đóng vai trò dự phòng khi socket không
/// gửi mẫu mới đủ lâu; marker được nội suy giữa hai mẫu để không nhảy từng nấc.
class TrackingLocationMotion {
  const TrackingLocationMotion._();

  static const realtimeFreshFor = Duration(seconds: 6);

  static bool shouldPollFallback({
    required DateTime? lastRealtimeAt,
    required DateTime now,
  }) {
    if (lastRealtimeAt == null) return true;
    return now.difference(lastRealtimeAt) >= realtimeFreshFor;
  }

  static LatLng interpolate(LatLng from, LatLng to, double progress) {
    final t = progress.clamp(0.0, 1.0);
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }

  /// Projects a raw GPS point onto the nearest segment of the OSRM route.
  ///
  /// GPS is allowed to be several metres away from the road. The map marker
  /// must use the projected point so it remains on the route at every zoom.
  static TrackingRouteProjection? projectOntoRoute(
    LatLng current,
    List<LatLng> route,
  ) {
    if (route.isEmpty) return null;
    if (route.length == 1) {
      return TrackingRouteProjection(
        point: route.single,
        distanceAlongRoute: 0,
        bearingDegrees: 0,
      );
    }

    TrackingRouteProjection? closest;
    var routeDistance = 0.0;
    var closestDistance = double.infinity;

    for (var index = 0; index < route.length - 1; index++) {
      final start = route[index];
      final end = route[index + 1];
      final edge = _projectOnEdge(current, start, end);
      if (edge.distanceMeters < closestDistance) {
        closestDistance = edge.distanceMeters;
        closest = TrackingRouteProjection(
          point: edge.point,
          distanceAlongRoute:
              routeDistance + edge.edgeLengthMeters * edge.progress,
          bearingDegrees: edge.bearingDegrees,
        );
      }
      routeDistance += edge.edgeLengthMeters;
    }

    return closest;
  }

  /// Interpolates by route distance instead of drawing a straight line
  /// between two GPS samples. This keeps the animated marker on every bend.
  static LatLng interpolateAlongRoute({
    required List<LatLng> route,
    required TrackingRouteProjection from,
    required TrackingRouteProjection to,
    required double progress,
  }) {
    final t = progress.clamp(0.0, 1.0).toDouble();
    final distance =
        from.distanceAlongRoute +
        (to.distanceAlongRoute - from.distanceAlongRoute) * t;
    return _pointAtDistance(route, distance);
  }

  static LatLng _pointAtDistance(List<LatLng> route, double distance) {
    if (route.isEmpty) return const LatLng(0, 0);
    if (route.length == 1) return route.single;

    var traversed = 0.0;
    final target = math.max(0.0, distance);
    for (var index = 0; index < route.length - 1; index++) {
      final start = route[index];
      final end = route[index + 1];
      final edgeLength = _distanceMeters(start, end);
      if (edgeLength == 0) continue;
      if (target <= traversed + edgeLength) {
        final progress = (target - traversed) / edgeLength;
        return interpolate(start, end, progress);
      }
      traversed += edgeLength;
    }
    return route.last;
  }

  static _EdgeProjection _projectOnEdge(
    LatLng current,
    LatLng start,
    LatLng end,
  ) {
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
    final progress = rawProgress.clamp(0.0, 1.0).toDouble();
    final projectedX = edgeX * progress;
    final projectedY = edgeY * progress;

    return _EdgeProjection(
      point: LatLng(
        start.latitude + (end.latitude - start.latitude) * progress,
        start.longitude + (end.longitude - start.longitude) * progress,
      ),
      progress: progress,
      edgeLengthMeters: math.sqrt(squaredLength),
      distanceMeters: math.sqrt(
        math.pow(pointX - projectedX, 2) + math.pow(pointY - projectedY, 2),
      ),
      bearingDegrees: _bearingDegrees(start, end),
    );
  }

  static double _distanceMeters(LatLng from, LatLng to) {
    const metersPerDegree = 111320.0;
    final longitudeScale =
        metersPerDegree * math.cos(from.latitude * math.pi / 180);
    final x = (to.longitude - from.longitude) * longitudeScale;
    final y = (to.latitude - from.latitude) * metersPerDegree;
    return math.sqrt(x * x + y * y);
  }

  static double _bearingDegrees(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final deltaLng = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(deltaLng) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(deltaLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }
}

class _EdgeProjection {
  const _EdgeProjection({
    required this.point,
    required this.progress,
    required this.edgeLengthMeters,
    required this.distanceMeters,
    required this.bearingDegrees,
  });

  final LatLng point;
  final double progress;
  final double edgeLengthMeters;
  final double distanceMeters;
  final double bearingDegrees;
}
