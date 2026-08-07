import 'dart:math' as math;

import 'delivery_eta_ai_model.dart';
import 'delivery_eta_ai_road_profile.dart';

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

/// Applies a guarded TP.HCM historical-traffic correction to an ETA baseline.
class DeliveryEtaAiCalibrator {
  DeliveryEtaAiCalibrator._();

  static const String datasetLabel = 'UTraffic TP.HCM';
  static const String datasetScope = 'Giao thông lịch sử TP.HCM';
  static const bool usesRealtimeTraffic = false;

  // 1st-99th percentile bounds from the curated UTraffic training rows.
  static const double _minLat = 10.740268807;
  static const double _maxLat = 10.88658775;
  static const double _minLng = 106.58906115;
  static const double _maxLng = 106.7949388485;
  static const double _aiWeight = 0.55;
  static const double _minTrafficMultiplier = 1.0;
  static const double _maxTrafficMultiplier = 2.2;
  static const double _minDistanceKm = 0.1;
  static const double _maxDistanceKm = 25;

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
    if (!distanceKm.isFinite ||
        !baselineTravelMinutes.isFinite ||
        distanceKm < _minDistanceKm ||
        distanceKm > _maxDistanceKm ||
        baselineTravelMinutes <= 0 ||
        pickupLat == null ||
        pickupLng == null ||
        deliveryLat == null ||
        deliveryLng == null) {
      return null;
    }

    final midpointLat = (pickupLat + deliveryLat) / 2;
    final midpointLng = (pickupLng + deliveryLng) / 2;
    if (!supportsRoute(
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      deliveryLat: deliveryLat,
      deliveryLng: deliveryLng,
    )) {
      return null;
    }
    final roadFeatures = DeliveryEtaAiRoadProfile.featuresNear(
      latitude: midpointLat,
      longitude: midpointLng,
    );
    if (roadFeatures == null) return null;

    final historicalTrafficMultiplier = predictHistoricalTrafficMultiplierAt(
      latitude: midpointLat,
      longitude: midpointLng,
      quotedAt: quotedAt,
      isPeakHour: isPeakHour,
      roadFeatures: roadFeatures,
    )!;
    final appliedTrafficMultiplier =
        1 + (historicalTrafficMultiplier - 1) * _aiWeight;
    final rawModelTravelMinutes =
        baselineTravelMinutes * historicalTrafficMultiplier;
    final travelMinutes = baselineTravelMinutes * appliedTrafficMultiplier;

    return DeliveryEtaAiCalibration(
      travelMinutes: travelMinutes,
      rawModelTravelMinutes: rawModelTravelMinutes,
      modelVersion: DeliveryEtaAiModel.version,
      historicalTrafficMultiplier: historicalTrafficMultiplier,
      appliedTrafficMultiplier: appliedTrafficMultiplier,
    );
  }

  static bool supportsRoute({
    required double pickupLat,
    required double pickupLng,
    required double deliveryLat,
    required double deliveryLng,
  }) {
    final midpointLat = (pickupLat + deliveryLat) / 2;
    final midpointLng = (pickupLng + deliveryLng) / 2;
    return supportsPoint(latitude: midpointLat, longitude: midpointLng);
  }

  static bool supportsPoint({
    required double latitude,
    required double longitude,
  }) {
    return latitude >= _minLat &&
        latitude <= _maxLat &&
        longitude >= _minLng &&
        longitude <= _maxLng;
  }

  static double? predictHistoricalTrafficMultiplierAt({
    required double latitude,
    required double longitude,
    required DateTime quotedAt,
    required bool isPeakHour,
    DeliveryEtaRoadFeatures? roadFeatures,
  }) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        !supportsPoint(latitude: latitude, longitude: longitude)) {
      return null;
    }

    final hour = quotedAt.hour + quotedAt.minute / 60;
    final dayOfWeek = quotedAt.weekday - 1;
    final profile =
        roadFeatures ??
        DeliveryEtaAiRoadProfile.featuresNear(
          latitude: latitude,
          longitude: longitude,
        );
    if (profile == null) return null;
    final features = <double>[
      latitude,
      longitude,
      math.sin(2 * math.pi * hour / 24),
      math.cos(2 * math.pi * hour / 24),
      math.sin(2 * math.pi * dayOfWeek / 7),
      math.cos(2 * math.pi * dayOfWeek / 7),
      dayOfWeek >= 5 ? 1 : 0,
      isPeakHour ? 1 : 0,
      profile.lengthMeters,
      profile.speedLimitKmh,
      profile.level,
      profile.historicalSpeedRatio,
    ];
    final logMultiplier = DeliveryEtaAiModel.predictLogTrafficMultiplier(
      features,
    );
    return math
        .exp(logMultiplier)
        .clamp(_minTrafficMultiplier, _maxTrafficMultiplier);
  }
}
