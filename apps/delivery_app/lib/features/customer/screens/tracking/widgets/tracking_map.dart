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
  TrackingTrafficRouteSnapshot? _trafficSnapshot;
  TrackingTrafficRouteProgress? _trafficProgress;
  List<DeliveryTrafficSegment> _visibleTrafficSegments = const [];
  TrackingRouteRequestGate _routeRequests = TrackingRouteRequestGate();
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
        oldWidget.order.driverId != widget.order.driverId ||
        oldWidget.order.pickupLat != widget.order.pickupLat ||
        oldWidget.order.pickupLng != widget.order.pickupLng ||
        oldWidget.order.deliveryLat != widget.order.deliveryLat ||
        oldWidget.order.deliveryLng != widget.order.deliveryLng) {
      _routeRequests = TrackingRouteRequestGate();
      _fullRoute = null;
      _trafficSnapshot = null;
      _trafficProgress = null;
      _visibleTrafficSegments = const [];
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
      _isPublishingPollFallback = true;
      ref.read(liveDriverLatLngProvider(widget.order.id).notifier).state = (
        lat: pos.latitude,
        lng: pos.longitude,
      );
      _isPublishingPollFallback = false;
      _animateDriverPosition(pos);

      if (TrackingRouteRefreshPolicy.shouldReload(
        snapshot: _trafficSnapshot,
        current: pos,
      )) {
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
    final request = _routeRequests.tryStart(
      hash: hash,
      hasAcceptedRoute: _fullRoute != null,
      now: DateTime.now(),
    );
    if (request == null) return;

    var accepted = false;
    try {
      final result = await OsrmService().getRouteWithWaypoints(
        waypoints: waypoints,
      );
      if (!mounted || !_routeRequests.isCurrent(request)) return;

      if (result != null && result.points.length >= 2) {
        _acceptRoute(result.points, current: driverPos);
        accepted = true;
        _fitCamera(driverPos);
      } else if (_fullRoute == null && waypoints.length >= 2) {
        _acceptRoute(waypoints, current: driverPos);
        accepted = true;
        _fitCamera(driverPos);
      }
    } catch (_) {
      // Keep the accepted snapshot while OSRM is temporarily unavailable.
    } finally {
      _routeRequests.finish(request, accepted: accepted);
    }
  }

  void _acceptRoute(List<LatLng> route, {LatLng? current}) {
    final snapshot = TrackingTrafficRouteSnapshot.build(
      routePoints: route,
      evaluatedAt: DateTime.now(),
    );
    final progress = TrackingTrafficRouteProgress(snapshot);
    setState(() {
      _fullRoute = snapshot.routePoints;
      _trafficSnapshot = snapshot;
      _trafficProgress = progress;
      _visibleTrafficSegments = progress.advanceTo(current);
    });
  }

  void _animateDriverPosition(LatLng target) {
    final current = _displayedDriverPos ?? _stableDriverPos ?? target;
    _motionStart = current;
    _motionTarget = target;
    _stableDriverPos = target;
    final trafficSegments = _trafficProgress?.advanceTo(target);
    if (current == target) {
      if (mounted) {
        setState(() {
          _displayedDriverPos = target;
          if (trafficSegments != null) {
            _visibleTrafficSegments = trafficSegments;
          }
        });
      }
      return;
    }
    if (mounted && trafficSegments != null) {
      setState(() => _visibleTrafficSegments = trafficSegments);
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
          if (TrackingRouteRefreshPolicy.shouldReload(
            snapshot: _trafficSnapshot,
            current: pos,
          )) {
            unawaited(_loadRoute(explicitDriverPos: pos));
          }
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

    // Chỉ cắt snapshot đã chấm màu; GPS không phân loại lại từng đoạn.
    final map = TrackingMapCanvas(
      mapController: _mapController,
      initialCenter: driverPos ?? midPoint,
      fullRoute: _fullRoute,
      trafficSegments: _visibleTrafficSegments,
      pickupPoint: pickupPoint,
      deliveryPoint: deliveryPoint,
      driverPosition: driverPos,
      completed: phase == TrackingMapPhase.completed,
      isFullscreen: widget.isFullscreen,
      phaseLegend: phase.legend,
      onOpenFullscreen: () => _openTrackingFullscreen(context, widget.order),
      onCloseFullscreen: () => Navigator.of(context).pop(),
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
}
