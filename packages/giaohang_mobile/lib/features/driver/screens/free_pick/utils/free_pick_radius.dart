import '../../../../../core/models/order_model.dart';
import '../../../../../core/utils/geo_utils.dart';

const freePickDefaultRadiusMeters = 2000.0;
const freePickMaximumRadiusMeters = 3000.0;
const freePickRadiusStepMeters = 500.0;

/// Backward-compatible name for the automatic assignment boundary.
const freePickRadiusMeters = freePickDefaultRadiusMeters;

double increaseFreePickRadius(
  double currentMeters, {
  double minimum = freePickDefaultRadiusMeters,
  double maximum = freePickMaximumRadiusMeters,
}) {
  return (currentMeters + freePickRadiusStepMeters)
      .clamp(minimum, maximum)
      .toDouble();
}

double decreaseFreePickRadius(
  double currentMeters, {
  double minimum = freePickDefaultRadiusMeters,
  double maximum = freePickMaximumRadiusMeters,
}) {
  return (currentMeters - freePickRadiusStepMeters)
      .clamp(minimum, maximum)
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
/// the server. Each order uses its own automatic/free-pick distance snapshot;
/// legacy orders keep their previous 2–3 km band.
List<OrderModel> ordersSearchableInFreePick(
  Iterable<OrderModel> orders, {
  required double driverLat,
  required double driverLng,
  required double radiusMeters,
  DateTime? now,
}) {
  final checkedAt = now ?? DateTime.now();
  final effectiveRadius = radiusMeters.clamp(0, 20000).toDouble();
  final searchable = <OrderModel>[];
  for (final order in orders) {
    final distance = order.pickupRoadDistanceMeters;
    final quotedAt = order.pickupRoadQuotedAt;
    final originLat = order.pickupRoadOriginLat;
    final originLng = order.pickupRoadOriginLng;
    if (distance == null ||
        !distance.isFinite ||
        quotedAt == null ||
        originLat == null ||
        originLng == null ||
        checkedAt.difference(quotedAt) > const Duration(seconds: 30) ||
        quotedAt.difference(checkedAt) > const Duration(seconds: 5)) {
      continue;
    }
    final movedMeters = GeoUtils.distanceMeters(
      fromLat: driverLat,
      fromLng: driverLng,
      toLat: originLat,
      toLng: originLng,
    );
    if (movedMeters <= 30 &&
        distance >
            (order.businessPolicy?.autoRadiusMeters ??
                freePickDefaultRadiusMeters) &&
        distance <=
            (order.businessPolicy?.freePickRadiusMeters ??
                freePickMaximumRadiusMeters) &&
        distance <= effectiveRadius) {
      searchable.add(order);
    }
  }
  return searchable.toList(growable: false);
}
