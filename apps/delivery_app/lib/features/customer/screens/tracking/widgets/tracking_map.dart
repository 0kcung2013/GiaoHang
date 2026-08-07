part of '../tracking_screen.dart';

class _TrackingMap extends ConsumerStatefulWidget {
  const _TrackingMap({required this.order, this.isFullscreen = false});

  final OrderModel order;
  final bool isFullscreen;

  @override
  ConsumerState<_TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends ConsumerState<_TrackingMap>
    with TickerProviderStateMixin {
  /// Full polyline chặng hiện tại (OSRM).
  List<LatLng>? _fullRoute;
  int _routeKey = 0;
  String _lastRouteHash = '';
  DateTime _lastOsrmCall = DateTime(2000);
  LatLng? _stableDriverPos;
  LatLng? _displayedDriverPos;
  LatLng? _motionStart;
  LatLng? _motionTarget;
  late final AnimationController _driverMotionController;
  DateTime? _lastRealtimeAt;
  bool _isPublishingPollFallback = false;
  bool _hasInitialCameraFit = false;
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
    _driverMotionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..addListener(_onDriverMotionTick);
    _loadRoute();
    _syncLocationPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _driverMotionController
      ..removeListener(_onDriverMotionTick)
      ..dispose();
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
        _displayedDriverPos = null;
      }
      _hasInitialCameraFit = false;
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
        _pollInFlight ||
        !TrackingLocationMotion.shouldPollFallback(
          lastRealtimeAt: _lastRealtimeAt,
          now: DateTime.now(),
        )) {
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

      final pos = TrackingDriverPositionResolver.resolve(
        live: null,
        profile: LatLng(lat, lng),
        stable: null,
        demoEmail: driver?.email,
      );
      if (pos == null) return;
      final prev = _stableDriverPos;
      _isPublishingPollFallback = true;
      ref.read(liveDriverLatLngProvider(widget.order.id).notifier).state = (
        lat: pos.latitude,
        lng: pos.longitude,
      );
      _isPublishingPollFallback = false;
      _animateDriverPosition(pos);

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
      demoEmail: driver?.email,
    );
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
    if (_hasInitialCameraFit) return;
    final points = _phase.cameraPoints(
      driver: driver,
      pickup: LatLng(widget.order.pickupLat, widget.order.pickupLng),
      delivery: LatLng(widget.order.deliveryLat, widget.order.deliveryLng),
    );
    try {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: widget.isFullscreen
              ? const EdgeInsets.fromLTRB(40, 112, 40, 96)
              : const EdgeInsets.fromLTRB(40, 48, 40, 48),
          maxZoom: 16,
        ),
      );
      _hasInitialCameraFit = true;
    } catch (_) {
      try {
        _mapController.move(points.first, 15);
        _hasInitialCameraFit = true;
      } catch (_) {}
    }
  }

  void _animateDriverPosition(LatLng target) {
    final current = _displayedDriverPos ?? _stableDriverPos ?? target;
    _motionStart = current;
    _motionTarget = target;
    _stableDriverPos = target;
    if (current == target) {
      if (mounted) setState(() => _displayedDriverPos = target);
      return;
    }
    _driverMotionController.forward(from: 0);
  }

  void _onDriverMotionTick() {
    final from = _motionStart;
    final to = _motionTarget;
    if (!mounted || from == null || to == null) return;
    final progress = Curves.easeOutCubic.transform(
      _driverMotionController.value,
    );
    setState(() {
      _displayedDriverPos = TrackingLocationMotion.interpolate(
        from,
        to,
        progress,
      );
    });
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
          if (_isPublishingPollFallback) return;
          _lastRealtimeAt = DateTime.now();
          final driver = ref.read(assignedDriverProvider(order.id)).valueOrNull;
          final pos = TrackingDriverPositionResolver.resolve(
            live: LatLng(next.lat, next.lng),
            profile: null,
            stable: null,
            demoEmail: driver?.email,
          );
          if (pos == null) return;
          _animateDriverPosition(pos);
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
      latestDriverPosition:
          _displayedDriverPos ??
          _resolveDriverPos(driverAsync.valueOrNull, live),
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
    final trafficSegments = DeliveryTrafficRouteAnalyzer.analyze(
      routePoints: remaining ?? const [],
      quotedAt: DateTime.now(),
    );

    final map = Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: driverPos ?? midPoint,
            initialZoom: 15,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
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
            if (trafficSegments.isNotEmpty)
              DeliveryTrafficRouteLayer(
                segments: trafficSegments,
                strokeWidth: 5,
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
        if (trafficSegments.isNotEmpty)
          Positioned(
            left: AppSpacing.sm,
            top: widget.isFullscreen ? 72 : AppSpacing.sm,
            right: AppSpacing.sm,
            child: DeliveryTrafficMapLegend(segments: trafficSegments),
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
        if (!widget.isFullscreen)
          Positioned(
            right: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: _MapActionButton(
              icon: Icons.fullscreen_rounded,
              label: 'Xem bản đồ',
              onTap: _openFullscreen,
            ),
          ),
        if (widget.isFullscreen)
          Positioned(
            top: AppSpacing.md,
            left: AppSpacing.md,
            child: _MapActionButton(
              icon: Icons.arrow_back_rounded,
              label: 'Theo dõi đơn',
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
      ],
    );

    if (widget.isFullscreen) {
      return Scaffold(body: map);
    }

    return Container(
      height: 260,
      decoration: BoxDecoration(
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: map,
    );
  }

  void _openFullscreen() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => _TrackingFullscreenMap(order: widget.order),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }
}

class _TrackingFullscreenMap extends StatelessWidget {
  const _TrackingFullscreenMap({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return _TrackingMap(order: order, isFullscreen: true);
  }
}

class _MapActionButton extends StatelessWidget {
  const _MapActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppColors.bgCard.withValues(alpha: 0.96),
        borderRadius: AppRadius.full,
        elevation: 3,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.full,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: AppColors.primary, size: 22),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    label,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
