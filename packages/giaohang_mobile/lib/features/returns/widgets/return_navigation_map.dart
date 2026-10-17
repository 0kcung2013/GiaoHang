import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/widgets/delivery_map_markers.dart';
import '../../../core/utils/delivery_map_utils.dart';
import '../../driver/screens/navigation/utils/driver_navigation_route_logic.dart';

class ReturnNavigationMap extends StatefulWidget {
  const ReturnNavigationMap({
    required this.controller,
    required this.destination,
    required this.position,
    required this.route,
    this.destinationIsPickup = true,
    this.followPosition = false,
    this.tileProvider,
    this.onMapReady,
    super.key,
  });

  final MapController controller;
  final LatLng destination;
  final LatLng? position;
  final List<LatLng>? route;
  final bool destinationIsPickup;
  final bool followPosition;
  final TileProvider? tileProvider;
  final VoidCallback? onMapReady;

  /// Camera hoàn hàng cố định hướng Bắc để không xoay theo từng khúc cua.
  static void followPositionCamera(MapController controller, LatLng position) {
    controller.rotate(0);
    controller.move(position, DriverNavigationRouteLogic.navigationZoom);
  }

  @override
  State<ReturnNavigationMap> createState() => _ReturnNavigationMapState();
}

class _ReturnNavigationMapState extends State<ReturnNavigationMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  LatLng? _displayedPosition;
  LatLng? _motionStart;
  LatLng? _motionTarget;
  Duration? _lastSampleTime;
  bool _mapReady = false;
  bool _followDuringMotion = false;

  @override
  void initState() {
    super.initState();
    _displayedPosition = widget.position;
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_onMotionTick);
  }

  @override
  void didUpdateWidget(covariant ReturnNavigationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.position != oldWidget.position) {
      _followDuringMotion = widget.followPosition || oldWidget.followPosition;
      _retarget();
    } else if (widget.followPosition && !oldWidget.followPosition) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _followCamera());
    }
  }

  @override
  void dispose() {
    _motion
      ..removeListener(_onMotionTick)
      ..dispose();
    super.dispose();
  }

  void _retarget() {
    final target = widget.position;
    final current = _displayedPosition;
    if (target == null || current == null || current == target) {
      _motion.stop();
      _displayedPosition = target;
      WidgetsBinding.instance.addPostFrameCallback((_) => _followCamera());
      return;
    }
    // Nhịp mẫu GPS quyết định thời gian nội suy; không dùng easing khiến xe
    // tăng/giảm tốc sau mỗi mẫu. Mẫu mới nối tiếp đúng vị trí đang render.
    final sampleTime = SchedulerBinding.instance.currentFrameTimeStamp;
    final interval = _lastSampleTime == null
        ? const Duration(seconds: 1)
        : sampleTime - _lastSampleTime!;
    _lastSampleTime = sampleTime;
    _motion.duration = Duration(
      microseconds: interval.inMicroseconds.clamp(250000, 1200000),
    );
    _motionStart = current;
    _motionTarget = target;
    _motion.forward(from: 0);
  }

  void _onMotionTick() {
    final from = _motionStart;
    final to = _motionTarget;
    if (!mounted || from == null || to == null) return;
    final route = widget.route;
    _displayedPosition = route != null && route.length >= 2
        ? DeliveryMapUtils.interpolateAlongRoute(
            route: route,
            from: from,
            to: to,
            progress: _motion.value,
          )
        : DeliveryMapUtils.interpolate(from, to, _motion.value);
    _followCamera();
    if (_motion.isCompleted) _followDuringMotion = false;
  }

  void _followCamera() {
    final position = _displayedPosition;
    if (!mounted ||
        !_mapReady ||
        position == null ||
        !(widget.followPosition || _followDuringMotion)) {
      return;
    }
    ReturnNavigationMap.followPositionCamera(widget.controller, position);
  }

  Widget _buildMovingLayers(BuildContext context, Widget? _) {
    final position = _displayedPosition;
    final route = widget.route;
    final remaining = route != null && route.length >= 2 && position != null
        ? DeliveryMapUtils.remainingRoute(fullRoute: route, current: position)
        : route;
    final bearing = position != null && route != null && route.length >= 2
        ? DriverNavigationRouteLogic.navigationMarkerBearingDegrees(
            driverPosition: position,
            routePoints: route,
          )
        : null;
    return Stack(
      children: [
        if (remaining != null && remaining.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: remaining,
                color: AppColors.bgCard.withValues(alpha: 0.92),
                strokeWidth: 11,
              ),
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
            if (widget.destinationIsPickup)
              DeliveryMapMarkers.pickup(widget.destination)
            else
              DeliveryMapMarkers.dropoff(widget.destination),
            if (position != null)
              DeliveryMapMarkers.navigationDriver(
                position,
                bearingDegrees: bearing,
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: widget.controller,
      options: MapOptions(
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        initialCenter: widget.position ?? widget.destination,
        initialZoom: 15,
        onMapReady: () {
          _mapReady = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _followCamera());
          widget.onMapReady?.call();
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.datn.giaohang',
          maxNativeZoom: 19,
          tileProvider: widget.tileProvider,
        ),
        AnimatedBuilder(animation: _motion, builder: _buildMovingLayers),
      ],
    );
  }
}
