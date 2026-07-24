part of '../tracking_screen.dart';

class _TrackingMap extends ConsumerStatefulWidget {
  final OrderModel order;

  const _TrackingMap({required this.order});

  @override
  ConsumerState<_TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends ConsumerState<_TrackingMap> {
  /// Full polyline chặng hiện tại (OSRM).
  List<LatLng>? _fullRoute;
  int _routeKey = 0;
  String _lastRouteHash = '';
  DateTime _lastOsrmCall = DateTime(2000);
  LatLng? _stableDriverPos;
  Timer? _pollTimer;
  final MapController _mapController = MapController();

  static const _osrmMinInterval = Duration(seconds: 12);
  static const _osrmMinMoveMeters = 70.0;

  @override
  void initState() {
    super.initState();
    _loadRoute();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_pollDriverLocation());
    });
    unawaited(_pollDriverLocation());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _TrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.status != widget.order.status ||
        oldWidget.order.driverId != widget.order.driverId) {
      _lastRouteHash = '';
      _fullRoute = null;
      _loadRoute();
    }
  }

  Future<void> _pollDriverLocation() async {
    if (!mounted || widget.order.driverId == null) return;
    try {
      final driver = await ref.read(
        assignedDriverProvider(widget.order.id).future,
      );
      final lat = driver?.currentLat;
      final lng = driver?.currentLng;
      if (lat == null || lng == null || lat == 0.0 || lng == 0.0) return;

      final pos = LatLng(lat, lng);
      final prev = _stableDriverPos;
      _stableDriverPos = pos;
      ref.read(liveDriverLatLngProvider(widget.order.id).notifier).state = (
        lat: lat,
        lng: lng,
      );
      if (mounted) setState(() {});
      _followCamera(pos);

      final moved = prev == null
          ? 999.0
          : const Distance().as(LengthUnit.Meter, prev, pos);
      if (moved >= _osrmMinMoveMeters || _fullRoute == null) {
        await _loadRoute(explicitDriverPos: pos);
      }
    } catch (_) {}
  }

  LatLng? _resolveDriverPos(
    DriverModel? driver,
    ({double lat, double lng})? live,
  ) {
    if (live != null && live.lat != 0.0 && live.lng != 0.0) {
      final p = LatLng(live.lat, live.lng);
      _stableDriverPos = p;
      return p;
    }
    if (driver?.currentLat != null &&
        driver?.currentLng != null &&
        driver!.currentLat != 0.0 &&
        driver.currentLng != 0.0) {
      final p = LatLng(driver.currentLat!, driver.currentLng!);
      if (_stableDriverPos == null) {
        _stableDriverPos = p;
        return p;
      }
      final back = const Distance().as(
        LengthUnit.Meter,
        p,
        _stableDriverPos!,
      );
      if (back <= 200) {
        _stableDriverPos = p;
        return p;
      }
      return _stableDriverPos;
    }
    return _stableDriverPos;
  }

  Future<void> _loadRoute({LatLng? explicitDriverPos}) async {
    final myKey = ++_routeKey;
    final driver =
        ref.read(assignedDriverProvider(widget.order.id)).valueOrNull;
    final live = ref.read(liveDriverLatLngProvider(widget.order.id));
    final driverPos =
        explicitDriverPos ?? _resolveDriverPos(driver, live);

    final pickupPos = LatLng(widget.order.pickupLat, widget.order.pickupLng);
    final deliveryPos =
        LatLng(widget.order.deliveryLat, widget.order.deliveryLng);

    final target = DeliveryMapUtils.nextTarget(
      status: widget.order.status,
      pickupLat: widget.order.pickupLat,
      pickupLng: widget.order.pickupLng,
      deliveryLat: widget.order.deliveryLat,
      deliveryLng: widget.order.deliveryLng,
    );

    final List<LatLng> waypoints;
    if (driverPos == null) {
      waypoints = [pickupPos, deliveryPos];
    } else {
      // Chặng hiện tại: TX → đích (Lấy hoặc Giao) — giống map tài xế
      waypoints = [driverPos, target];
    }

    final hash =
        '${widget.order.status}_${waypoints.map((w) => '${w.latitude.toStringAsFixed(3)}_${w.longitude.toStringAsFixed(3)}').join('|')}';
    if (hash == _lastRouteHash && _fullRoute != null) return;

    final now = DateTime.now();
    if (now.difference(_lastOsrmCall) < _osrmMinInterval &&
        _fullRoute != null &&
        hash.startsWith(widget.order.status)) {
      return;
    }

    _lastRouteHash = hash;
    final result =
        await OsrmService().getRouteWithWaypoints(waypoints: waypoints);
    _lastOsrmCall = DateTime.now();
    if (!mounted || myKey != _routeKey) return;

    if (result != null && result.points.length >= 2) {
      setState(() => _fullRoute = result.points);
      if (driverPos != null) _followCamera(driverPos);
    } else if (_fullRoute == null && waypoints.length >= 2) {
      setState(() => _fullRoute = waypoints);
    }
  }

  void _followCamera(LatLng driver) {
    final target = DeliveryMapUtils.nextTarget(
      status: widget.order.status,
      pickupLat: widget.order.pickupLat,
      pickupLng: widget.order.pickupLng,
      deliveryLat: widget.order.deliveryLat,
      deliveryLng: widget.order.deliveryLng,
    );
    try {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: [driver, target],
          padding: const EdgeInsets.fromLTRB(40, 48, 40, 48),
          maxZoom: 16,
        ),
      );
    } catch (_) {
      try {
        _mapController.move(driver, 15);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final driverAsync = ref.watch(assignedDriverProvider(order.id));
    final live = ref.watch(liveDriverLatLngProvider(order.id));

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
      (prev, next) {
        final d = next.valueOrNull;
        if (d?.currentLat == null || d?.currentLng == null) return;
        if (d!.currentLat == 0 || d.currentLng == 0) return;
        final existing = ref.read(liveDriverLatLngProvider(order.id));
        if (existing == null) {
          ref.read(liveDriverLatLngProvider(order.id).notifier).state = (
            lat: d.currentLat!,
            lng: d.currentLng!,
          );
        }
      },
    );

    ref.listen<({double lat, double lng})?>(
      liveDriverLatLngProvider(order.id),
      (previous, next) {
        if (next == null) return;
        var pos = LatLng(next.lat, next.lng);
        // Snap T lên vạch xanh (cùng logic map tài xế)
        if (_fullRoute != null && _fullRoute!.length >= 2) {
          pos = DeliveryMapUtils.snapToRoute(
            fullRoute: _fullRoute!,
            current: pos,
          );
        }
        _stableDriverPos = pos;
        if (mounted) {
          setState(() {});
          _followCamera(pos);
        }
        unawaited(_loadRoute(explicitDriverPos: pos));
      },
    );

    final pickupPoint = LatLng(order.pickupLat, order.pickupLng);
    final deliveryPoint = LatLng(order.deliveryLat, order.deliveryLng);
    final midPoint = LatLng(
      (order.pickupLat + order.deliveryLat) / 2,
      (order.pickupLng + order.deliveryLng) / 2,
    );

    var driverPos = _resolveDriverPos(driverAsync.valueOrNull, live);
    if (driverPos != null &&
        _fullRoute != null &&
        _fullRoute!.length >= 2) {
      driverPos = DeliveryMapUtils.snapToRoute(
        fullRoute: _fullRoute!,
        current: driverPos,
      );
    }

    // Vạch xanh = phần còn lại (đi qua → ngắn dần, bám đường)
    final remaining = (_fullRoute != null &&
            _fullRoute!.length >= 2 &&
            driverPos != null)
        ? DeliveryMapUtils.remainingRoute(
            fullRoute: _fullRoute!,
            current: driverPos,
          )
        : _fullRoute;

    return Container(
      height: 260,
      decoration: BoxDecoration(
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: driverPos ?? midPoint,
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.datn.giaohang',
                subdomains: const ['a', 'b', 'c'],
                maxNativeZoom: 19,
              ),
              // Full chặng mờ (ngữ cảnh)
              if (_fullRoute != null && _fullRoute!.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _fullRoute!,
                      color: AppColors.routeLine.withValues(alpha: 0.2),
                      strokeWidth: 4,
                    ),
                  ],
                ),
              // Còn lại — đậm (đi qua thì ngắn dần)
              if (remaining != null && remaining.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: remaining,
                      color: AppColors.routeLine,
                      strokeWidth: 5,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  DeliveryMapMarkers.pickup(pickupPoint),
                  DeliveryMapMarkers.dropoff(deliveryPoint),
                  if (driverPos != null)
                    DeliveryMapMarkers.driver(
                      DeliveryMapMarkers.offsetIfNear(
                        DeliveryMapMarkers.offsetIfNear(
                          driverPos,
                          pickupPoint,
                        ),
                        deliveryPoint,
                      ),
                    ),
                ],
              ),
            ],
          ),
          // Legend
          Positioned(
            left: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: AppRadius.md,
                boxShadow: AppShadow.subtle,
              ),
              child: Text(
                order.status == 'delivering'
                    ? 'T → G · đang giao'
                    : 'T → L · đang lấy hàng',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
