import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Tiện ích map giao hàng (chuẩn app giao hàng: Grab/ShopeeFood-like).
///
/// - Vạch xanh = **đường còn lại** (đã đi qua thì cắt, không vẽ full trip).
/// - Camera bám vị trí hiện tại + điểm đến tiếp theo.
class DeliveryMapUtils {
  DeliveryMapUtils._();

  static const Distance _distance = Distance();

  /// Điểm đích chặng hiện tại theo status đơn.
  static LatLng nextTarget({
    required String status,
    required double pickupLat,
    required double pickupLng,
    required double deliveryLat,
    required double deliveryLng,
  }) {
    if (status == 'delivering' || status == 'delivered') {
      return LatLng(deliveryLat, deliveryLng);
    }
    return LatLng(pickupLat, pickupLng);
  }

  /// Cắt polyline còn lại từ vị trí hiện tại → cuối tuyến.
  /// Bám **điểm trên route** (không kéo vạch lệch đường).
  static List<LatLng> remainingRoute({
    required List<LatLng> fullRoute,
    required LatLng current,
    double snapMaxMeters = 100,
  }) {
    if (fullRoute.length < 2) return fullRoute;

    final projection = _projectOntoRoute(current, fullRoute);
    if (projection == null || projection.distanceMeters > snapMaxMeters * 5) {
      // Xa route → current → đích (tránh vẽ sai cả tuyến)
      return [current, fullRoute.last];
    }

    final snapped = snapToRoute(
      fullRoute: fullRoute,
      current: current,
      maxSnapMeters: snapMaxMeters,
    );
    // Còn lại bắt đầu đúng tại điểm snap, kể cả khi GPS nằm giữa 2 đỉnh.
    if (snapped == current) {
      return [current, ...fullRoute.sublist(projection.edgeIndex + 1)];
    }
    return [snapped, ...fullRoute.sublist(projection.edgeIndex + 1)];
  }

  /// Snap marker TX lên polyline để không “lơ lửng” so với vạch xanh.
  static LatLng snapToRoute({
    required List<LatLng> fullRoute,
    required LatLng current,
    double maxSnapMeters = 120,
  }) {
    if (fullRoute.isEmpty) return current;
    if (fullRoute.length == 1) {
      final onlyPoint = fullRoute.first;
      final distance = _distance.as(LengthUnit.Meter, current, onlyPoint);
      return distance <= maxSnapMeters ? onlyPoint : current;
    }

    var best = fullRoute.first;
    var bestDist = double.infinity;
    for (var i = 0; i < fullRoute.length - 1; i++) {
      final candidate = _closestPointOnSegment(
        current,
        fullRoute[i],
        fullRoute[i + 1],
      );
      final d = _distance.as(LengthUnit.Meter, current, candidate);
      if (d < bestDist) {
        bestDist = d;
        best = candidate;
      }
    }
    if (bestDist <= maxSnapMeters) return best;
    return current;
  }

  /// Hướng đoạn route gần nhất tại vị trí hiện tại, theo bearing 0° = Bắc.
  static double? routeBearing({
    required List<LatLng> route,
    required LatLng current,
  }) {
    return _projectOntoRoute(current, route)?.bearingDegrees;
  }

  /// Hướng về một điểm ngắn phía trước trên polyline.
  ///
  /// Khoảng nhìn trước giúp marker bám hướng tuyến nhưng không giật ngang khi
  /// OSRM tạo ra các đoạn nối rất ngắn ở giao lộ.
  static double? forwardRouteBearing({
    required List<LatLng> route,
    required LatLng current,
    double lookAheadMeters = 24,
  }) {
    if (route.length < 2) return null;
    final projection = _projectOntoRoute(current, route);
    if (projection == null) return null;

    final target = _pointAtRouteDistance(
      route,
      projection.distanceAlongRoute + lookAheadMeters.clamp(0, double.infinity),
    );
    if (_distanceMeters(projection.point, target) < 0.1) {
      return projection.bearingDegrees;
    }
    return _bearingDegrees(projection.point, target);
  }

  /// Nội suy marker theo chiều dài route, không đi xuyên góc theo đường chim
  /// bay giữa hai mẫu GPS.
  static LatLng interpolateAlongRoute({
    required List<LatLng> route,
    required LatLng from,
    required LatLng to,
    required double progress,
  }) {
    if (route.length < 2) return interpolate(from, to, progress);
    final fromProjection = _projectOntoRoute(from, route);
    final toProjection = _projectOntoRoute(to, route);
    if (fromProjection == null || toProjection == null) {
      return interpolate(from, to, progress);
    }

    final t = progress.clamp(0.0, 1.0).toDouble();
    final targetDistance =
        fromProjection.distanceAlongRoute +
        (toProjection.distanceAlongRoute - fromProjection.distanceAlongRoute) *
            t;
    return _pointAtRouteDistance(route, targetDistance);
  }

  static LatLng interpolate(LatLng from, LatLng to, double progress) {
    final t = progress.clamp(0.0, 1.0).toDouble();
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }

