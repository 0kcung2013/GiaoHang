import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import '../utils/delivery_traffic_route_analyzer.dart';
import 'order_model.dart';

class RouteSpeedSection {
  const RouteSpeedSection(this.startMeters, this.endMeters, this.speedKmh);
  final double startMeters;
  final double endMeters;
  final double speedKmh;
}

class DeliveryEtaRouteProfileCache {
  String? _key;
  DeliveryEtaRouteProfile? _value;
  DeliveryEtaRouteProfile? resolve(OrderModel order) {
    final key =
        '${order.id}:${order.driverId}:${order.status}:${order.actualPickedUpAt}:'
        '${order.deliveryEtaData?['computed_at']}:${order.deliveryEtaData?['version']}';
    if (_key != key) {
      _key = key;
      _value = DeliveryEtaRouteProfile.forOrder(order);
    }
    return _value;
  }
}

/// Shared forecast for ETA, map colors and generated route movement.
class DeliveryEtaRouteProfile {
  DeliveryEtaRouteProfile._(
    this.points,
    this.distanceMeters,
    this.sections,
    this.usesAi,
    this.forecastAt,
  ) {
    _cumulative = [0];
    for (var i = 1; i < points.length; i++) {
      _cumulative.add(_cumulative.last + _distance(points[i - 1], points[i]));
    }
  }
  static const _distance = Distance();
  final List<LatLng> points;
  final double distanceMeters;
  final List<RouteSpeedSection> sections;
  final bool usesAi;
  final DateTime forecastAt;
  late final List<double> _cumulative;
  double get geometryScale => _cumulative.last / distanceMeters;
  String get identity => '${forecastAt.toIso8601String()}:$distanceMeters';

  static DeliveryEtaRouteProfile? forOrder(OrderModel order) {
    final data = order.deliveryEtaData;
    if (order.driverId == null ||
        data?['driver_id'] != order.driverId ||
        data?['calculation_mode'] != 'assignment_once_v1') {
      return null;
    }
    final delivering =
        order.status == 'delivering' ||
        order.status == 'delivered' ||
        order.actualPickedUpAt != null;
    return fromJson(data?[delivering ? 'delivery' : 'approach']);
  }

  static DeliveryEtaRouteProfile? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final length = _number(raw['distance_meters']);
    final at = DateTime.tryParse(raw['forecast_at']?.toString() ?? '');
    final geometry = raw['route_points'];
    final speeds = raw['speed_profile'];
    if (length == null ||
        !length.isFinite ||
        length <= 0 ||
        at == null ||
        geometry is! List ||
        geometry.length < 2 ||
        speeds is! List ||
        speeds.isEmpty) {
      return null;
    }
    final points = <LatLng>[];
    for (final p in geometry) {
      if (p is! List || p.length < 2 || p[0] is! num || p[1] is! num) {
        return null;
      }
      final lng = (p[0] as num).toDouble(), lat = (p[1] as num).toDouble();
      if (!lat.isFinite || !lng.isFinite || lat.abs() > 90 || lng.abs() > 180) {
        return null;
      }
      points.add(LatLng(lat, lng));
    }
    final sections = <RouteSpeedSection>[];
    var end = 0.0;
    for (final s in speeds) {
      if (s is! Map) return null;
      final from = _number(s['start_meters']);
      final to = _number(s['end_meters']);
      final v = _number(s['speed_kmh']);
      if (from == null ||
          to == null ||
          v == null ||
          !from.isFinite ||
          !to.isFinite ||
          !v.isFinite ||
          v <= 0 ||
          v > 90 ||
          (from - end).abs() > 0.01 ||
          to <= from ||
          to > length + 0.01) {
        return null;
      }
      sections.add(RouteSpeedSection(from, to, v));
      end = to;
    }
    if ((end - length).abs() > 0.01) return null;
    final result = DeliveryEtaRouteProfile._(
      List.unmodifiable(points),
      length,
      List.unmodifiable(sections),
      raw['used_ai'] == true,
      at,
    );
    return result._cumulative.last > 0 ? result : null;
  }

  static double? _number(dynamic value) =>
      value is num ? value.toDouble() : null;

  double distanceAt(LatLng position) {
    var best = double.infinity, along = 0.0;
    final cosLat = math.cos(position.latitude * math.pi / 180);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      final dx = (b.longitude - a.longitude) * cosLat;
      final dy = b.latitude - a.latitude;
      final px = (position.longitude - a.longitude) * cosLat;
      final py = position.latitude - a.latitude;
      final denominator = dx * dx + dy * dy;
      final t = denominator == 0
          ? 0.0
          : ((px * dx + py * dy) / denominator).clamp(0.0, 1.0);
      final error = math.pow(px - dx * t, 2) + math.pow(py - dy * t, 2);
      if (error < best) {
        best = error.toDouble();
        along = _cumulative[i - 1] + t * (_cumulative[i] - _cumulative[i - 1]);
      }
    }
    return (along / geometryScale).clamp(0.0, distanceMeters);
  }

  double speedAt(LatLng position) => speedAtDistance(distanceAt(position));
  double speedAtDistance(double meters) => sections
      .firstWhere(
        (s) => meters < s.endMeters - 0.000001,
        orElse: () => sections.last,
      )
      .speedKmh;

  double remainingMinutes(LatLng position) {
    final from = distanceAt(position);
    return sections.fold(
      0.0,
      (sum, s) =>
          sum +
          math.max(0, s.endMeters - math.max(s.startMeters, from)) /
              1000 /
              s.speedKmh *
              60,
    );
  }

  List<DeliveryTrafficSegment> get trafficSegments => _segmentsFrom(0);
  List<DeliveryTrafficSegment> remainingSegments(LatLng? position) =>
      _segmentsFrom(position == null ? 0 : distanceAt(position));
  List<DeliveryTrafficSegment> _segmentsFrom(double from) => List.unmodifiable([
    for (final s in sections)
      if (s.endMeters > from + 0.000001)
        DeliveryTrafficSegment(
          points: _pointsBetween(math.max(from, s.startMeters), s.endMeters),
          level: usesAi
              ? DeliveryTrafficRouteAnalyzer.classifyMultiplier(50 / s.speedKmh)
              : DeliveryTrafficLevel.unavailable,
          maxHistoricalMultiplier: usesAi ? 50 / s.speedKmh : null,
          meanHistoricalMultiplier: usesAi ? 50 / s.speedKmh : null,
          distanceMeters: s.endMeters - s.startMeters,
        ),
  ]);

  List<LatLng> _pointsBetween(double start, double end) {
    final from = start * geometryScale, to = end * geometryScale;
    final result = <LatLng>[_pointAt(from)];
    for (var i = 1; i < points.length - 1; i++) {
      if (_cumulative[i] > from && _cumulative[i] < to) result.add(points[i]);
    }
    result.add(_pointAt(to));
    return List.unmodifiable(result);
  }

  LatLng _pointAt(double meters) {
    for (var i = 1; i < points.length; i++) {
      if (meters > _cumulative[i]) continue;
      final length = _cumulative[i] - _cumulative[i - 1];
      final t = length == 0
          ? 0.0
          : ((meters - _cumulative[i - 1]) / length).clamp(0.0, 1.0);
      final a = points[i - 1], b = points[i];
      return LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );
    }
    return points.last;
  }
}
