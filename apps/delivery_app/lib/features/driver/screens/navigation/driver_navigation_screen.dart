import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../../../../core/location/driver_location_producer_policy.dart';
import '../../../../core/location/driver_foreground_location_service.dart';
import '../../../../core/models/delivery_proof_model.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/providers/customer_providers.dart';
import '../../../../core/providers/driver_nav_session_provider.dart';
import '../../../../core/providers/driver_wallet_providers.dart';
import '../../../../core/providers/location_providers.dart';
import '../../../../core/services/osrm_service.dart';
import '../../../../core/services/delivery_proof_watermark_service.dart';
import '../../../../core/utils/delivery_map_utils.dart';
import '../../../reviews/widgets/driver_rate_customer_sheet.dart';
import '../../../order_contact/models/order_contact_message.dart';
import '../../../order_contact/order_contact_strings.dart';
import '../../../order_contact/widgets/arrival_contact_sheet.dart';
import '../../../order_contact/widgets/demo_call_sheet.dart';
import '../../../order_contact/widgets/order_contact_chat_sheet.dart';
import '../../../risk_reports/data/risk_intervention_repository.dart';
import 'models/driver_arrival_policy.dart';
import 'models/driver_delivery_workflow.dart';
import 'utils/driver_navigation_motion.dart';
import 'utils/driver_navigation_route_logic.dart';
import 'utils/driver_navigation_position_smoother.dart';
import 'utils/driver_navigation_resume_policy.dart';
import 'widgets/driver_delivery_confirmation_sheet.dart';
import 'widgets/driver_delivery_success_dialog.dart';
import 'widgets/driver_navigation_map.dart';
import 'widgets/driver_navigation_view.dart';
import 'widgets/driver_wallet_debit_dialog.dart';

part 'driver_navigation_delivery_actions.dart';
part 'driver_navigation_contact_actions.dart';

class DriverNavigationScreen extends ConsumerStatefulWidget {
  final OrderModel order;
  final RiskInterventionRepository? riskInterventionRepository;

  const DriverNavigationScreen({
    super.key,
    required this.order,
    this.riskInterventionRepository,
  });

  @override
  ConsumerState<DriverNavigationScreen> createState() =>
      _DriverNavigationScreenState();
}

