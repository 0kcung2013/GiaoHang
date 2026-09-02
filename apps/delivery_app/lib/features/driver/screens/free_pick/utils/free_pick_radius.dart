import '../../../../../core/models/order_model.dart';
import '../../../../../core/utils/geo_utils.dart';

const freePickDefaultRadiusMeters = 2000.0;
const freePickMaximumRadiusMeters = 4000.0;
const freePickRadiusStepMeters = 500.0;

/// Backward-compatible name for the automatic assignment boundary.
const freePickRadiusMeters = freePickDefaultRadiusMeters;

double increaseFreePickRadius(double currentMeters) {
  return (currentMeters + freePickRadiusStepMeters)
      .clamp(freePickDefaultRadiusMeters, freePickMaximumRadiusMeters)
      .toDouble();
}

double decreaseFreePickRadius(double currentMeters) {
  return (currentMeters - freePickRadiusStepMeters)
      .clamp(freePickDefaultRadiusMeters, freePickMaximumRadiusMeters)
      .toDouble();
}

String formatFreePickRadius(double radiusMeters) {
  final kilometers = radiusMeters / 1000;
  final value = kilometers == kilometers.roundToDouble()
      ? kilometers.toStringAsFixed(0)
      : kilometers.toStringAsFixed(1).replaceFirst('.', ',');
  return '$value km';
}

/// FreePick is the manual recovery/search path for every order returned by
/// the server. The automatic 2 km zone is excluded; the driver may manually
/// expand the searchable ring up to 4 km.
List<OrderModel> ordersSearchableInFreePick(
  Iterable<OrderModel> orders, {
  required double driverLat,
  required double driverLng,
  required double radiusMeters,
}) {
  final effectiveRadius = radiusMeters
      .clamp(freePickDefaultRadiusMeters, freePickMaximumRadiusMeters)
      .toDouble();
  final searchable = <OrderModel>[];
  for (final order in orders) {
    final distance = GeoUtils.distanceMeters(
      fromLat: driverLat,
      fromLng: driverLng,
      toLat: order.pickupLat,
      toLng: order.pickupLng,
    );
    if (distance > freePickDefaultRadiusMeters && distance <= effectiveRadius) {
      searchable.add(order);
    }
  }
  return searchable.toList(growable: false);
}