  static _RouteProjection? _projectOntoRoute(
    LatLng current,
    List<LatLng> route,
  ) {
    _RouteProjection? closest;
    var distanceAlongRoute = 0.0;
    var closestDistance = double.infinity;

    for (var index = 0; index < route.length - 1; index++) {
      final start = route[index];
      final end = route[index + 1];
      final edge = _projectOnSegment(current, start, end);
      if (edge.distanceMeters < closestDistance) {
        closestDistance = edge.distanceMeters;
        closest = _RouteProjection(
          point: edge.point,
          edgeIndex: index,
          progress: edge.progress,
          lengthMeters: edge.lengthMeters,
          distanceMeters: edge.distanceMeters,
          bearingDegrees: edge.bearingDegrees,
          distanceAlongRoute:
              distanceAlongRoute + edge.lengthMeters * edge.progress,
        );
      }
      distanceAlongRoute += edge.lengthMeters;
    }
    return closest;
  }

  static LatLng _pointAtRouteDistance(List<LatLng> route, double distance) {
    var traversed = 0.0;
    final target = distance.clamp(0.0, double.infinity).toDouble();
    for (var index = 0; index < route.length - 1; index++) {
      final start = route[index];
      final end = route[index + 1];
      final edgeLength = _distanceMeters(start, end);
      if (edgeLength == 0) continue;
      if (target <= traversed + edgeLength) {
        return interpolate(start, end, (target - traversed) / edgeLength);
      }
      traversed += edgeLength;
    }
    return route.last;
  }

  static _RouteProjection _projectOnSegment(
    LatLng point,
    LatLng start,
    LatLng end,
  ) {
    final deltaLat = end.latitude - start.latitude;
    final deltaLng = end.longitude - start.longitude;
    final segmentLengthSquared = deltaLat * deltaLat + deltaLng * deltaLng;
    if (segmentLengthSquared == 0) {
      return _RouteProjection(
        point: start,
        edgeIndex: 0,
        distanceAlongRoute: 0,
        progress: 0,
        lengthMeters: 0,
        distanceMeters: _distance.as(LengthUnit.Meter, point, start),
        bearingDegrees: _bearingDegrees(start, end),
      );
    }

    final progress =
        ((point.latitude - start.latitude) * deltaLat +
            (point.longitude - start.longitude) * deltaLng) /
        segmentLengthSquared;
    final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
    final projected = LatLng(
      start.latitude + deltaLat * clampedProgress,
      start.longitude + deltaLng * clampedProgress,
    );
    return _RouteProjection(
      point: projected,
      edgeIndex: 0,
      distanceAlongRoute: 0,
      progress: clampedProgress,
      lengthMeters: _distanceMeters(start, end),
      distanceMeters: _distance.as(LengthUnit.Meter, point, projected),
      bearingDegrees: _bearingDegrees(start, end),
    );
  }

  static double _distanceMeters(LatLng from, LatLng to) {
    return _distance.as(LengthUnit.Meter, from, to);
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

  static LatLng _closestPointOnSegment(LatLng point, LatLng start, LatLng end) {
    final deltaLat = end.latitude - start.latitude;
    final deltaLng = end.longitude - start.longitude;
    final segmentLengthSquared = deltaLat * deltaLat + deltaLng * deltaLng;
    if (segmentLengthSquared == 0) return start;

    final progress =
        ((point.latitude - start.latitude) * deltaLat +
            (point.longitude - start.longitude) * deltaLng) /
        segmentLengthSquared;
    final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
    return LatLng(
      start.latitude + deltaLat * clampedProgress,
      start.longitude + deltaLng * clampedProgress,
    );
  }

  /// Ước lượng mét còn lại trên polyline remaining.
  static double remainingMeters(List<LatLng> remaining) {
    if (remaining.length < 2) return 0;
    var total = 0.0;
    for (var i = 0; i < remaining.length - 1; i++) {
      total += _distance.as(LengthUnit.Meter, remaining[i], remaining[i + 1]);
    }
    return total;
  }

  /// Điểm để fit camera: vị trí TX + đích chặng (+ optional điểm kia mờ).
  static List<LatLng> followFocusPoints({
    required LatLng? driver,
    required LatLng nextTarget,
    LatLng? secondaryAnchor,
    bool includeSecondary = false,
  }) {
    final pts = <LatLng>[];
    if (driver != null) pts.add(driver);
    pts.add(nextTarget);
    if (includeSecondary && secondaryAnchor != null) {
      pts.add(secondaryAnchor);
    }
    return pts;
  }

  static String formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  static String formatDuration(double seconds) {
    if (seconds < 60) return '${seconds.round()} giây';
    final m = (seconds / 60).ceil();
    if (m < 60) return '$m phút';
    final h = m ~/ 60;
    final rm = m % 60;
    return rm == 0 ? '$h giờ' : '$h giờ $rm phút';
  }
}

class _RouteProjection {
  const _RouteProjection({
    required this.point,
    required this.edgeIndex,
    required this.distanceAlongRoute,
    required this.progress,
    required this.lengthMeters,
    required this.distanceMeters,
    required this.bearingDegrees,
  });

  final LatLng point;
  final int edgeIndex;
  final double distanceAlongRoute;
  final double progress;
  final double lengthMeters;
  final double distanceMeters;
  final double bearingDegrees;
}
