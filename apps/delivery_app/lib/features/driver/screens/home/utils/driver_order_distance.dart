import '../../../../../core/models/order_model.dart';
import '../../../../../core/utils/geo_utils.dart';

double? totalOrderDistanceMeters({
  required OrderModel order,
  required double? driverLat,
  required double? driverLng,
}) {
  if (!_isValidCoordinate(driverLat, driverLng) ||
      !_isValidCoordinate(order.pickupLat, order.pickupLng) ||
      !_isValidCoordinate(order.deliveryLat, order.deliveryLng)) {
    return null;
  }

  final pickupDistance = GeoUtils.distanceMeters(
    fromLat: driverLat!,
    fromLng: driverLng!,
    toLat: order.pickupLat,
    toLng: order.pickupLng,
  );
  return totalOrderDistanceFromPickup(
    order: order,
    pickupDistanceMeters: pickupDistance,
  );
}

double? totalOrderDistanceFromPickup({
  required OrderModel order,
  required double? pickupDistanceMeters,
}) {
  if (pickupDistanceMeters == null ||
      !pickupDistanceMeters.isFinite ||
      pickupDistanceMeters < 0 ||
      !_isValidCoordinate(order.pickupLat, order.pickupLng) ||
      !_isValidCoordinate(order.deliveryLat, order.deliveryLng)) {
    return null;
  }

  final deliveryDistance = GeoUtils.distanceMeters(
    fromLat: order.pickupLat,
    fromLng: order.pickupLng,
    toLat: order.deliveryLat,
    toLng: order.deliveryLng,
  );
  return pickupDistanceMeters + deliveryDistance;
}

String totalOrderDistanceText(double? distanceMeters) {
  if (distanceMeters == null ||
      !distanceMeters.isFinite ||
      distanceMeters < 0) {
    return 'Chưa có tổng quãng đường';
  }
  if (distanceMeters < 1000) {
    final roundedMeters = (distanceMeters / 50).round() * 50;
    return 'Tổng 2 chặng · ~${roundedMeters.clamp(0, 950)} m';
  }
  final distanceKm = distanceMeters / 1000;
  final decimals = distanceKm < 10 ? 1 : 0;
  return 'Tổng 2 chặng · ~${distanceKm.toStringAsFixed(decimals)} km';
}

String distanceKilometersText(double? distanceMeters) {
  if (distanceMeters == null ||
      !distanceMeters.isFinite ||
      distanceMeters < 0) {
    return '—';
  }
  final distanceKm = distanceMeters / 1000;
  final decimals = distanceKm < 10 ? 1 : 0;
  return '${distanceKm.toStringAsFixed(decimals)} km';
}

bool _isValidCoordinate(double? lat, double? lng) {
  return lat != null &&
      lng != null &&
      lat.isFinite &&
      lng.isFinite &&
      lat >= -90 &&
      lat <= 90 &&
      lng >= -180 &&
      lng <= 180 &&
      (lat != 0 || lng != 0);
}
