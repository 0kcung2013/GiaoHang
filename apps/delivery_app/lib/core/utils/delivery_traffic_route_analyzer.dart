import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../ml/delivery_eta_ai_calibrator.dart';

enum DeliveryTrafficLevel { clear, moderate, heavy, congested, unavailable }

class DeliveryTrafficSegment {
  const DeliveryTrafficSegment({
    required this.points,
    required this.level,
    required this.maxHistoricalMultiplier,
  });

  final List<LatLng> points;
  final DeliveryTrafficLevel level;
  final double? maxHistoricalMultiplier;
}

/// Converts an OSRM polyline into short, historically-scored traffic sections.
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
    if (multiplier < 1.15) return DeliveryTrafficLevel.clear;
    if (multiplier < 1.35) return DeliveryTrafficLevel.moderate;
    if (multiplier < 1.55) return DeliveryTrafficLevel.heavy;
    return DeliveryTrafficLevel.congested;
  }

  static DeliveryTrafficSegment _scoreChunk({
    required List<LatLng> points,
    required DateTime quotedAt,
    required bool isPeakHour,
  }) {
    final midpoint = points[points.length ~/ 2];
    final multiplier =
        DeliveryEtaAiCalibrator.predictHistoricalTrafficMultiplierAt(
          latitude: midpoint.latitude,
          longitude: midpoint.longitude,
          quotedAt: quotedAt,
          isPeakHour: isPeakHour,
        );
    return DeliveryTrafficSegment(
      points: points,
      level: classifyMultiplier(multiplier),
      maxHistoricalMultiplier: multiplier,
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
    final minuteOfDay = value.hour * 60 + value.minute;
    return (minuteOfDay >= 6 * 60 + 30 && minuteOfDay < 9 * 60) ||
        (minuteOfDay >= 16 * 60 + 30 && minuteOfDay < 19 * 60 + 30);
  }
}

extension DeliveryTrafficSegmentSummary on List<DeliveryTrafficSegment> {
  bool get hasHistoricalTraffic =>
      any((segment) => segment.level != DeliveryTrafficLevel.unavailable);

  bool get hasUnavailableTraffic =>
      any((segment) => segment.level == DeliveryTrafficLevel.unavailable);
}