class _DriverNavigationScreenState
    extends ConsumerState<DriverNavigationScreen> {
  late OrderModel _currentOrder;
  final MapController _mapController = MapController();
  List<LatLng>? _routePoints;
  List<OsrmNavigationStep> _navigationSteps = const [];
  int _activeNavigationStepIndex = 0;
  double? _totalDistance;
  double? _totalDuration;
  bool _isUpdatingStatus = false;

  LatLng? _driverPos;
  int _simRouteIndex = 0;

  Timer? _routeRefreshTimer;
  Timer? _simTimer; // Chỉ dùng khi web simulate
  StreamSubscription<Position>? _posStream; // GPS stream trên thiết bị thật

  String? _lastRouteStatus;
  int _routeKey = 0;
  DateTime _lastCameraFollowAt = DateTime.fromMillisecondsSinceEpoch(0);
  LatLng? _lastCameraFollowPosition;

  bool _arrivedAtTarget = false;
  bool _pickupConfirmed = false;
  bool _hasRestoredNavigationPosition = false;

  static const Duration _simulationTick = Duration(milliseconds: 250);
  static const double _simulationSpeedMetersPerSecond = 15.0;

  late final StateController<String?> _navigationOwner;
  late final DriverNavSessionsNotifier _navSessionsNotifier;
  late final RiskInterventionRepository? _riskInterventionRepository;

  void _updateUi(VoidCallback update) => setState(update);

  User? get _authenticatedUser {
    try {
      return Supabase.instance.client.auth.currentUser;
    } on AssertionError {
      // Isolated widget tests and previews can mount before app bootstrap.
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _riskInterventionRepository =
        widget.riskInterventionRepository ?? _createRiskRepository();
    _navigationOwner = ref.read(activeDriverNavigationOrderProvider.notifier);
    _navSessionsNotifier = ref.read(driverNavSessionsProvider.notifier);
    _restoreNavSession();
    _startRouteRefresh();
    final orderId = _currentOrder.id;
    // Riverpod không cho phép đổi provider trong initState/build.
    // Future chạy sau khi frame mount hoàn tất, rồi mới bootstrap navigation.
    Future<void>(() {
      if (!mounted) return;
      _navigationOwner.state = orderId;
      unawaited(_startForegroundLocationService());
      unawaited(_ensureInitialRoute());
    });
  }

  RiskInterventionRepository? _createRiskRepository() {
    try {
      return SupabaseRiskInterventionRepository();
    } on AssertionError {
      // Widget tests and isolated previews may mount without app bootstrap.
      return null;
    }
  }

  Future<void> _startForegroundLocationService() async {
    if (kIsWeb) return;
    final driverUserId = _currentOrder.driverId;
    if (driverUserId == null || driverUserId.isEmpty) return;
    final driver = await ref.read(driverByUserIdProvider(driverUserId).future);
    if (driver == null || !mounted) return;
    await DriverForegroundLocationService.start(
      driverProfileId: driver.id,
      driverUserId: driverUserId,
    );
  }

  Future<void> _ensureInitialRoute() async {
    // Đợi hydrate SharedPreferences (hot restart Shift+R).
    await _navSessionsNotifier.ready;
    if (!mounted) return;
    _restoreNavSession();

    final restoredPosition = _driverPos;
    if (restoredPosition != null) {
      await _onDriverMoved(
        restoredPosition,
        source: DriverPositionSource.restoredSession,
        forceSync: true,
      );
      if (!mounted) return;
    }

    // Chỉ khởi động GPS/simulation sau khi session trên đĩa đã được hydrate.
    // Nếu làm ngược lại, kết quả GPS/profile async có thể ghi đè tiến trình
    // vừa restore và khiến route chạy lại từ đầu.
    await _startMovement();
    if (!mounted) return;

    if (_driverPos == null) {
      final order = _currentOrder;
      final driverId = order.driverId;
      if (driverId != null && driverId.isNotEmpty) {
        try {
          final d = await ref.read(driverByUserIdProvider(driverId).future);
          if (d?.currentLat != null &&
              d?.currentLng != null &&
              d!.currentLat != 0 &&
              d.currentLng != 0) {
            _driverPos = LatLng(d.currentLat!, d.currentLng!);
          }
        } catch (_) {}
      }
      if (mounted) setState(() {});
    }

    _lastRouteStatus = null;
    await _loadRoute();
  }

  @override
  void didUpdateWidget(covariant DriverNavigationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.status != widget.order.status) {
      _currentOrder = widget.order;
      _lastRouteStatus = null;
      _arrivedAtTarget =
          false; // Reset trạng thái đến nơi để kiểm tra cho chặng tiếp theo
      _pickupConfirmed = false;
      _simRouteIndex = 0;
      _loadRoute();
    }
  }

  @override
  void dispose() {
    final orderId = _currentOrder.id;
    // Không đổi provider trực tiếp trong dispose; tránh Riverpod lifecycle error.
    Future<void>(() {
      if (_navigationOwner.state == orderId) {
        _navigationOwner.state = null;
      }
    });
    _persistNavSession();
    _routeRefreshTimer?.cancel();
    _simTimer?.cancel();
    _posStream?.cancel();
    super.dispose();
  }

  void _restoreNavSession() {
    final sessions = ref.read(driverNavSessionsProvider);
    final saved = sessions[_currentOrder.id];
    if (saved == null) return;
    if (!saved.canRestoreFor(
      activeOrderId: _currentOrder.id,
      activeStatus: _currentOrder.status,
    )) {
      unawaited(_navSessionsNotifier.remove(_currentOrder.id));
      return;
    }
    // Cùng đơn: cho phép restore cả khi status khớp.
    // Nếu đã delivering mà session còn picking_up → vẫn lấy vị trí (đã tới lấy).
    if (saved.lat == 0 && saved.lng == 0) return;

    _driverPos = LatLng(saved.lat, saved.lng);
    _hasRestoredNavigationPosition = true;
    // Chỉ giữ cờ arrived nếu cùng chặng (tránh kẹt banner chặng cũ).
    if (saved.status == _currentOrder.status) {
      // Giữ bước trung gian "đã nhận" để tài xế chủ động gạt bắt đầu giao.
      _pickupConfirmed = saved.pickupConfirmed;
      _arrivedAtTarget = saved.arrivedAtTarget;
      _simRouteIndex = saved.simRouteIndex;
    } else {
      _arrivedAtTarget = false;
      _pickupConfirmed = false;
      _simRouteIndex = 0;
    }
    debugPrint(
      '[NAV_SESSION] restore order=${_currentOrder.id} '
      'pos=(${saved.lat},${saved.lng}) simIndex=$_simRouteIndex '
      'arrived=$_arrivedAtTarget pickupConfirmed=$_pickupConfirmed '
      'savedStatus=${saved.status} '
      'orderStatus=${_currentOrder.status}',
    );
  }

  void _persistNavSession() {
    final pos = _driverPos;
    if (pos == null) return;
    final next = DriverNavSession(
      orderId: _currentOrder.id,
      status: _currentOrder.status,
      lat: pos.latitude,
      lng: pos.longitude,
      arrivedAtTarget: _arrivedAtTarget,
      pickupConfirmed: _pickupConfirmed,
      simRouteIndex: _simRouteIndex,
      updatedAt: DateTime.now(),
    );
    unawaited(_navSessionsNotifier.upsert(next));
  }

  void _startRouteRefresh() {
    if (kIsWeb) {
      return;
    }
    _routeRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted || _driverPos == null) return;
      // Cho phép refresh khoảng cách; _loadRoute tự skip nếu gần như đứng yên.
      _lastRouteStatus = null;
      unawaited(_loadRoute());
    });
  }

  Future<void> _startMovement() async {
    if (kIsWeb) {
      // Web không có GPS stream liên tục → dùng fallback pickup + simulate
      await _initWebFallback();
    } else {
      await _startGpsStream();
    }
  }

  Future<void> _startGpsStream() async {
    // Ưu tiên session đã restore trong initState.
    if (_driverPos == null) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null && last.latitude != 0.0 && last.longitude != 0.0) {
          await _onDriverMoved(
            LatLng(last.latitude, last.longitude),
            source: DriverPositionSource.deviceGps,
          );
        } else {
          final current = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
            ),
          );
          await _onDriverMoved(
            LatLng(current.latitude, current.longitude),
            source: DriverPositionSource.deviceGps,
          );
        }
      } catch (e) {
        debugPrint('[GPS_STREAM] seed position failed: $e');
      }
    } else if (_routePoints == null) {
      await _loadRoute();
    }

    // Điểm GPS demo là cố định nên sẽ kéo marker về đầu tuyến sau hot restart.
    // Session là tọa độ cuối đã đồng bộ; giữ nó cho đến khi hành trình kết thúc.
    if (DriverNavigationResumePolicy.shouldKeepRestoredPosition(
      hasRestoredPosition: _hasRestoredNavigationPosition,
      driverEmail: _authenticatedUser?.email,
    )) {
      return;
    }

    _posStream?.cancel();
    _posStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            distanceFilter: 5, // cập nhật mỗi 5m di chuyển thật
          ),
        ).listen(
          (pos) {
            if (!mounted) return;
            final newPos = LatLng(pos.latitude, pos.longitude);
            _onDriverMoved(newPos, source: DriverPositionSource.deviceGps);
          },
          onError: (e) {
            debugPrint('[GPS_STREAM] Error: $e');
          },
        );
  }

  Future<void> _initWebFallback() async {
    final order = _currentOrder;
    final driverId = order.driverId;

    // Đã có session restore → chỉ load route / tiếp tục sim, không nhảy về pickup.
    if (_driverPos != null) {
      debugPrint(
        '[GPS_WEB] Using restored session pos: '
        '(${_driverPos!.latitude}, ${_driverPos!.longitude})',
      );
      await _loadRoute();
      return;
    }

    LatLng? startPos;
    var source = DriverPositionSource.targetFallback;

    // 1. Thử lấy GPS thực tế của trình duyệt web
    final gpsPos = ref.read(currentPositionProvider).valueOrNull;
    if (gpsPos != null && gpsPos.latitude != 0.0 && gpsPos.longitude != 0.0) {
      startPos = LatLng(gpsPos.latitude, gpsPos.longitude);
      source = DriverPositionSource.browserGps;
      debugPrint(
        '[GPS_WEB] Initialized driver at browser GPS location: '
        '(${startPos.latitude}, ${startPos.longitude})',
      );
    }
    // 2. Profile tài xế trên Supabase (vị trí đã upload trước đó)
    else if (driverId != null && driverId.isNotEmpty) {
      try {
        final driverModel = await ref.read(
          driverByUserIdProvider(driverId).future,
        );
        if (driverModel != null &&
            driverModel.currentLat != null &&
            driverModel.currentLat != 0.0 &&
            driverModel.currentLng != null &&
            driverModel.currentLng != 0.0) {
          startPos = LatLng(driverModel.currentLat!, driverModel.currentLng!);
          source = DriverPositionSource.serverProfile;
          debugPrint(
            '[GPS_WEB] Initialized driver at profile location: '
            '(${startPos.latitude}, ${startPos.longitude})',
          );
        } else {
          debugPrint('[GPS_WEB] Driver profile has no usable coordinates.');
        }
      } catch (e) {
        debugPrint('[GPS_WEB] Failed to fetch driver profile: $e.');
      }
    }

    if (startPos == null) {
      _arrivedAtTarget = false;
      await _loadRoute();
      return;
    }

    await _onDriverMoved(startPos, source: source);
  }

  void _startSimulation({bool resume = true}) {
    _simTimer?.cancel();
    final points = _routePoints;
    if (points == null || points.length < 2) {
      debugPrint(
        '[SIM] Cannot start simulation: _routePoints is null or too short',
      );
      return;
    }

    // Tiếp tục từ điểm gần vị trí hiện tại / session — không reset index = 0.
    if (resume && _driverPos != null) {
      final nearest = DriverNavigationRouteLogic.nearestRouteIndex(
        points,
        _driverPos!,
      );
      // Giữ index session nếu vẫn hợp lệ và không lùi quá xa so với nearest.
      if (_simRouteIndex > nearest &&
          _simRouteIndex < points.length &&
          (_simRouteIndex - nearest).abs() <= 8) {
        // giữ _simRouteIndex
      } else {
        _simRouteIndex = (nearest + 1).clamp(1, points.length);
      }
    } else if (!resume) {
      _simRouteIndex = 1;
    } else {
      _simRouteIndex = _simRouteIndex.clamp(1, points.length);
    }

    debugPrint(
      '[SIM] Starting simulation points=${points.length} '
      'fromIndex=$_simRouteIndex resume=$resume',
    );

    _simTimer = Timer.periodic(_simulationTick, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!DriverDeliveryWorkflow.canSimulateMovement(
        status: _currentOrder.status,
        pickupConfirmed: _pickupConfirmed,
        arrivedAtTarget: _arrivedAtTarget,
      )) {
        timer.cancel();
        _persistNavSession();
        return;
      }
      final pts = _routePoints;
      if (pts == null) {
        return;
      }
      final current = _driverPos;
      if (current == null) {
        return;
      }
      final step = DriverNavigationMotion.advanceAlongRoute(
        route: pts,
        current: current,
        nextRouteIndex: _simRouteIndex,
        maxDistanceMeters:
            _simulationSpeedMetersPerSecond *
            _simulationTick.inMilliseconds /
            Duration.millisecondsPerSecond,
      );
      _simRouteIndex = step.nextRouteIndex;
      if (step.reachedEnd) {
        debugPrint('[SIM] Reached end of simulation route');
        timer.cancel();
        _persistNavSession();
      }
      unawaited(
        _onDriverMoved(step.position, source: DriverPositionSource.simulation),
      );
    });
  }

  Future<void> _onDriverMoved(
    LatLng newPos, {
    required DriverPositionSource source,
    bool forceSync = false,
  }) async {
    if (!mounted) return;
    if (source == DriverPositionSource.simulation &&
        !DriverDeliveryWorkflow.canSimulateMovement(
          status: _currentOrder.status,
          pickupConfirmed: _pickupConfirmed,
          arrivedAtTarget: _arrivedAtTarget,
        )) {
      return;
    }

    // Raw GPS theo mode của phiên; simulation/session/profile giữ map coords.
    var published = source.resolveForPublishing(
      locationMode: ref.read(driverLocationModeProvider),
      email: _authenticatedUser?.email,
      position: newPos,
    );

    // Snap lên polyline (nếu có) → marker không lệch vạch xanh / điểm L.
    if (_routePoints != null && _routePoints!.length >= 2) {
      published = DeliveryMapUtils.snapToRoute(
        fullRoute: _routePoints!,
        current: published,
      );
    }
    if (source != DriverPositionSource.simulation && _driverPos != null) {
      published = DriverNavigationPositionSmoother.smooth(
        previous: _driverPos!,
        next: published,
      );
    }

    var justArrived = false;
    if (!_arrivedAtTarget) {
      final target = DeliveryMapUtils.nextTarget(
        status: _currentOrder.status,
        pickupLat: _currentOrder.pickupLat,
        pickupLng: _currentOrder.pickupLng,
        deliveryLat: _currentOrder.deliveryLat,
        deliveryLng: _currentOrder.deliveryLng,
      );
      final arrival = DriverArrivalPolicy.resolveArrival(
        status: _currentOrder.status,
        current: published,
        target: target,
        source: source,
      );
      if (arrival != null) {
        published = arrival;
        _arrivedAtTarget = true;
        justArrived = true;
      }
    }

    final isFirstPos = _driverPos == null;
    final needRoute = isFirstPos || _routePoints == null;
    setState(() {
      _driverPos = published;
      if (justArrived) {
        _totalDistance = 0;
        _totalDuration = 0;
      }
    });
    _advanceNavigationStep(published);
    _persistNavSession();
    _followCamera(published, force: isFirstPos || justArrived);

    final driverId = _currentOrder.driverId;
    final orderId = _currentOrder.id;

    // 1) Broadcast + 2) PG — cùng tọa độ đã snap (khách = tài xế)
    final broadcastFuture = ref
        .read(realtimeServiceProvider)
        .broadcastDriverLocation(
          orderId: orderId,
          lat: published.latitude,
          lng: published.longitude,
        );
    if (forceSync) {
      await broadcastFuture;
    } else {
      unawaited(broadcastFuture);
    }

    if (driverId != null && driverId.isNotEmpty) {
      final ingest = ref.read(locationIngestServiceProvider);
      final ingestFuture = ingest.ingest(
        driverUserId: driverId,
        lat: published.latitude,
        lng: published.longitude,
        prioritySync: true,
        force: forceSync || justArrived,
        coordinateSpace: LocationIngestCoordinateSpace.mapCoordinates,
      );
      if (forceSync) {
        await ingestFuture;
      } else {
        unawaited(ingestFuture);
      }
    }

    if (needRoute) {
      await _loadRoute();
      return;
    }

    // Cập nhật km còn lại theo polyline đã cắt
    if (_routePoints != null && _routePoints!.length >= 2) {
      final remaining = DeliveryMapUtils.remainingRoute(
        fullRoute: _routePoints!,
        current: published,
      );
      final meters = DeliveryMapUtils.remainingMeters(remaining);
      if (mounted && meters > 0) {
        setState(() {
          _totalDistance = meters;
          // Đồng bộ ETA với tốc độ mô phỏng 54 km/h.
          _totalDuration = meters / _simulationSpeedMetersPerSecond;
        });
      }
    }
  }

  void _advanceNavigationStep(LatLng current) {
    final nextIndex = DriverNavigationRouteLogic.advanceNavigationStepIndex(
      steps: _navigationSteps,
      currentIndex: _activeNavigationStepIndex,
      driverPosition: current,
    );
    if (nextIndex == _activeNavigationStepIndex || !mounted) return;
    setState(() => _activeNavigationStepIndex = nextIndex);
  }

  void _followCamera(LatLng position, {bool force = false}) {
    final previous = _lastCameraFollowPosition;
    final moved = previous == null
        ? double.infinity
        : const Distance().as(LengthUnit.Meter, previous, position);
    final elapsed = DateTime.now().difference(_lastCameraFollowAt);
    if (!force && (elapsed < const Duration(milliseconds: 350) || moved < 4)) {
      return;
    }
    _lastCameraFollowAt = DateTime.now();
    _lastCameraFollowPosition = position;
    DriverNavigationRouteLogic.followDriverCamera(
      controller: _mapController,
      order: _currentOrder,
      driverPosition: position,
      routePoints: _routePoints,
    );
  }

  Future<void> _loadRoute() async {
    final pos = ref.read(currentPositionProvider).valueOrNull;
    final order = _currentOrder;

    final hasPos = pos != null && pos.latitude != 0.0 && pos.longitude != 0.0;
    final hasDriverPos =
        _driverPos != null &&
        _driverPos!.latitude != 0.0 &&
        _driverPos!.longitude != 0.0;

    // Luôn ưu tiên _driverPos (sim/GPS nav) — tránh browser GPS / stale
    // làm route + sim nhảy về điểm đầu.
    final LatLng driverLatLng;
    if (hasDriverPos) {
      driverLatLng = _driverPos!;
    } else if (hasPos) {
      driverLatLng = LatLng(pos.latitude, pos.longitude);
    } else {
      driverLatLng = LatLng(order.pickupLat, order.pickupLng);
    }

    // Hash theo status + vị trí thô — không reload OSRM mỗi vài mét.
    final statusKey =
        '${order.status}_${driverLatLng.latitude.toStringAsFixed(3)}_${driverLatLng.longitude.toStringAsFixed(3)}';
    if (statusKey == _lastRouteStatus &&
        _routePoints != null &&
        _routePoints!.length >= 2) {
      return;
    }
    _lastRouteStatus = statusKey;

    final myKey = ++_routeKey;
    // Không xóa polyline cũ trước khi có route mới (tránh màn hình trống).

    final waypoints = DriverNavigationRouteLogic.buildWaypoints(
      order: order,
      driverPosition: driverLatLng,
    );

    debugPrint(
      '[OSRM_DEBUG_DRIVER] loading route status=${order.status} '
      'from=${driverLatLng.latitude},${driverLatLng.longitude}',
    );

    final result = await OsrmService().getRouteWithWaypoints(
      waypoints: waypoints,
    );

    if (!mounted || myKey != _routeKey) return;

    if (result == null || result.points.length < 2) {
      debugPrint('[OSRM_DEBUG_DRIVER] OSRM null/short — keep previous route');
      // Fallback đường thẳng để vẫn thấy "đường xanh"
      if (_routePoints == null || _routePoints!.length < 2) {
        final wp = DriverNavigationRouteLogic.buildWaypoints(
          order: order,
          driverPosition: driverLatLng,
        );
        if (wp.length >= 2) {
          setState(() {
            _routePoints = wp;
            _navigationSteps = const [];
            _activeNavigationStepIndex = 0;
            _totalDistance = const Distance().as(
              LengthUnit.Meter,
              wp.first,
              wp.last,
            );
            _totalDuration = null;
          });
          _fitMapBounds();
        }
      }
    } else {
      debugPrint(
        '[OSRM_DEBUG_DRIVER] result: ${result.points.length} pts, '
        '${result.distanceMeters}m',
      );
      setState(() {
        _routePoints = result.points;
        _navigationSteps = result.steps;
        _activeNavigationStepIndex = 0;
        _totalDistance = result.distanceMeters;
        _totalDuration = result.durationSeconds;
      });
      _fitMapBounds();

      // Web sim chỉ chạy trong một chặng đang hoạt động.
      if (kIsWeb &&
          _driverPos != null &&
          DriverDeliveryWorkflow.canSimulateMovement(
            status: order.status,
            pickupConfirmed: _pickupConfirmed,
            arrivedAtTarget: _arrivedAtTarget,
          )) {
        if (_simTimer == null || !_simTimer!.isActive) {
          _startSimulation(resume: true);
        }
      }
    }
  }

  void _fitMapBounds() {
    DriverNavigationRouteLogic.fitMapBounds(
      controller: _mapController,
      order: _currentOrder,
      driverPosition: _driverPos,
      routePoints: _routePoints,
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = _currentOrder;
    final navigationStep = DriverNavigationRouteLogic.nextNavigationStep(
      steps: _navigationSteps,
      activeIndex: _activeNavigationStepIndex,
    );
    final maneuverDistance = navigationStep == null || _driverPos == null
        ? null
        : const Distance().as(
            LengthUnit.Meter,
            _driverPos!,
            navigationStep.location,
          );
    final center =
        _driverPos ??
        LatLng(
          (order.pickupLat + order.deliveryLat) / 2,
          (order.pickupLng + order.deliveryLng) / 2,
        );

    return DriverNavigationView(
      order: order,
      totalDistance: _totalDistance,
      totalDuration: _totalDuration,
      driverLatitude: _driverPos?.latitude,
      driverLongitude: _driverPos?.longitude,
      arrivedAtTarget: _arrivedAtTarget,
      pickupConfirmed: _pickupConfirmed,
      isUpdatingStatus: _isUpdatingStatus,
      navigationStep: navigationStep,
      maneuverDistance: maneuverDistance,
      onBack: () => Navigator.of(context).maybePop(),
      onFitMap: _fitMapBounds,
      onPrimaryAction: _handlePrimaryAction,
      onContact: _openActiveOrderContact,
      currentUserId: _authenticatedUser?.id,
      onOpenMessageChat: _openOrderChat,
      riskInterventionRepository: _riskInterventionRepository,
      map: DriverNavigationMap(
        mapController: _mapController,
        order: order,
        center: center,
        routePoints: _routePoints,
        driverPosition: _driverPos,
      ),
    );
  }
}
