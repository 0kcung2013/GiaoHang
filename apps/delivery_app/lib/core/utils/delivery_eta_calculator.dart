import 'dart:math' as math;

import '../ml/delivery_eta_ai_calibrator.dart';

class DeliveryEtaEstimate {
  const DeliveryEtaEstimate({
    required this.minMinutes,
    required this.maxMinutes,
    required this.baselineTravelMinutes,
    required this.calibratedTravelMinutes,
    required this.handlingMinutes,
    required this.rawRouteMinutes,
    required this.usedRouteDuration,
    required this.isPeakHour,
    required this.usedAiCorrection,
    required this.aiModelVersion,
    required this.rawAiTravelMinutes,
    required this.aiTrafficMultiplier,
    required this.aiDatasetLabel,
    required this.aiDatasetScope,
    required this.aiUsesRealtimeTraffic,
    required this.aiFallbackReason,
  });

  final int minMinutes;
  final int maxMinutes;
  final double baselineTravelMinutes;
  final double calibratedTravelMinutes;
  final int handlingMinutes;
  final double? rawRouteMinutes;
  final bool usedRouteDuration;
  final bool isPeakHour;
  final bool usedAiCorrection;
  final String? aiModelVersion;
  final double? rawAiTravelMinutes;
  final double? aiTrafficMultiplier;
  final String aiDatasetLabel;
  final String aiDatasetScope;
  final bool aiUsesRealtimeTraffic;
  final String? aiFallbackReason;

  String get rangeLabel => '$minMinutes–$maxMinutes phút';

  double get aiAdjustmentMinutes =>
      math.max(0, calibratedTravelMinutes - baselineTravelMinutes);
}

/// ETA hybrid: OSRM/distance baseline + TP.HCM historical traffic correction.
///
/// Outside the dataset coverage, the calculator preserves the existing urban
/// peak-hour heuristic instead of extrapolating the AI model.
class DeliveryEtaCalculator {
  DeliveryEtaCalculator._();

  static const double normalReferenceSpeedKmh = 28;
  static const double peakReferenceSpeedKmh = 22;
  static const double normalRouteFactor = 1.10;
  static const double peakRouteFactor = 1.25;
  static const double minPlausibleSpeedKmh = 5;
  static const double maxPlausibleSpeedKmh = 55;
  static const int handlingMinutes = 4;

