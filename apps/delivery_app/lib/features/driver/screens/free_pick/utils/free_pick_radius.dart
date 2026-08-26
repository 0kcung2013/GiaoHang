import '../../../../../core/models/order_model.dart';

const freePickRadiusMeters = 2000.0;

/// FreePick is the manual recovery/search path for every order returned by
/// the server. The backend already protects live offers and the 50 km limit.
List<OrderModel> ordersSearchableInFreePick(Iterable<OrderModel> orders) {
  return orders.toList(growable: false);
}
