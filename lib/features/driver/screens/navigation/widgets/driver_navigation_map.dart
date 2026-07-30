import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/utils/delivery_map_utils.dart';
import '../../../../../core/widgets/delivery_map_markers.dart';

class DriverNavigationMap extends StatelessWidget {
  const DriverNavigationMap({
    super.key,
    required this.mapController,
    required this.order,
    required this.center,
    required this.routePoints,
    required this.driverPosition,
  });

  final MapController mapController;
  final OrderModel order;
  final LatLng center;
  final List<LatLng>? routePoints;
  final LatLng? driverPosition;

  @override
  Widget build(BuildContext context) {
    final pickupPoint = LatLng(order.pickupLat, order.pickupLng);
    final deliveryPoint = LatLng(order.deliveryLat, order.deliveryLng);
    final remaining =
        routePoints != null &&
            routePoints!.length >= 2 &&
            driverPosition != null
        ? DeliveryMapUtils.remainingRoute(
            fullRoute: routePoints!,
            current: driverPosition!,
          )
        : routePoints;

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(initialCenter: center, initialZoom: 15),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.datn.giaohang',
          subdomains: const ['a', 'b', 'c'],
          maxNativeZoom: 19,
        ),
        if (routePoints != null && routePoints!.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints!,
                color: AppColors.routeLine.withValues(alpha: 0.22),
                strokeWidth: 5,
              ),
            ],
          ),
        if (remaining != null && remaining.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: remaining,
                color: AppColors.routeLine,
                strokeWidth: 7,
              ),
            ],
          ),
        MarkerLayer(
          rotate: true,
          markers: [
            DeliveryMapMarkers.pickup(pickupPoint),
            DeliveryMapMarkers.dropoff(deliveryPoint),
            if (driverPosition != null)
              DeliveryMapMarkers.navigationDriver(
                DeliveryMapMarkers.offsetIfNear(
                  DeliveryMapMarkers.offsetIfNear(driverPosition!, pickupPoint),
                  deliveryPoint,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
