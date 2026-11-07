import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/utils/delivery_map_utils.dart';
import '../../../../../core/widgets/delivery_map_markers.dart';
import '../utils/driver_navigation_route_logic.dart';

class DriverNavigationMap extends StatelessWidget {
  const DriverNavigationMap({
    super.key,
    required this.mapController,
    required this.order,
    required this.center,
    required this.routePoints,
    required this.driverPosition,
    this.otherDestination,
    this.status,
    this.tileProvider,
  });
  final MapController mapController;
  final OrderModel order;
  final LatLng center;
  final List<LatLng>? routePoints;
  final LatLng? driverPosition;
  final LatLng? otherDestination;
  final String? status;
  final TileProvider? tileProvider;

  static Polyline activeRoutePolyline(List<LatLng> points) =>
      Polyline(points: points, color: AppColors.routeLine, strokeWidth: 7);

  static List<LatLng>? remainingRouteFor({
    required List<LatLng>? routePoints,
    required LatLng? driverPosition,
  }) {
    if (routePoints == null ||
        routePoints.length < 2 ||
        driverPosition == null) {
      return null;
    }
    if (DriverNavigationRouteLogic.distanceFromRoute(
          routePoints,
          driverPosition,
        ) >
        60) {
      return null;
    }
    return DeliveryMapUtils.remainingRoute(
      fullRoute: routePoints,
      current: driverPosition,
    );
  }

  double? get _driverBearing {
    // Bearing ngắn hạn bám tiếp tuyến polyline; camera nhìn xa hơn để tránh
    // rung khi đi qua nhiều đỉnh route gần nhau.
    final route = routePoints;
    final position = driverPosition;
    if (route == null || route.length < 2 || position == null) return null;
    return DriverNavigationRouteLogic.navigationMarkerBearingDegrees(
      driverPosition: position,
      routePoints: route,
    );
  }

  @override
  Widget build(BuildContext context) {
    final remainingRoute = remainingRouteFor(
      routePoints: routePoints,
      driverPosition: driverPosition,
    );
    final pickupPoint = LatLng(order.pickupLat, order.pickupLng);
    final deliveryPoint = LatLng(order.deliveryLat, order.deliveryLng);

    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(initialCenter: center, initialZoom: 15),
          children: [
            TileLayer(
              tileProvider: tileProvider,
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.datn.giaohang',
              maxNativeZoom: 19,
            ),
            if (remainingRoute != null && remainingRoute.length >= 2)
              PolylineLayer(
                polylines: [
                  DriverNavigationMap.activeRoutePolyline(remainingRoute),
                ],
              ),
            MarkerLayer(
              rotate: true,
              markers: [
                DeliveryMapMarkers.pickup(pickupPoint),
                DeliveryMapMarkers.dropoff(deliveryPoint),
                if (otherDestination != null)
                  Marker(
                    point: otherDestination!,
                    width: 32,
                    height: 32,
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.textMuted,
                      size: 28,
                    ),
                  ),
                if (driverPosition != null)
                  DeliveryMapMarkers.navigationDriver(
                    driverPosition!,
                    bearingDegrees: _driverBearing,
                  ),
              ],
            ),
          ],
        ),
        if (status != null)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: AppRadius.lg,
                boxShadow: AppShadow.subtle,
              ),
              child: Text(status!, style: AppTextStyles.labelMedium),
            ),
          ),
      ],
    );
  }
}
