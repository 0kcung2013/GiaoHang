import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

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

  String get rangeLabel => minMinutes == maxMinutes
      ? '$minMinutes phút'
      : '$minMinutes–$maxMinutes phút';

  double get aiAdjustmentMinutes =>
      calibratedTravelMinutes - baselineTravelMinutes;
}

/// Synthetic AI speed for the current leg, with a 25 km/h fallback. Full-order ETA is calculated by refresh-order-eta.
class DeliveryEtaCalculator {
  DeliveryEtaCalculator._();

  static const double normalReferenceSpeedKmh = 25;
  static const double peakReferenceSpeedKmh = 25;
  static const int handlingMinutes = 5;

  static DeliveryEtaEstimate calculate({
    required double distanceMeters,
    double? routeDurationSeconds,
    double? pickupLat,
    double? pickupLng,
    double? deliveryLat,
    double? deliveryLng,
    DateTime? quotedAt,
    List<LatLng>? routePoints,
  }) {
    final now = quotedAt ?? DateTime.now();
    final peakHour = _isPeakHour(now);
    final distanceKm = math.max(0, distanceMeters) / 1000;
    final rawRouteMinutes =
        routeDurationSeconds != null && routeDurationSeconds > 0
        ? routeDurationSeconds / 60
        : null;

    final normalDistanceMinutes = distanceKm == 0
        ? 0.0
        : distanceKm / normalReferenceSpeedKmh * 60;
    // OSRM contributes road distance; its duration remains comparison metadata.
    final aiBaselineMinutes = normalDistanceMinutes;

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
    final hasRouteShape = routePoints != null && routePoints.length >= 2;
    final shapeSupported =
        !hasRouteShape ||
        routePoints.every(
          (p) => DeliveryEtaAiCalibrator.supportsPoint(
            latitude: p.latitude,
            longitude: p.longitude,
          ),
        );
    final aiCalibration = !shapeSupported
        ? null
        : DeliveryEtaAiCalibrator.calibrate(
            distanceKm: distanceKm,
            baselineTravelMinutes: aiBaselineMinutes,
            pickupLat: pickupLat,
            pickupLng: pickupLng,
            deliveryLat: deliveryLat,
            deliveryLng: deliveryLng,
            isPeakHour: peakHour,
            quotedAt: now,
          );

    final fallbackTravelMinutes = normalDistanceMinutes;
    final baselineTravelMinutes = aiCalibration == null
        ? fallbackTravelMinutes
        : aiBaselineMinutes;
    final calibratedTravelMinutes =
        aiCalibration?.travelMinutes ?? fallbackTravelMinutes;
    final effectiveAiMultiplier =
        aiCalibration == null || aiBaselineMinutes <= 0
        ? null
        : calibratedTravelMinutes / aiBaselineMinutes;

    final centerMinutes = calibratedTravelMinutes + handlingMinutes;
    final minMinutes = centerMinutes.ceil();
    final maxMinutes = minMinutes;

    return DeliveryEtaEstimate(
      minMinutes: minMinutes,
      maxMinutes: maxMinutes,
      baselineTravelMinutes: baselineTravelMinutes,
      calibratedTravelMinutes: calibratedTravelMinutes,
      handlingMinutes: handlingMinutes,
      rawRouteMinutes: rawRouteMinutes,
      usedRouteDuration: false,
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
          : !shapeSupported
          ? 'Chưa đủ dữ liệu giao thông trên toàn tuyến'
          : 'Chưa đủ tín hiệu để hiệu chỉnh bằng AI',
    );
  }

  static bool _isPeakHour(DateTime value) {
    value = VietnamTime.toWallClock(value);
    final minuteOfDay = value.hour * 60 + value.minute;
    final morningPeak = minuteOfDay >= 6 * 60 + 30 && minuteOfDay < 9 * 60;
    final eveningPeak =
        minuteOfDay >= 16 * 60 + 30 && minuteOfDay < 19 * 60 + 30;
    return morningPeak || eveningPeak;
  }
}
