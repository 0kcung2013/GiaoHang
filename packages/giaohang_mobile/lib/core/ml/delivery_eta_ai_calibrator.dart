import 'dart:math' as math;
import 'package:giaohang_domain/giaohang_domain.dart';
import 'delivery_eta_ai_model.dart';

class DeliveryEtaAiCalibration {
  const DeliveryEtaAiCalibration({
    required this.travelMinutes,
    required this.rawModelTravelMinutes,
    required this.modelVersion,
    required this.historicalTrafficMultiplier,
    required this.appliedTrafficMultiplier,
  });

  final double travelMinutes;
  final double rawModelTravelMinutes;
  final String modelVersion;
  final double historicalTrafficMultiplier;
  final double appliedTrafficMultiplier;
}

/// SmartTraffic synthetic speed inference. The geographic gate is a demo policy.
class DeliveryEtaAiCalibrator {
  DeliveryEtaAiCalibrator._();
  static const datasetLabel = 'SmartTraffic TP.HCM';
  static const datasetScope = 'Dữ liệu giao thông mô phỏng';
  static const usesRealtimeTraffic = false;

  static DeliveryEtaAiCalibration? calibrate({
    required double distanceKm,
    required double baselineTravelMinutes,
    required double? pickupLat,
    required double? pickupLng,
    required double? deliveryLat,
    required double? deliveryLng,
    required bool isPeakHour,
    required DateTime quotedAt,
  }) {
    if (!baselineTravelMinutes.isFinite ||
        baselineTravelMinutes <= 0 ||
        pickupLat == null ||
        pickupLng == null ||
        deliveryLat == null ||
        deliveryLng == null ||
        !supportsRoute(
          pickupLat: pickupLat,
          pickupLng: pickupLng,
          deliveryLat: deliveryLat,
          deliveryLng: deliveryLng,
        )) {
      return null;
    }
    final minutes = travelMinutesForDistance(distanceKm, quotedAt);
    if (minutes == null) return null;
    return DeliveryEtaAiCalibration(
      travelMinutes: minutes,
      rawModelTravelMinutes: minutes,
      modelVersion: DeliveryEtaAiModel.version,
      historicalTrafficMultiplier: minutes / (distanceKm / 50 * 60),
      appliedTrafficMultiplier: minutes / baselineTravelMinutes,
    );
  }

  static double? predictSpeed(DateTime at) {
    final wall = VietnamTime.toWallClock(at);
    final value = DeliveryEtaAiModel.predictSpeed([
      wall.hour + wall.minute / 60,
      (wall.weekday - 1).toDouble(),
      wall.weekday >= 6 ? 1 : 0,
    ]);
    return value.isFinite && value > 0 && value <= 90 ? value : null;
  }

  static double? travelMinutesForDistance(double distanceKm, DateTime at) {
    if (!distanceKm.isFinite || distanceKm < 0.1 || distanceKm > 25) {
      return null;
    }
    var elapsed = 0.0;
    for (var remaining = distanceKm * 1000; remaining > 0; remaining -= 250) {
      final speed = predictSpeed(
        at.add(Duration(milliseconds: (elapsed * 60000).floor())),
      );
      if (speed == null) return null;
      elapsed += math.min(250, remaining) / 1000 / speed * 60;
    }
    return elapsed;
  }

  static bool supportsRoute({
    required double pickupLat,
    required double pickupLng,
    required double deliveryLat,
    required double deliveryLng,
  }) =>
      supportsPoint(latitude: pickupLat, longitude: pickupLng) &&
      supportsPoint(latitude: deliveryLat, longitude: deliveryLng);

  static bool supportsPoint({
    required double latitude,
    required double longitude,
  }) =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= 10.740268807 &&
      latitude <= 10.88658775 &&
      longitude >= 106.58906115 &&
      longitude <= 106.7949388485;

  /// Legacy API name retained for map callers; ratio to a 50 km/h display reference.
  /// This is not the old LOS target or the multiplier applied to a 25 km/h baseline.
  static double? predictHistoricalTrafficMultiplierAt({
    required double latitude,
    required double longitude,
    required DateTime quotedAt,
    required bool isPeakHour,
  }) {
    if (!supportsPoint(latitude: latitude, longitude: longitude)) return null;
    final speed = predictSpeed(quotedAt);
    return speed == null ? null : 50 / speed;
  }
}
