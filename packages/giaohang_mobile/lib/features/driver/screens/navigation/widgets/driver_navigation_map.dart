import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/utils/delivery_map_utils.dart';
import '../../../../../core/widgets/delivery_map_markers.dart';
import '../utils/driver_navigation_motion.dart';
import '../utils/driver_navigation_route_logic.dart';

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

  /// Chỉ vẽ đoạn đường còn lại phía trước tài xế, giống màn theo dõi khách.
  static List<LatLng>? remainingRouteFor({
    required List<LatLng>? routePoints,
    required LatLng? driverPosition,
  }) {
    if (routePoints == null || routePoints.length < 2) return routePoints;
    if (driverPosition == null) return routePoints;
    return DeliveryMapUtils.remainingRoute(
      fullRoute: routePoints,
      current: driverPosition,
    );
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
    _displayedDriverPosition = _snapToRoute(widget.driverPosition);
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
    final routeChanged = widget.routePoints != oldWidget.routePoints;
    if (routeChanged) {
      _refreshRemainingRoute();
    }
    if (positionChanged) _animateDriverPosition(widget.driverPosition);
  }

  @override
  void dispose() {
    _markerMotionController
      ..removeListener(_onMarkerMotionTick)
      ..dispose();
    super.dispose();
  }

  void _refreshRemainingRoute() {
    _remainingRoute = DriverNavigationMap.remainingRouteFor(
      routePoints: widget.routePoints,
      driverPosition: _snapToRoute(
        _displayedDriverPosition ?? widget.driverPosition,
      ),
    );
  }

  void _animateDriverPosition(LatLng? target) {
    if (target == null) {
      _markerMotionController.stop();
      _displayedDriverPosition = null;
      _refreshRemainingRoute();
      return;
    }

    final current = _snapToRoute(_displayedDriverPosition ?? target) ?? target;
    final snappedTarget = _snapToRoute(target) ?? target;
    _motionStart = current;
    _motionTarget = snappedTarget;
    if (current == snappedTarget) {
      _displayedDriverPosition = snappedTarget;
      _refreshRemainingRoute();
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
      final route = widget.routePoints;
      _displayedDriverPosition = route != null && route.length >= 2
          ? DeliveryMapUtils.interpolateAlongRoute(
              route: route,
              from: from,
              to: to,
              progress: progress,
            )
          : DriverNavigationMotion.interpolate(from, to, progress);
      _remainingRoute = DriverNavigationMap.remainingRouteFor(
        routePoints: route,
        driverPosition: _displayedDriverPosition,
      );
    });
  }

  LatLng? _snapToRoute(LatLng? position) {
    if (position == null) return null;
    final route = widget.routePoints;
    if (route == null || route.length < 2) return position;
    return DeliveryMapUtils.snapToRoute(fullRoute: route, current: position);
  }

  double? get _driverBearing {
    // Bearing ngắn hạn bám tiếp tuyến polyline; camera nhìn xa hơn để tránh
    // rung khi đi qua nhiều đỉnh route gần nhau.
    final route = widget.routePoints;
    final position = _displayedDriverPosition;
    if (route == null || route.length < 2 || position == null) return null;
    return DriverNavigationRouteLogic.navigationMarkerBearingDegrees(
      driverPosition: position,
      routePoints: route,
    );
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
                    _snapToRoute(_displayedDriverPosition)!,
                    bearingDegrees: _driverBearing,
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
