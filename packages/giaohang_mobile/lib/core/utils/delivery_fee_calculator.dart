import '../services/osrm_service.dart';
import '../services/eta_forecast_service.dart';
import '../models/delivery_eta_route_profile.dart';
import 'delivery_eta_calculator.dart';
import 'delivery_pricing_policy.dart';
import 'geo_utils.dart';
import 'package:giaohang_domain/giaohang_domain.dart' show BusinessSettings;

/// Ước tính phí giao hàng theo khoảng cách (haversine / OSRM).
class DeliveryFeeEstimate {
  const DeliveryFeeEstimate({
    required this.distanceMeters,
    required this.deliveryFee,
    required this.totalPrice,
    required this.serviceType,
    required this.source,
    required this.feeBreakdown,
    required this.eta,
    this.durationSeconds,
    this.settings,
  });

  final double distanceMeters;
  final double deliveryFee;
  final double totalPrice;
  final String serviceType;

  /// 'osrm' | 'haversine'
  final String source;
  final double? durationSeconds;
  final BusinessSettings? settings;
  final DeliveryFeeBreakdown feeBreakdown;
  final DeliveryEtaEstimate eta;

  double get distanceKm => distanceMeters / 1000;
}

class DeliveryFeeCalculator {
  DeliveryFeeCalculator._();

  /// Giữ API cũ cho các caller hiện tại; phí tiêu chuẩn do policy đảm nhiệm.
  static double feeFromDistanceMeters({
    required double distanceMeters,
    required String serviceType,
  }) {
    return DeliveryPricingPolicy.calculate(
      distanceMeters: distanceMeters,
    ).total;
  }

  /// Ưu tiên OSRM (đường thật); fallback haversine nếu API lỗi.
  static Future<DeliveryFeeEstimate> estimate({
    required double pickupLat,
    required double pickupLng,
    required double deliveryLat,
    required double deliveryLng,
    required String serviceType,
    OsrmService? osrm,
    DateTime? quotedAt,
    BusinessSettings? settings,
  }) async {
    OsrmRouteResult? route;

    try {
      route = await (osrm ?? OsrmService()).getRoute(
        startLat: pickupLat,
        startLng: pickupLng,
        endLat: deliveryLat,
        endLng: deliveryLng,
      );
    } catch (_) {
      // giữ haversine
    }

    return fromRoadRoute(
      route: route,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      deliveryLat: deliveryLat,
      deliveryLng: deliveryLng,
      serviceType: serviceType,
      quotedAt: quotedAt,
      settings: settings,
    );
  }

  /// Reuse the exact OSRM route previewed on the map for fee and ETA.
  static Future<DeliveryFeeEstimate> fromRoadRoute({
    required OsrmRouteResult? route,
    required double pickupLat,
    required double pickupLng,
    required double deliveryLat,
    required double deliveryLng,
    required String serviceType,
    DateTime? quotedAt,
    BusinessSettings? settings,
  }) async {
    final at = quotedAt ?? DateTime.now();
    final forecast = route == null
        ? null
        : EtaForecastService.canReuseForecast(route, at)
        ? route
        : await EtaForecastService.instance.forecast(route, at);
    return fromRoute(
      route: forecast,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      deliveryLat: deliveryLat,
      deliveryLng: deliveryLng,
      serviceType: serviceType,
      quotedAt: at,
      settings: settings,
    );
  }

  static DeliveryFeeEstimate fromRoute({
    required OsrmRouteResult? route,
    required double pickupLat,
    required double pickupLng,
    required double deliveryLat,
    required double deliveryLng,
    required String serviceType,
    DateTime? quotedAt,
    BusinessSettings? settings,
  }) {
    final hasRoadRoute = route != null && route.distanceMeters > 0;
    final meters = hasRoadRoute
        ? route.distanceMeters
        : GeoUtils.distanceMeters(
            fromLat: pickupLat,
            fromLng: pickupLng,
            toLat: deliveryLat,
            toLng: deliveryLng,
          );
    final duration = hasRoadRoute ? route.durationSeconds : null;
    final source = hasRoadRoute ? 'osrm' : 'haversine';
    final feeBreakdown = DeliveryPricingPolicy.calculate(
      distanceMeters: meters,
      settings: settings,
    );
    final eta = DeliveryEtaCalculator.calculate(
      distanceMeters: meters,
      routeDurationSeconds: duration,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      deliveryLat: deliveryLat,
      deliveryLng: deliveryLng,
      quotedAt: quotedAt,
      routePoints: hasRoadRoute ? route.points : null,
      speedProfile: DeliveryEtaRouteProfile.fromJson(route?.forecastProfile),
    );

    return DeliveryFeeEstimate(
      distanceMeters: meters,
      deliveryFee: feeBreakdown.total,
      totalPrice: feeBreakdown.total,
      serviceType: serviceType,
      source: source,
      durationSeconds: duration,
      feeBreakdown: feeBreakdown,
      eta: eta,
      settings: settings,
    );
  }
}
