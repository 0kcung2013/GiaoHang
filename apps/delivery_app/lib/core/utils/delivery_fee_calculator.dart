import '../services/osrm_service.dart';
import 'delivery_eta_calculator.dart';
import 'delivery_pricing_policy.dart';
import 'geo_utils.dart';

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
  });

  final double distanceMeters;
  final double deliveryFee;
  final double totalPrice;
  final String serviceType;

  /// 'osrm' | 'haversine'
  final String source;
  final double? durationSeconds;
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
  }) async {
    final haversineM = GeoUtils.distanceMeters(
      fromLat: pickupLat,
      fromLng: pickupLng,
      toLat: deliveryLat,
      toLng: deliveryLng,
    );

    double meters = haversineM;
    double? duration;
    var source = 'haversine';

    try {
      final route = await (osrm ?? OsrmService()).getRoute(
        startLat: pickupLat,
        startLng: pickupLng,
        endLat: deliveryLat,
        endLng: deliveryLng,
      );
      if (route != null && route.distanceMeters > 0) {
        meters = route.distanceMeters;
        duration = route.durationSeconds;
        source = 'osrm';
      }
    } catch (_) {
      // giữ haversine
    }

    final feeBreakdown = DeliveryPricingPolicy.calculate(
      distanceMeters: meters,
    );
    final eta = DeliveryEtaCalculator.calculate(
      distanceMeters: meters,
      routeDurationSeconds: duration,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      deliveryLat: deliveryLat,
      deliveryLng: deliveryLng,
      quotedAt: quotedAt,
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
    );
  }
}
