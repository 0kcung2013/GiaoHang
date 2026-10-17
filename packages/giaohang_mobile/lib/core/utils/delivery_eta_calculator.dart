import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../models/delivery_eta_route_profile.dart';
import '../services/utraffic_forecast_service.dart';
import '../services/eta_forecast_service.dart';
import '../ml/eta_simulation/coverage.dart';
import '../constants/eta_simulation_strings.dart';

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
    this.aiIsSynthetic = false,
    this.distanceMeters = 0,
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
  final bool aiIsSynthetic;
  final double distanceMeters;

  /// Whole-route moving speed, excluding preparation and handling time.
  double? get averageSpeedKmh =>
      distanceMeters.isFinite &&
          distanceMeters > 0 &&
          calibratedTravelMinutes.isFinite &&
          calibratedTravelMinutes > 0
      ? distanceMeters * .06 / calibratedTravelMinutes
      : null;

  String get rangeLabel => minMinutes == maxMinutes
      ? '$minMinutes phút'
      : '$minMinutes–$maxMinutes phút';

  double get aiAdjustmentMinutes =>
      calibratedTravelMinutes - baselineTravelMinutes;
}

/// Preview uses the same profile as the map. Full-order ETA is server-owned.
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
    DeliveryEtaRouteProfile? speedProfile,
  }) {
    final now = quotedAt ?? speedProfile?.forecastAt ?? DateTime.now();
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

    final validProfile =
        speedProfile != null &&
        speedProfile.matchesRoute(
          distanceMeters: distanceMeters,
          at: now,
          points: routePoints,
        );
    final profile = validProfile ? speedProfile : null;
    final osrmBaseline = profile?.baselineSeconds;
    final aiBaselineMinutes =
        osrmBaseline != null && osrmBaseline.isFinite && osrmBaseline > 0
        ? osrmBaseline / 60
        : normalDistanceMinutes;
    final baselineTravelMinutes = aiBaselineMinutes;
    final calibratedTravelMinutes = profile == null
        ? normalDistanceMinutes
        : profile.sections.fold<double>(
            0,
            (sum, s) => sum + (s.endMeters - s.startMeters) * .06 / s.speedKmh,
          );
    final usedAi = profile?.usesAi == true;
    final effectiveAiMultiplier = usedAi && aiBaselineMinutes > 0
        ? calibratedTravelMinutes / aiBaselineMinutes
        : null;

    final centerMinutes = calibratedTravelMinutes + handlingMinutes;
    final minMinutes = centerMinutes.ceil();
    final maxMinutes = minMinutes;

    return DeliveryEtaEstimate(
      distanceMeters: math.max(0, distanceMeters),
      minMinutes: minMinutes,
      maxMinutes: maxMinutes,
      baselineTravelMinutes: baselineTravelMinutes,
      calibratedTravelMinutes: calibratedTravelMinutes,
      handlingMinutes: handlingMinutes,
      rawRouteMinutes: rawRouteMinutes,
      usedRouteDuration:
          osrmBaseline != null && osrmBaseline.isFinite && osrmBaseline > 0,
      isPeakHour: peakHour,
      usedAiCorrection: usedAi,
      aiModelVersion: usedAi || profile?.lightgbmTravelMinutes != null
          ? profile?.modelVersion ?? UtrafficForecastService.modelVersion
          : null,
      rawAiTravelMinutes:
          profile?.lightgbmTravelMinutes ??
          (usedAi ? calibratedTravelMinutes : null),
      aiTrafficMultiplier: effectiveAiMultiplier,
      aiDatasetLabel:
          profile?.datasetLabel ??
          (profile?.isSynthetic == true
              ? EtaForecastService.datasetLabel
              : UtrafficForecastService.datasetLabel),
      aiDatasetScope:
          profile?.datasetScope ??
          (profile?.isSynthetic == true
              ? EtaForecastService.datasetScope
              : UtrafficForecastService.datasetScope),
      aiUsesRealtimeTraffic: false,
      aiIsSynthetic: profile?.isSynthetic == true,
      aiFallbackReason: usedAi || profile?.isSynthetic == true
          ? null
          : profile?.fallbackReason == EtaSimulationCoverage.outsideReason
          ? EtaSimulationStrings.outsideCoverage
          : 'Chưa có dự báo vận tốc cho tuyến này',
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
