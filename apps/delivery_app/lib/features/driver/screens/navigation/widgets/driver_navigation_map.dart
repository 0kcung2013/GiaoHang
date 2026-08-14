import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/utils/delivery_map_utils.dart';
import '../../../../../core/widgets/delivery_map_markers.dart';
import '../utils/driver_navigation_motion.dart';

class DriverNavigationMap extends StatefulWidget {
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

  static Polyline activeRoutePolyline(List<LatLng> points) {
    return Polyline(points: points, color: AppColors.routeLine, strokeWidth: 7);
  }

  @override
  State<DriverNavigationMap> createState() => _DriverNavigationMapState();
}

class _DriverNavigationMapState extends State<DriverNavigationMap>
    with TickerProviderStateMixin {
  static const _markerMotionDuration = Duration(milliseconds: 1100);

  late final AnimationController _markerMotionController;
  LatLng? _displayedDriverPosition;
  LatLng? _motionStart;
  LatLng? _motionTarget;
  List<LatLng>? _remainingRoute;

  @override
  void initState() {
    super.initState();
    _displayedDriverPosition = widget.driverPosition;
    _markerMotionController = AnimationController(
      vsync: this,
      duration: _markerMotionDuration,
    )..addListener(_onMarkerMotionTick);
    _refreshRemainingRoute();
  }

  @override
  void didUpdateWidget(covariant DriverNavigationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final positionChanged = widget.driverPosition != oldWidget.driverPosition;
    if (positionChanged) {
      _animateDriverPosition(widget.driverPosition);
    }
    if (positionChanged || widget.routePoints != oldWidget.routePoints) {
      _refreshRemainingRoute();
    }
  }

  @override
  void dispose() {
    _markerMotionController
      ..removeListener(_onMarkerMotionTick)
      ..dispose();
    super.dispose();
  }

  void _refreshRemainingRoute() {
    final route = widget.routePoints;
    final driver = widget.driverPosition;
    _remainingRoute = route != null && route.length >= 2 && driver != null
        ? DeliveryMapUtils.remainingRoute(fullRoute: route, current: driver)
        : route;
  }

  void _animateDriverPosition(LatLng? target) {
    if (target == null) {
      _markerMotionController.stop();
      _displayedDriverPosition = null;
      return;
    }

    final current = _displayedDriverPosition ?? target;
    _motionStart = current;
    _motionTarget = target;
    if (current == target) {
      _displayedDriverPosition = target;
      return;
    }
    _markerMotionController.forward(from: 0);
  }

  void _onMarkerMotionTick() {
    final from = _motionStart;
    final to = _motionTarget;
    if (!mounted || from == null || to == null) return;
    final progress = Curves.easeOutCubic.transform(
      _markerMotionController.value,
    );
    setState(() {
      _displayedDriverPosition = DriverNavigationMotion.interpolate(
        from,
        to,
        progress,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final pickupPoint = LatLng(widget.order.pickupLat, widget.order.pickupLng);
    final deliveryPoint = LatLng(
      widget.order.deliveryLat,
      widget.order.deliveryLng,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          mapController: widget.mapController,
          options: MapOptions(initialCenter: widget.center, initialZoom: 15),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.datn.giaohang',
              subdomains: const ['a', 'b', 'c'],
              maxNativeZoom: 19,
            ),
            if (_remainingRoute != null && _remainingRoute!.length >= 2)
              PolylineLayer(
                polylines: [
                  DriverNavigationMap.activeRoutePolyline(_remainingRoute!),
                ],
              ),
            MarkerLayer(
              rotate: true,
              markers: [
                DeliveryMapMarkers.pickup(pickupPoint),
                DeliveryMapMarkers.dropoff(deliveryPoint),
                if (_displayedDriverPosition != null)
                  DeliveryMapMarkers.navigationDriver(
                    DeliveryMapMarkers.offsetIfNear(
                      DeliveryMapMarkers.offsetIfNear(
                        _displayedDriverPosition!,
                        pickupPoint,
                      ),
                      deliveryPoint,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
