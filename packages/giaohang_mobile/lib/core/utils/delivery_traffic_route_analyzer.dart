import 'package:latlong2/latlong.dart';

import '../models/delivery_eta_route_profile.dart';

enum DeliveryTrafficLevel { clear, moderate, heavy, congested, unavailable }

class DeliveryTrafficSegment {
  const DeliveryTrafficSegment({
    required this.points,
    required this.level,
    required this.maxHistoricalMultiplier,
    this.distanceMeters = 0,
    this.meanHistoricalMultiplier,
    this.isSynthetic = false,
    this.usesSpeedColors = false,
    this.fallbackReason,
  });

  final List<LatLng> points;
  final DeliveryTrafficLevel level;
  final double? maxHistoricalMultiplier;
  final double distanceMeters;
  final double? meanHistoricalMultiplier;
  final bool isSynthetic;
  final bool usesSpeedColors;
  final String? fallbackReason;
}

/// Render a forecast already computed once for both map and ETA.
class DeliveryTrafficRouteAnalyzer {
  DeliveryTrafficRouteAnalyzer._();
  static DeliveryTrafficLevel classifySpeed(double speed) {
    if (!speed.isFinite || speed <= 0) return DeliveryTrafficLevel.unavailable;
    if (speed >= 35) return DeliveryTrafficLevel.clear;
    if (speed >= 25) return DeliveryTrafficLevel.moderate;
    if (speed >= 20) return DeliveryTrafficLevel.heavy;
    return DeliveryTrafficLevel.congested;
  }

  static List<DeliveryTrafficSegment> analyze({
    required List<LatLng> routePoints,
    required DateTime quotedAt,
    DeliveryEtaRouteProfile? profile,
  }) {
    if (routePoints.length < 2) return const [];
    if (profile != null &&
        profile.forecastAt.isAtSameMomentAs(quotedAt) &&
        profile.points.length == routePoints.length &&
        List.generate(
          routePoints.length,
          (i) => routePoints[i] == profile.points[i],
        ).every((same) => same)) {
      return profile.trafficSegments;
    }
    const distance = Distance();
    return [
      DeliveryTrafficSegment(
        points: routePoints,
        level: DeliveryTrafficLevel.unavailable,
        maxHistoricalMultiplier: null,
        distanceMeters: List.generate(
          routePoints.length - 1,
          (i) => distance(routePoints[i], routePoints[i + 1]),
        ).fold(0.0, (a, b) => a + b),
      ),
    ];
  }

  static DeliveryTrafficLevel classifyMultiplier(
    double? multiplier, {
    bool isSynthetic = false,
  }) {
    if (multiplier == null || !multiplier.isFinite) {
      return DeliveryTrafficLevel.unavailable;
    }
    // Synthetic maps show 25%, 50%, 75% extra travel time. Legacy speed
    // snapshots retain their existing thresholds and km/h legend.
    if (multiplier < 1.25) return DeliveryTrafficLevel.clear;
    if (multiplier < (isSynthetic ? 1.5 : 50 / 34)) {
      return DeliveryTrafficLevel.moderate;
    }
    if (multiplier < (isSynthetic ? 1.75 : 50 / 28)) {
      return DeliveryTrafficLevel.heavy;
    }
    return DeliveryTrafficLevel.congested;
  }
}

extension DeliveryTrafficSegmentSummary on List<DeliveryTrafficSegment> {
  /// Display summary from the shared forecast. This average is not an ETA input.
  /// Missing coverage must not silently become clear traffic.
  double? get meanHistoricalTrafficMultiplier {
    if (isEmpty || hasUnavailableTraffic) return null;
    var distance = 0.0;
    var weighted = 0.0;
    for (final segment in this) {
      final multiplier = segment.meanHistoricalMultiplier;
      if (multiplier == null || !multiplier.isFinite) return null;
      distance += segment.distanceMeters;
      weighted += segment.distanceMeters * multiplier;
    }
    return distance > 0 ? weighted / distance : null;
  }

  bool get hasHistoricalTraffic =>
      any((segment) => segment.level != DeliveryTrafficLevel.unavailable);

  bool get hasUnavailableTraffic =>
      any((segment) => segment.level == DeliveryTrafficLevel.unavailable);
}
