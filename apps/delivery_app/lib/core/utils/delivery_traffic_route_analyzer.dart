import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../ml/delivery_eta_ai_calibrator.dart';

enum DeliveryTrafficLevel { clear, moderate, heavy, congested, unavailable }

class DeliveryTrafficSegment {
  const DeliveryTrafficSegment({
    required this.points,
    required this.level,
    required this.maxHistoricalMultiplier,
    this.distanceMeters = 0,
    this.meanHistoricalMultiplier,
  });

  final List<LatLng> points;
  final DeliveryTrafficLevel level;
  final double? maxHistoricalMultiplier;
  final double distanceMeters;
  final double? meanHistoricalMultiplier;
}

/// Colors an OSRM polyline by simulated speed, not observed street congestion.
class DeliveryTrafficRouteAnalyzer {
  DeliveryTrafficRouteAnalyzer._();

  static const double targetChunkMeters = 250;
  static const Distance _distance = Distance();

  static List<DeliveryTrafficSegment> analyze({
    required List<LatLng> routePoints,
    required DateTime quotedAt,
  }) {
    if (routePoints.length < 2) return const [];

    final peakHour = _isPeakHour(quotedAt);
    final rawSegments = <DeliveryTrafficSegment>[];
    var chunk = <LatLng>[routePoints.first];
    var chunkMeters = 0.0;

    for (var index = 1; index < routePoints.length; index++) {
      final previous = routePoints[index - 1];
      final current = routePoints[index];
      chunkMeters += _distance.as(LengthUnit.Meter, previous, current);
      chunk.add(current);

      final isLast = index == routePoints.length - 1;
      if (chunkMeters < targetChunkMeters && !isLast) continue;

      rawSegments.add(
        _scoreChunk(
          points: List.unmodifiable(chunk),
          distanceMeters: chunkMeters,
          quotedAt: quotedAt,
          isPeakHour: peakHour,
        ),
      );
      chunk = <LatLng>[current];
      chunkMeters = 0;
    }

    return List.unmodifiable(_mergeAdjacentLevels(rawSegments));
  }

  static DeliveryTrafficLevel classifyMultiplier(double? multiplier) {
    if (multiplier == null || !multiplier.isFinite) {
      return DeliveryTrafficLevel.unavailable;
    }
    // Display bands from speed = 50 / ratio; these are not learned LOS labels.
    if (multiplier < 1.25) return DeliveryTrafficLevel.clear;
    if (multiplier < 50 / 34) return DeliveryTrafficLevel.moderate;
    if (multiplier < 50 / 28) return DeliveryTrafficLevel.heavy;
    return DeliveryTrafficLevel.congested;
  }

  static DeliveryTrafficSegment _scoreChunk({
    required List<LatLng> points,
    required double distanceMeters,
    required DateTime quotedAt,
    required bool isPeakHour,
  }) {
    final midpoint = points[points.length ~/ 2];
    final multiplier =
        !points.every(
          (p) => DeliveryEtaAiCalibrator.supportsPoint(
            latitude: p.latitude,
            longitude: p.longitude,
          ),
        )
        ? null
        : DeliveryEtaAiCalibrator.predictHistoricalTrafficMultiplierAt(
            latitude: midpoint.latitude,
            longitude: midpoint.longitude,
            quotedAt: quotedAt,
            isPeakHour: isPeakHour,
          );
    return DeliveryTrafficSegment(
      points: points,
      level: classifyMultiplier(multiplier),
      maxHistoricalMultiplier: multiplier,
      distanceMeters: distanceMeters,
      meanHistoricalMultiplier: multiplier,
    );
  }

  static List<DeliveryTrafficSegment> _mergeAdjacentLevels(
    List<DeliveryTrafficSegment> input,
  ) {
    final merged = <DeliveryTrafficSegment>[];
    for (final segment in input) {
      if (segment.points.length < 2) continue;
      if (merged.isEmpty || merged.last.level != segment.level) {
        merged.add(segment);
        continue;
      }

      final previous = merged.removeLast();
      merged.add(
        DeliveryTrafficSegment(
          points: List.unmodifiable([
            ...previous.points,
            ...segment.points.skip(1),
          ]),
          level: segment.level,
          maxHistoricalMultiplier: _maxNullable(
            previous.maxHistoricalMultiplier,
            segment.maxHistoricalMultiplier,
          ),
          distanceMeters: previous.distanceMeters + segment.distanceMeters,
          meanHistoricalMultiplier:
              previous.meanHistoricalMultiplier == null ||
                  segment.meanHistoricalMultiplier == null
              ? null
              : (previous.meanHistoricalMultiplier! * previous.distanceMeters +
                        segment.meanHistoricalMultiplier! *
                            segment.distanceMeters) /
                    (previous.distanceMeters + segment.distanceMeters),
        ),
      );
    }
    return merged;
  }

  static double? _maxNullable(double? first, double? second) {
    if (first == null) return second;
    if (second == null) return first;
    return math.max(first, second);
  }

  static bool _isPeakHour(DateTime value) {
    value = VietnamTime.toWallClock(value);
    final minuteOfDay = value.hour * 60 + value.minute;
    return (minuteOfDay >= 6 * 60 + 30 && minuteOfDay < 9 * 60) ||
        (minuteOfDay >= 16 * 60 + 30 && minuteOfDay < 19 * 60 + 30);
  }
}

extension DeliveryTrafficSegmentSummary on List<DeliveryTrafficSegment> {
  /// Display summary at the quoted time. ETA separately advances time along
  /// the route using predicted speed; this average is not an ETA input.
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
