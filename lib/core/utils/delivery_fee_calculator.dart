import '../services/osrm_service.dart';
import 'geo_utils.dart';

/// Ước tính phí giao hàng theo khoảng cách (haversine / OSRM).
class DeliveryFeeEstimate {
  const DeliveryFeeEstimate({
    required this.distanceMeters,
    required this.deliveryFee,
    required this.totalPrice,
    required this.serviceType,
    required this.source,
    this.durationSeconds,
  });

  final double distanceMeters;
  final double deliveryFee;
  final double totalPrice;
  final String serviceType;
  /// 'osrm' | 'haversine'
  final String source;
  final double? durationSeconds;

  double get distanceKm => distanceMeters / 1000;
}

class DeliveryFeeCalculator {
  DeliveryFeeCalculator._();

  /// Phí nền (VND).
  static const double baseFee = 15000;

  /// Phí mỗi km sau nền.
  static const double perKm = 5000;

  /// Sàn phí tối thiểu.
  static const double minFee = 25000;

  /// Hệ số dịch vụ nhanh.
  static const double expressMultiplier = 1.35;

  /// Tính phí từ khoảng cách mét + loại dịch vụ.
  static double feeFromDistanceMeters({
    required double distanceMeters,
    required String serviceType,
  }) {
    final km = distanceMeters / 1000;
    var fee = baseFee + perKm * km;
    if (fee < minFee) fee = minFee;
    if (serviceType == 'express') {
      fee *= expressMultiplier;
    }
    // Làm tròn 1000đ
    return (fee / 1000).round() * 1000.0;
  }

  /// Ưu tiên OSRM (đường thật); fallback haversine nếu API lỗi.
  static Future<DeliveryFeeEstimate> estimate({
    required double pickupLat,
    required double pickupLng,
    required double deliveryLat,
    required double deliveryLng,
    required String serviceType,
    OsrmService? osrm,
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

    final fee = feeFromDistanceMeters(
      distanceMeters: meters,
      serviceType: serviceType,
    );

    return DeliveryFeeEstimate(
      distanceMeters: meters,
      deliveryFee: fee,
      totalPrice: fee,
      serviceType: serviceType,
      source: source,
      durationSeconds: duration,
    );
  }
}
