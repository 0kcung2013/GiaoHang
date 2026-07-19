part of '../tracking_screen.dart';

class _TrackingMap extends ConsumerStatefulWidget {
  final OrderModel order;

  const _TrackingMap({required this.order});

  @override
  ConsumerState<_TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends ConsumerState<_TrackingMap> {
  List<LatLng>? _routePoints;
  int _routeKey = 0;
  String _lastRouteHash = '';
  DateTime _lastOsrmCall = DateTime(2000);
  String _lastDriverPosKey = '';

  static const _osrmMinInterval = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  @override
  void didUpdateWidget(covariant _TrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.status != widget.order.status ||
        oldWidget.order.driverId != widget.order.driverId) {
      _loadRoute();
    }
  }

  Future<void> _loadRoute() async {
    final myKey = ++_routeKey;

    final driver =
        ref.read(assignedDriverProvider(widget.order.id)).valueOrNull;
    final pickupPos = LatLng(widget.order.pickupLat, widget.order.pickupLng);
    final deliveryPos = LatLng(widget.order.deliveryLat, widget.order.deliveryLng);

    final List<LatLng> waypoints;
    if (driver?.currentLat == null ||
        driver?.currentLng == null ||
        driver!.currentLat == 0.0 ||
        driver.currentLng == 0.0) {
      debugPrint('[OSRM_DEBUG] Driver location missing. Routing [pickup→delivery].');
      waypoints = [pickupPos, deliveryPos];
    } else {
      final driverPos = LatLng(driver.currentLat!, driver.currentLng!);
      final distanceToPickup = const Distance().as(LengthUnit.Meter, driverPos, pickupPos);
      final isDriverTooFar = distanceToPickup > 150000;

      if (isDriverTooFar) {
        debugPrint('[OSRM_DEBUG] Driver too far. Routing [pickup→delivery].');
        waypoints = [pickupPos, deliveryPos];
      } else if (widget.order.status == 'delivering' ||
          widget.order.status == 'delivered') {
        waypoints = [driverPos, deliveryPos];
      } else {
        waypoints = [driverPos, pickupPos];
      }
    }

    final statusKey =
        '${widget.order.status}_${waypoints.map((w) => '${w.latitude.toStringAsFixed(4)}_${w.longitude.toStringAsFixed(4)}').join('_')}';
    if (statusKey == _lastRouteHash) {
      debugPrint('[OSRM_DEBUG] route unchanged, skipping');
      return;
    }
    _lastRouteHash = statusKey;

    final now = DateTime.now();
    if (now.difference(_lastOsrmCall) < _osrmMinInterval &&
        _routePoints != null) {
      debugPrint('[OSRM_DEBUG] rate limited, skipping OSRM call');
      return;
    }

    debugPrint('[OSRM_DEBUG] loading route for order status: ${widget.order.status}');
    debugPrint('[OSRM_DEBUG] waypoints: ${waypoints.map((w) => '${w.latitude},${w.longitude}').toList()}');

    final result = await OsrmService().getRouteWithWaypoints(waypoints: waypoints);
    _lastOsrmCall = DateTime.now();

    if (!mounted || myKey != _routeKey) return;

    if (result == null) {
      debugPrint('[OSRM_DEBUG] OSRM service returned null');
    } else {
      debugPrint('[OSRM_DEBUG] result: ${result.points.length} points, ${result.distanceMeters}m');
      setState(() => _routePoints = result.points);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final driverAsync = ref.watch(assignedDriverProvider(order.id));

    if (order.driverId != null) {
      ref.watch(
        driverLocationRealtimeProvider((
          driverId: order.driverId!,
          orderId: order.id,
        )),
      );
    }

    ref.listen<AsyncValue<DriverModel?>>(
      assignedDriverProvider(order.id),
      (previous, next) {
        final driver = next.valueOrNull;
        if (driver?.currentLat != null && driver?.currentLng != null &&
            driver!.currentLat != 0.0 && driver.currentLng != 0.0) {
          final posKey =
              '${driver.currentLat!.toStringAsFixed(4)}_${driver.currentLng!.toStringAsFixed(4)}';
          if (posKey != _lastDriverPosKey) {
            _lastDriverPosKey = posKey;
            _loadRoute();
          }
        }
      },
    );

    final pickupPoint = LatLng(order.pickupLat, order.pickupLng);
    final deliveryPoint = LatLng(order.deliveryLat, order.deliveryLng);
    final midPoint = LatLng(
      (order.pickupLat + order.deliveryLat) / 2,
      (order.pickupLng + order.deliveryLng) / 2,
    );

    final driver = driverAsync.valueOrNull;
    LatLng? driverPos;
    if (driver?.currentLat != null &&
        driver?.currentLng != null &&
        driver!.currentLat != 0.0 &&
        driver.currentLng != 0.0) {
      final pos = LatLng(driver.currentLat!, driver.currentLng!);
      final distanceToPickup = const Distance().as(LengthUnit.Meter, pos, pickupPoint);
      if (distanceToPickup <= 150000) {
        driverPos = pos;
      }
    }

    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: driverPos ?? midPoint,
          initialZoom: 14,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.datn.giaohang',
            subdomains: const ['a', 'b', 'c'],
            maxNativeZoom: 19,
          ),
          MarkerLayer(markers: _buildMarkers(pickupPoint, deliveryPoint, driverPos)),
          if (_routePoints != null)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _routePoints!,
                  color: AppColors.routeLine,
                  strokeWidth: 4,
                ),
              ],
            ),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers(LatLng pickup, LatLng delivery, LatLng? driver) {
    final markers = <Marker>[
      Marker(
        point: pickup,
        child: _MapMarkerIcon(color: AppColors.markerPickup, label: 'L'),
      ),
      Marker(
        point: delivery,
        child: _MapMarkerIcon(color: AppColors.markerDrop, label: 'G'),
      ),
    ];

    if (driver != null) {
      markers.add(
        Marker(
          point: driver,
          child: _MapMarkerIcon(color: AppColors.markerDriver, label: 'T'),
        ),
      );
    }

    return markers;
  }
}
