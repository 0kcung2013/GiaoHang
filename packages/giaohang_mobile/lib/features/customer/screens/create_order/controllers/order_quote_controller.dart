import '../../../../../core/utils/delivery_fee_calculator.dart';
import '../../../../../core/utils/geo_utils.dart';
import '../../../../../core/services/osrm_service.dart';

typedef OrderQuoteEstimator =
    Future<DeliveryFeeEstimate> Function({
      required double pickupLat,
      required double pickupLng,
      required double deliveryLat,
      required double deliveryLng,
      required String serviceType,
    });

class OrderQuoteController {
  OrderQuoteController({OrderQuoteEstimator? estimator})
    : _estimator = estimator;

  final OrderQuoteEstimator? _estimator;

  Future<DeliveryFeeEstimate> calculate({
    required double pickupLat,
    required double pickupLng,
    required double deliveryLat,
    required double deliveryLng,
    OsrmRouteResult? route,
    DateTime? quotedAt,
  }) {
    if (pickupLat == 0 || pickupLng == 0) {
      throw const OrderQuoteException(
        'Vui lòng chọn điểm lấy hàng trên bản đồ.',
      );
    }
    if (deliveryLat == 0 || deliveryLng == 0) {
      throw const OrderQuoteException(
        'Vui lòng chọn điểm giao hàng trên bản đồ.',
      );
    }

    final directDistance = GeoUtils.distanceMeters(
      fromLat: pickupLat,
      fromLng: pickupLng,
      toLat: deliveryLat,
      toLng: deliveryLng,
    );
    if (directDistance < 50) {
      throw const OrderQuoteException(
        'Điểm lấy và điểm giao quá gần nhau. Vui lòng kiểm tra lại.',
      );
    }

    if (route != null) {
      return DeliveryFeeCalculator.fromRoadRoute(
        route: route,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        deliveryLat: deliveryLat,
        deliveryLng: deliveryLng,
        serviceType: 'standard',
        quotedAt: quotedAt,
      );
    }
    final estimator = _estimator;
    if (estimator == null) {
      return DeliveryFeeCalculator.estimate(
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        deliveryLat: deliveryLat,
        deliveryLng: deliveryLng,
        serviceType: 'standard',
        quotedAt: quotedAt,
      );
    }
    return estimator(
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      deliveryLat: deliveryLat,
      deliveryLng: deliveryLng,
      serviceType: 'standard',
    );
  }
}

class OrderQuoteException implements Exception {
  const OrderQuoteException(this.message);

  final String message;

  @override
  String toString() => message;
}