  static DeliveryEtaEstimate calculate({
    required double distanceMeters,
    double? routeDurationSeconds,
    double? pickupLat,
    double? pickupLng,
    double? deliveryLat,
    double? deliveryLng,
    DateTime? quotedAt,
  }) {
    final now = quotedAt ?? DateTime.now();
    final peakHour = _isPeakHour(now);
    final distanceKm = math.max(0, distanceMeters) / 1000;
    final rawRouteMinutes =
        routeDurationSeconds != null && routeDurationSeconds > 0
        ? routeDurationSeconds / 60
        : null;

    final routeSpeedKmh = rawRouteMinutes == null || rawRouteMinutes <= 0
        ? null
        : distanceKm / (rawRouteMinutes / 60);
    final routeDurationIsPlausible =
        routeSpeedKmh != null &&
        routeSpeedKmh >= minPlausibleSpeedKmh &&
        routeSpeedKmh <= maxPlausibleSpeedKmh;

    final normalDistanceMinutes = distanceKm == 0
        ? 0.0
        : distanceKm / normalReferenceSpeedKmh * 60;
    final normalRouteMinutes = routeDurationIsPlausible
        ? rawRouteMinutes! * normalRouteFactor
        : 0.0;
    final aiBaselineMinutes = math.max(
      normalDistanceMinutes,
      normalRouteMinutes,
    );

    final hasCoordinates =
        pickupLat != null &&
        pickupLng != null &&
        deliveryLat != null &&
        deliveryLng != null;
    final routeIsSupported =
        hasCoordinates &&
        DeliveryEtaAiCalibrator.supportsRoute(
          pickupLat: pickupLat,
          pickupLng: pickupLng,
          deliveryLat: deliveryLat,
          deliveryLng: deliveryLng,
        );
    final aiCalibration = DeliveryEtaAiCalibrator.calibrate(
      distanceKm: distanceKm,
      baselineTravelMinutes: aiBaselineMinutes,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      deliveryLat: deliveryLat,
      deliveryLng: deliveryLng,
      isPeakHour: peakHour,
      quotedAt: now,
    );

    final fallbackDistanceMinutes = distanceKm == 0
        ? 0.0
        : distanceKm /
              (peakHour ? peakReferenceSpeedKmh : normalReferenceSpeedKmh) *
              60;
    final fallbackRouteMinutes = routeDurationIsPlausible
        ? rawRouteMinutes! * (peakHour ? peakRouteFactor : normalRouteFactor)
        : 0.0;
    final fallbackTravelMinutes = math.max(
      fallbackDistanceMinutes,
      fallbackRouteMinutes,
    );
    final baselineTravelMinutes = aiCalibration == null
        ? fallbackTravelMinutes
        : aiBaselineMinutes;
    // The Vietnamese model may add local congestion, but it must never make a
    // peak-hour estimate shorter than the existing trusted fallback.
    final calibratedTravelMinutes = aiCalibration == null
        ? fallbackTravelMinutes
        : math.max(aiCalibration.travelMinutes, fallbackTravelMinutes);
    final effectiveAiMultiplier =
        aiCalibration == null || aiBaselineMinutes <= 0
        ? null
        : calibratedTravelMinutes / aiBaselineMinutes;

    final centerMinutes = math.max(
      8.0,
      calibratedTravelMinutes + handlingMinutes,
    );
    // Keep the ETA range truthful when AI produces a sub-five-minute change.
    // Coarse 5-minute buckets hid the difference between a clear route and a
    // congested route (for example, both became 10–15 minutes). The range is
    // still at least five minutes wide to communicate uncertainty.
    final minMinutes = math.max(8, centerMinutes.floor());
    final maxMinutes = math.max(minMinutes + 5, (centerMinutes * 1.25).ceil());

    return DeliveryEtaEstimate(
      minMinutes: minMinutes,
      maxMinutes: maxMinutes,
      baselineTravelMinutes: baselineTravelMinutes,
      calibratedTravelMinutes: calibratedTravelMinutes,
      handlingMinutes: handlingMinutes,
      rawRouteMinutes: rawRouteMinutes,
      usedRouteDuration: routeDurationIsPlausible,
      isPeakHour: peakHour,
      usedAiCorrection: aiCalibration != null,
      aiModelVersion: aiCalibration?.modelVersion,
      rawAiTravelMinutes: aiCalibration?.rawModelTravelMinutes,
      aiTrafficMultiplier: effectiveAiMultiplier,
      aiDatasetLabel: DeliveryEtaAiCalibrator.datasetLabel,
      aiDatasetScope: DeliveryEtaAiCalibrator.datasetScope,
      aiUsesRealtimeTraffic: DeliveryEtaAiCalibrator.usesRealtimeTraffic,
      aiFallbackReason: aiCalibration != null
          ? null
          : !hasCoordinates
          ? 'Chưa có tọa độ để xác định vùng dữ liệu AI'
          : !routeIsSupported
          ? 'Ngoài vùng dữ liệu giao thông TP.HCM'
          : 'Chưa đủ tín hiệu để hiệu chỉnh bằng AI',
    );
  }

  static bool _isPeakHour(DateTime value) {
    final minuteOfDay = value.hour * 60 + value.minute;
    final morningPeak = minuteOfDay >= 6 * 60 + 30 && minuteOfDay < 9 * 60;
    final eveningPeak =
        minuteOfDay >= 16 * 60 + 30 && minuteOfDay < 19 * 60 + 30;
    return morningPeak || eveningPeak;
  }
}
