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
  bool _pollInFlight = false;
  final MapController _mapController = MapController();

  static const _osrmMinInterval = Duration(seconds: 12);
  static const _osrmMinMoveMeters = 70.0;

  TrackingMapPhase get _phase =>
      TrackingMapPhase.fromStatus(widget.order.status);

  @override
  void initState() {
    super.initState();
    _loadRoute();
    _syncLocationPolling();
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
      if (!_phase.tracksLiveDriver) {
        _stableDriverPos = null;
      }
      _syncLocationPolling();
      _loadRoute();
    }
  }

  void _syncLocationPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (!_phase.tracksLiveDriver) return;

    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_pollDriverLocation());
    });
    unawaited(_pollDriverLocation());
  }

  Future<void> _pollDriverLocation() async {
    if (!mounted ||
        !_phase.tracksLiveDriver ||
        widget.order.driverId == null ||
        _pollInFlight) {
      return;
    }
    _pollInFlight = true;
    try {
      // Gọi service trực tiếp để đây là polling thật. Đọc FutureProvider đã
      // hoàn tất chỉ trả lại cache và không đảm bảo có tọa độ mới.
      final driver = await ref
          .read(driverServiceProvider)
          .getDriverForOrder(widget.order.id);
      if (!mounted || !_phase.tracksLiveDriver) return;
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
      _fitCamera(pos);

      final moved = prev == null
          ? 999.0
          : const Distance().as(LengthUnit.Meter, prev, pos);
      if (moved >= _osrmMinMoveMeters || _fullRoute == null) {
        await _loadRoute(explicitDriverPos: pos);
      }
    } catch (_) {
      // Realtime vẫn là luồng chính; polling chỉ là fallback tự phục hồi.
    } finally {
      _pollInFlight = false;
    }
  }

  LatLng? _resolveDriverPos(
    DriverModel? driver,
    ({double lat, double lng})? live,
  ) {
    final livePoint = live == null ? null : LatLng(live.lat, live.lng);
    final profilePoint =
        driver?.currentLat == null || driver?.currentLng == null
        ? null
        : LatLng(driver!.currentLat!, driver.currentLng!);
    final resolved = TrackingDriverPositionResolver.resolve(
      live: livePoint,
      profile: profilePoint,
      stable: _stableDriverPos,
    );
    _stableDriverPos = resolved;
    return resolved;
  }

  Future<void> _loadRoute({LatLng? explicitDriverPos}) async {
    final myKey = ++_routeKey;
    final phase = _phase;
    final driverPos = phase.tracksLiveDriver
        ? explicitDriverPos ??
              _resolveDriverPos(
                ref.read(assignedDriverProvider(widget.order.id)).valueOrNull,
                ref.read(liveDriverLatLngProvider(widget.order.id)),
              )
        : null;

    final pickupPos = LatLng(widget.order.pickupLat, widget.order.pickupLng);
    final deliveryPos = LatLng(
      widget.order.deliveryLat,
      widget.order.deliveryLng,
    );

    final List<LatLng> waypoints;
    if (driverPos == null) {
      waypoints = phase.routeWaypoints(
        driver: null,
        pickup: pickupPos,
        delivery: deliveryPos,
      );
    } else {
      // Chặng hiện tại: TX → đích (Lấy hoặc Giao) — giống map tài xế
      waypoints = phase.routeWaypoints(
        driver: driverPos,
        pickup: pickupPos,
        delivery: deliveryPos,
      );
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
    final result = await OsrmService().getRouteWithWaypoints(
      waypoints: waypoints,
    );
    _lastOsrmCall = DateTime.now();
    if (!mounted || myKey != _routeKey) return;

    if (result != null && result.points.length >= 2) {
      setState(() => _fullRoute = result.points);
      _fitCamera(driverPos);
    } else if (_fullRoute == null && waypoints.length >= 2) {
      setState(() => _fullRoute = waypoints);
      _fitCamera(driverPos);
    }
  }

  void _fitCamera(LatLng? driver) {
    final points = _phase.cameraPoints(
      driver: driver,
      pickup: LatLng(widget.order.pickupLat, widget.order.pickupLng),
      delivery: LatLng(widget.order.deliveryLat, widget.order.deliveryLng),
    );
    try {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.fromLTRB(40, 48, 40, 48),
          maxZoom: 16,
        ),
      );
    } catch (_) {
      try {
        _mapController.move(points.first, 15);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final phase = _phase;
    final driverAsync = phase.tracksLiveDriver
        ? ref.watch(assignedDriverProvider(order.id))
        : const AsyncData<DriverModel?>(null);
    final live = phase.tracksLiveDriver
        ? ref.watch(liveDriverLatLngProvider(order.id))
        : null;

    if (phase.tracksLiveDriver && order.driverId != null) {
      ref.watch(
        driverLocationRealtimeProvider((
          driverId: order.driverId!,
          orderId: order.id,
        )),
      );
    }

    if (phase.tracksLiveDriver) {
      ref.listen<AsyncValue<DriverModel?>>(assignedDriverProvider(order.id), (
        prev,
        next,
      ) {
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
      });

      ref.listen<({double lat, double lng})?>(
        liveDriverLatLngProvider(order.id),
        (previous, next) {
          if (next == null) return;
          final pos = LatLng(next.lat, next.lng);
          _stableDriverPos = pos;
          if (mounted) {
            setState(() {});
            _fitCamera(pos);
          }
          unawaited(_loadRoute(explicitDriverPos: pos));
        },
      );
    }

    final pickupPoint = LatLng(order.pickupLat, order.pickupLng);
    final deliveryPoint = LatLng(order.deliveryLat, order.deliveryLng);
    final midPoint = LatLng(
      (order.pickupLat + order.deliveryLat) / 2,
      (order.pickupLng + order.deliveryLng) / 2,
    );

    final driverPos = phase.visibleDriverPosition(
      latestDriverPosition: _resolveDriverPos(driverAsync.valueOrNull, live),
      delivery: deliveryPoint,
    );

    // Vạch xanh = phần còn lại (đi qua → ngắn dần, bám đường)
    final remaining =
        (_fullRoute != null && _fullRoute!.length >= 2 && driverPos != null)
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
                      phase == TrackingMapPhase.completed
                          ? driverPos
                          : DeliveryMapMarkers.offsetIfNear(
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
                phase.legend,
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
