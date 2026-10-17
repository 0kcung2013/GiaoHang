import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/models/order_model.dart';
import '../../../../../core/models/order_route_distance.dart';
import '../../../../../core/providers/customer_providers.dart';
import '../data/driver_order_route_distance_service.dart';

typedef DriverOrderRouteRequest = ({
  DriverRouteQuoteKey key,
  LatLng? driverPosition,
  double? pickupRoadMeters,
  double? fixedPickupMeters,
  double? fixedDeliveryMeters,
});

DriverOrderRouteRequest driverOrderRouteRequest(
  OrderModel order, {
  String? driverId,
  LatLng? driverPosition,
}) => (
  key: (
    orderId: order.id,
    driverId: driverId ?? order.driverId ?? order.offeredDriverId,
    offerExpiresAt: order.offerExpiresAt,
    pickupLat: order.pickupLat,
    pickupLng: order.pickupLng,
    deliveryLat: order.deliveryLat,
    deliveryLng: order.deliveryLng,
  ),
  driverPosition:
      order.routeDistance != null &&
          (driverId == null || driverId == order.driverId)
      ? null
      : driverPosition,
  pickupRoadMeters: order.pickupRoadDistanceMeters,
  fixedPickupMeters: driverId == null || driverId == order.driverId
      ? order.routeDistance?.pickupMeters
      : null,
  fixedDeliveryMeters: driverId == null || driverId == order.driverId
      ? order.routeDistance?.deliveryMeters
      : null,
);

final driverOrderRouteDistanceServiceProvider =
    Provider<DriverOrderRouteDistanceService>(
      (ref) => DriverOrderRouteDistanceService(),
    );

/// Các thẻ dùng chung một kết quả; không gọi lại OSRM theo từng tick GPS.
final driverOrderRouteDistanceProvider = FutureProvider.autoDispose
    .family<OrderRouteDistance, DriverOrderRouteRequest>((ref, request) async {
      if (request.fixedPickupMeters != null &&
          request.fixedDeliveryMeters != null) {
        return OrderRouteDistance(
          pickupMeters: request.fixedPickupMeters,
          deliveryMeters: request.fixedDeliveryMeters,
        );
      }
      var origin = request.driverPosition;
      final service = ref.watch(driverOrderRouteDistanceServiceProvider);
      final driverId = request.key.driverId;
      if (origin == null && driverId != null && driverId.isNotEmpty) {
        try {
          final driver = await ref.watch(
            driverByUserIdProvider(driverId).future,
          );
          if (driver?.currentLat != null && driver?.currentLng != null) {
            origin = LatLng(driver!.currentLat!, driver.currentLng!);
          }
        } catch (_) {
          // Vẫn hiển thị chặng lấy → giao nếu chưa có vị trí tài xế.
        }
      }
      return service.estimate(
        key: request.key,
        driverPosition: origin,
        pickupRoadMeters: request.pickupRoadMeters,
      );
    });
