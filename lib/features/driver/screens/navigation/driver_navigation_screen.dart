import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/providers/customer_providers.dart';
import '../../../../core/providers/driver_nav_session_provider.dart';
import '../../../../core/providers/location_providers.dart';
import '../../../../core/services/osrm_service.dart';
import '../../../../core/utils/delivery_map_utils.dart';
import '../../../../core/widgets/delivery_map_markers.dart';
import '../../../reviews/widgets/driver_rate_customer_sheet.dart';
import '../home/utils/driver_home_formatters.dart';
import '../home/widgets/slide_status_action.dart';
import 'widgets/arrival_bottom_sheet.dart';

class DriverNavigationScreen extends ConsumerStatefulWidget {
  final OrderModel order;

  const DriverNavigationScreen({super.key, required this.order});

  @override
  ConsumerState<DriverNavigationScreen> createState() =>
      _DriverNavigationScreenState();
}

class _DriverNavigationScreenState
    extends ConsumerState<DriverNavigationScreen> {
  late OrderModel _currentOrder;
  final MapController _mapController = MapController();
  List<LatLng>? _routePoints;
  double? _totalDistance;
  double? _totalDuration;
  bool _isUpdatingStatus = false;

  // ─── Driver position & movement ───────────────────────────────────────────
  LatLng? _driverPos;
  /// Index trong _routePoints hiện tại để animate simulation trên web
  int _simRouteIndex = 0;

  // ─── Timers ───────────────────────────────────────────────────────────────
  Timer? _routeRefreshTimer;
  Timer? _simTimer; // Chỉ dùng khi web simulate
  StreamSubscription<Position>? _posStream; // GPS stream trên thiết bị thật

  // ─── Route dedup ──────────────────────────────────────────────────────────
  String? _lastRouteStatus;
  int _routeKey = 0;

  // ─── Arrival ──────────────────────────────────────────────────────────────
  /// Đã hiện banner "Đến nơi" hay chưa (tránh hiện lại)
  bool _arrivedAtTarget = false;

  /// Khoảng cách (m) tới target để coi là "đến nơi"
  static const double _arrivalThresholdMeters = 60.0;

  /// Tốc độ simulate trên web (điểm/giây). Thấp + ingest throttle.
  static const int _simPointsPerSecond = 1;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _restoreNavSession();
    _startMovement();
    _startRouteRefresh();
    // Đảm bảo đường xanh hiện ngay cả status assigned (trước khi gạt).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_ensureInitialRoute());
    });
  }

  /// Seed vị trí + load OSRM lần đầu (không đè session đã restore).
  Future<void> _ensureInitialRoute() async {
    // Đợi hydrate SharedPreferences (hot restart Shift+R).
    await ref.read(driverNavSessionsProvider.notifier).ready;
    if (!mounted) return;
    _restoreNavSession();

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
      // Chỉ fallback pickup nếu chưa có bất kỳ vị trí nào
      _driverPos ??= LatLng(order.pickupLat, order.pickupLng);
      if (mounted) setState(() {});
    }

    // Nếu đã tới pickup (session) — không start sim chạy lại từ đầu.
    final pickup = LatLng(_currentOrder.pickupLat, _currentOrder.pickupLng);
    if (_driverPos != null) {
      final d = const Distance().as(LengthUnit.Meter, _driverPos!, pickup);
      if (d <= _arrivalThresholdMeters &&
          (_currentOrder.status == 'assigned' ||
              _currentOrder.status == 'picking_up')) {
        _arrivedAtTarget = true;
        _driverPos = pickup;
        _simTimer?.cancel();
      }
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
      _arrivedAtTarget = false; // Reset trạng thái đến nơi để kiểm tra cho chặng tiếp theo
      _simRouteIndex = 0;
      _loadRoute();
    }
  }

  @override
  void dispose() {
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
    // Cùng đơn: cho phép restore cả khi status khớp.
    // Nếu đã delivering mà session còn picking_up → vẫn lấy vị trí (đã tới lấy).
    if (saved.lat == 0 && saved.lng == 0) return;

    _driverPos = LatLng(saved.lat, saved.lng);
    // Chỉ giữ cờ arrived nếu cùng chặng (tránh kẹt banner chặng cũ).
    if (saved.status == _currentOrder.status) {
      _arrivedAtTarget = saved.arrivedAtTarget;
      _simRouteIndex = saved.simRouteIndex;
    } else {
      _arrivedAtTarget = false;
      _simRouteIndex = 0;
    }
    debugPrint(
      '[NAV_SESSION] restore order=${_currentOrder.id} '
      'pos=(${saved.lat},${saved.lng}) simIndex=$_simRouteIndex '
      'arrived=$_arrivedAtTarget savedStatus=${saved.status} '
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
      simRouteIndex: _simRouteIndex,
      updatedAt: DateTime.now(),
    );
    unawaited(ref.read(driverNavSessionsProvider.notifier).upsert(next));
  }

  void _startRouteRefresh() {
    if (kIsWeb) return; // Không cần tự động refresh route định kỳ khi đang giả lập trên Web
    _routeRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted || _driverPos == null) return;
      // Cho phép refresh khoảng cách; _loadRoute tự skip nếu gần như đứng yên.
      _lastRouteStatus = null;
      unawaited(_loadRoute());
    });
  }

  // ─── Movement: GPS thật (Android/iOS) hoặc Simulate (Web) ────────────────

  /// Entry point: chọn GPS stream thật hoặc simulation dựa vào platform.
  void _startMovement() {
    if (kIsWeb) {
      // Web không có GPS stream liên tục → dùng fallback pickup + simulate
      _initWebFallback();
    } else {
      _startGpsStream();
    }
  }

  /// Android/iOS: seed vị trí gần nhất rồi mới subscribe GPS stream.
  Future<void> _startGpsStream() async {
    // Ưu tiên session đã restore trong initState.
    if (_driverPos == null) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null && last.latitude != 0.0 && last.longitude != 0.0) {
          await _onDriverMoved(LatLng(last.latitude, last.longitude));
        } else {
          final current = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
            ),
          );
          await _onDriverMoved(
            LatLng(current.latitude, current.longitude),
          );
        }
      } catch (e) {
        debugPrint('[GPS_STREAM] seed position failed: $e');
      }
    } else if (_routePoints == null) {
      await _loadRoute();
    }

    _posStream?.cancel();
    _posStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 5, // cập nhật mỗi 5m di chuyển thật
      ),
    ).listen(
      (pos) {
        if (!mounted) return;
        final newPos = LatLng(pos.latitude, pos.longitude);
        _onDriverMoved(newPos);
      },
      onError: (e) {
        debugPrint('[GPS_STREAM] Error: $e');
      },
    );
  }

  /// Web: lấy tọa độ thực tế của tài xế làm điểm khởi đầu, sau đó mô phỏng di chuyển.
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

    LatLng startPos = LatLng(order.pickupLat, order.pickupLng);

    // 1. Thử lấy GPS thực tế của trình duyệt web
    final gpsPos = ref.read(currentPositionProvider).valueOrNull;
    if (gpsPos != null && gpsPos.latitude != 0.0 && gpsPos.longitude != 0.0) {
      startPos = LatLng(gpsPos.latitude, gpsPos.longitude);
      debugPrint(
        '[GPS_WEB] Initialized driver at browser GPS location: '
        '(${startPos.latitude}, ${startPos.longitude})',
      );
    }
    // 2. Profile tài xế trên Supabase (vị trí đã upload trước đó)
    else if (driverId != null && driverId.isNotEmpty) {
      try {
        final driverModel =
            await ref.read(driverByUserIdProvider(driverId).future);
        if (driverModel != null &&
            driverModel.currentLat != null &&
            driverModel.currentLat != 0.0 &&
            driverModel.currentLng != null &&
            driverModel.currentLng != 0.0) {
          startPos = LatLng(driverModel.currentLat!, driverModel.currentLng!);
          debugPrint(
            '[GPS_WEB] Initialized driver at profile location: '
            '(${startPos.latitude}, ${startPos.longitude})',
          );
        } else {
          debugPrint(
            '[GPS_WEB] Driver profile has no coordinates. '
            'Falling back to order pickup location.',
          );
        }
      } catch (e) {
        debugPrint(
          '[GPS_WEB] Failed to fetch driver profile: $e. '
          'Falling back to order pickup location.',
        );
      }
    }

    await _onDriverMoved(startPos);
  }

  /// Simulate driver di chuyển theo từng điểm của _routePoints (chỉ dùng web).
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
      final nearest = _nearestRouteIndex(points, _driverPos!);
      // Giữ index session nếu vẫn hợp lệ và không lùi quá xa so với nearest.
      if (_simRouteIndex > 0 &&
          _simRouteIndex < points.length &&
          (_simRouteIndex - nearest).abs() <= 8) {
        // giữ _simRouteIndex
      } else {
        _simRouteIndex = nearest;
      }
    } else if (!resume) {
      _simRouteIndex = 0;
    } else {
      _simRouteIndex = _simRouteIndex.clamp(0, points.length - 1);
    }

    debugPrint(
      '[SIM] Starting simulation points=${points.length} '
      'fromIndex=$_simRouteIndex resume=$resume',
    );

    _simTimer = Timer.periodic(
      Duration(milliseconds: (1000 / _simPointsPerSecond).round()),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        // Chỉ sim khi đúng chặng lấy/giao; assigned không tự chạy.
        final st = _currentOrder.status;
        if (st != 'picking_up' && st != 'delivering') {
          timer.cancel();
          _persistNavSession();
          return;
        }
        // Đã tới đích chặng → dừng (chờ user gạt).
        if (_arrivedAtTarget) {
          timer.cancel();
          _persistNavSession();
          return;
        }
        final pts = _routePoints;
        if (pts == null) {
          return;
        }
        if (_simRouteIndex >= pts.length) {
          debugPrint('[SIM] Reached end of simulation route');
          timer.cancel();
          _persistNavSession();
          return;
        }
        final pos = pts[_simRouteIndex];
        _simRouteIndex++;
        _onDriverMoved(pos);
      },
    );
  }

  int _nearestRouteIndex(List<LatLng> points, LatLng pos) {
    var bestIdx = 0;
    var bestDist = double.infinity;
    final distance = const Distance();
    for (var i = 0; i < points.length; i++) {
      final d = distance.as(LengthUnit.Meter, pos, points[i]);
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  /// Xử lý mỗi khi driver di chuyển (GPS thật hoặc simulate).
  Future<void> _onDriverMoved(LatLng newPos) async {
    if (!mounted) return;

    // Snap lên polyline (nếu có) → marker không lệch vạch xanh / điểm L.
    var published = LatLng(newPos.latitude, newPos.longitude);
    if (_routePoints != null && _routePoints!.length >= 2) {
      published = DeliveryMapUtils.snapToRoute(
        fullRoute: _routePoints!,
        current: published,
      );
    }

    final isFirstPos = _driverPos == null;
    final needRoute = isFirstPos || _routePoints == null;
    setState(() => _driverPos = published);
    _persistNavSession();
    _followDriverCamera(published);

    final driverId = _currentOrder.driverId;
    final orderId = _currentOrder.id;

    // 1) Broadcast + 2) PG — cùng tọa độ đã snap (khách = tài xế)
    unawaited(
      ref.read(realtimeServiceProvider).broadcastDriverLocation(
            orderId: orderId,
            lat: published.latitude,
            lng: published.longitude,
          ),
    );

    if (driverId != null && driverId.isNotEmpty) {
      final ingest = ref.read(locationIngestServiceProvider);
      unawaited(
        ingest.ingest(
          driverUserId: driverId,
          lat: published.latitude,
          lng: published.longitude,
          prioritySync: true,
        ),
      );
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
          // Ước ~22 km/h trung bình nội thành cho ETA hiển thị
          _totalDuration = (meters / 6.1);
        });
      }
    }

    _checkArrival(published);
  }

  /// Camera bám TX + điểm đến chặng (dễ quan sát như app giao hàng).
  void _followDriverCamera(LatLng driver) {
    if (!mounted) return;
    final order = _currentOrder;
    final target = DeliveryMapUtils.nextTarget(
      status: order.status,
      pickupLat: order.pickupLat,
      pickupLng: order.pickupLng,
      deliveryLat: order.deliveryLat,
      deliveryLng: order.deliveryLng,
    );
    try {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: [driver, target],
          padding: const EdgeInsets.fromLTRB(48, 72, 48, 160),
          maxZoom: 16.5,
        ),
      );
    } catch (_) {
      try {
        _mapController.move(driver, 15.5);
      } catch (_) {}
    }
  }

  /// Tính khoảng cách tới target hiện tại và hiện banner nếu đã đến nơi.
  void _checkArrival(LatLng current) {
    if (_arrivedAtTarget) return;

    final order = _currentOrder;
    final LatLng target;
    if (order.status == 'delivering') {
      target = LatLng(order.deliveryLat, order.deliveryLng);
    } else {
      target = LatLng(order.pickupLat, order.pickupLng);
    }

    final distM = const Distance().as(LengthUnit.Meter, current, target);
    debugPrint('[ARRIVAL] Distance to target: ${distM.toStringAsFixed(0)}m');

    if (distM <= _arrivalThresholdMeters) {
      _arrivedAtTarget = true;
      // Dừng sim — không tự chạy tiếp sang điểm giao.
      _simTimer?.cancel();
      _simTimer = null;
      // Snap đúng điểm đích chặng hiện tại.
      if (_currentOrder.status != 'delivering') {
        setState(() {
          _driverPos = LatLng(
            _currentOrder.pickupLat,
            _currentOrder.pickupLng,
          );
        });
      } else {
        setState(() {
          _driverPos = LatLng(
            _currentOrder.deliveryLat,
            _currentOrder.deliveryLng,
          );
        });
      }
      _persistNavSession();
      _showArrivalBanner();
      // Giữ route hiện tại; không chuyển chặng cho đến khi user gạt status.
    }
  }

  void _showArrivalBanner() {
    if (!mounted) return;
    final order = _currentOrder;
    final isPickup = order.status != 'delivering';
    final address = isPickup ? order.pickupAddress : order.deliveryAddress;
    unawaited(
      showArrivalBottomSheet(
        context: context,
        isPickup: isPickup,
        address: address,
        nextActionHint: isPickup
            ? 'Tiếp theo: gạt «Đã lấy hàng — bắt đầu giao»'
            : 'Tiếp theo: gạt «Hoàn tất giao hàng»',
      ),
    );
  }

  List<LatLng> _buildWaypoints(LatLng driverLatLng) {
    final order = _currentOrder;
    final pickupLatLng = LatLng(order.pickupLat, order.pickupLng);
    final deliveryLatLng = LatLng(order.deliveryLat, order.deliveryLng);

    final distanceToPickup = const Distance().as(
      LengthUnit.Meter,
      driverLatLng,
      pickupLatLng,
    );
    final isDriverTooFar = distanceToPickup > 150000; // > 150km

    if (isDriverTooFar) {
      debugPrint(
        '[OSRM_DEBUG_DRIVER] Driver too far '
        '(${distanceToPickup.toStringAsFixed(0)}m). Routing [pickup→delivery].',
      );
      return [pickupLatLng, deliveryLatLng];
    }

    // Chỉ khi ĐÃ gạt "bắt đầu giao" mới route tới điểm giao.
    // (Trước đây: gần pickup tự route giao → sim tự chạy tới G — sai.)
    if (order.status == 'delivering') {
      return [driverLatLng, deliveryLatLng];
    }

    // assigned / picking_up: luôn chặng lấy hàng (kể cả đã đứng tại pickup).
    return [driverLatLng, pickupLatLng];
  }

  Future<void> _loadRoute() async {
    final pos = ref.read(currentPositionProvider).valueOrNull;
    final order = _currentOrder;

    final hasPos = pos != null && pos.latitude != 0.0 && pos.longitude != 0.0;
    final hasDriverPos = _driverPos != null &&
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

    final waypoints = _buildWaypoints(driverLatLng);

    debugPrint(
      '[OSRM_DEBUG_DRIVER] loading route status=${order.status} '
      'from=${driverLatLng.latitude},${driverLatLng.longitude}',
    );

    final result =
        await OsrmService().getRouteWithWaypoints(waypoints: waypoints);

    if (!mounted || myKey != _routeKey) return;

    if (result == null || result.points.length < 2) {
      debugPrint('[OSRM_DEBUG_DRIVER] OSRM null/short — keep previous route');
      // Fallback đường thẳng để vẫn thấy "đường xanh"
      if (_routePoints == null || _routePoints!.length < 2) {
        final wp = _buildWaypoints(driverLatLng);
        if (wp.length >= 2) {
          setState(() {
            _routePoints = wp;
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
        _totalDistance = result.distanceMeters;
        _totalDuration = result.durationSeconds;
      });
      _fitMapBounds();

      // Web sim: chỉ picking_up / delivering, và chưa tới đích chặng.
      if (kIsWeb &&
          !_arrivedAtTarget &&
          (order.status == 'picking_up' || order.status == 'delivering')) {
        if (_simTimer == null || !_simTimer!.isActive) {
          _startSimulation(resume: true);
        }
      }
    }
  }

  void _fitMapBounds() {
    if (_driverPos != null) {
      _followDriverCamera(_driverPos!);
      return;
    }
    final order = _currentOrder;
    final target = DeliveryMapUtils.nextTarget(
      status: order.status,
      pickupLat: order.pickupLat,
      pickupLng: order.pickupLng,
      deliveryLat: order.deliveryLat,
      deliveryLng: order.deliveryLng,
    );
    try {
      _mapController.move(target, 15);
    } catch (_) {}
  }

  Future<void> _updateStatus() async {
    setState(() => _isUpdatingStatus = true);
    try {
      final service = ref.read(customerOrderServiceProvider);
      final nextStatus = await service.updateDriverOrderStatus(
        orderId: _currentOrder.id,
        driverId: _currentOrder.driverId ?? '',
        currentStatus: _currentOrder.status,
      );

      // Invalidate providers để realtime cập nhật order state
      ref.invalidate(availableOrdersProvider(_currentOrder.customerId));
      ref.invalidate(driverOrdersProvider(_currentOrder.driverId ?? ''));

      if (!mounted) return;

      if (nextStatus == 'delivered') {
        final deliveredOrder = _currentOrder.copyWith(status: nextStatus);
        await _showDeliveredDialog();
        if (!mounted) return;
        // Mời đánh giá khách (có thể bỏ qua)
        await showDriverRateCustomerSheet(
          context: context,
          order: deliveredOrder,
          customerName: null,
        );
        if (mounted) Navigator.of(context).pop(true);
      } else {
        // picking_up hoặc delivering → chặng mới chỉ sau khi user gạt
        _simTimer?.cancel();
        _simTimer = null;
        setState(() {
          _currentOrder = _currentOrder.copyWith(status: nextStatus);
          _lastRouteStatus = null;
          _routePoints = null;
          _totalDistance = null;
          _totalDuration = null;
          _arrivedAtTarget = false;
          _simRouteIndex = 0;
        });
        _persistNavSession();
        await _loadRoute(); // load chặng mới + start sim nếu web
        _fitMapBounds();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi cập nhật trạng thái: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _showDeliveredDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 44,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Giao hàng thành công!',
                style: AppTextStyles.headingSmall
                    .copyWith(color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Đơn hàng đã được giao đến khách hàng.\nCảm ơn bạn đã hoàn thành đơn hàng.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.md,
                    ),
                  ),
                  child: Text(
                    'Hoàn tất',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final order = _currentOrder;
    final pickupPoint = LatLng(order.pickupLat, order.pickupLng);
    final deliveryPoint = LatLng(order.deliveryLat, order.deliveryLng);
    final center = _driverPos ??
        LatLng(
          (order.pickupLat + order.deliveryLat) / 2,
          (order.pickupLng + order.deliveryLng) / 2,
        );

    // Vạch xanh = phần CÒN LẠI (đã đi qua thì cắt — giống map khách / ShopeeFood)
    final remaining = (_routePoints != null &&
            _routePoints!.length >= 2 &&
            _driverPos != null)
        ? DeliveryMapUtils.remainingRoute(
            fullRoute: _routePoints!,
            current: _driverPos!,
          )
        : _routePoints;

    final statusLabel = driverOrderStatusActionLabel(order.status);

    String routeTitle;
    if (order.status == 'assigned' || order.status == 'picking_up') {
      routeTitle = 'Đến điểm lấy hàng';
    } else if (order.status == 'delivering') {
      routeTitle = 'Đến điểm giao hàng';
    } else {
      routeTitle = 'Lộ trình';
    }

    final legHint = order.status == 'delivering'
        ? 'Đích: điểm giao (G)'
        : 'Đích: điểm lấy (L)';

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Text(
          routeTitle,
          style:
              AppTextStyles.headingSmall.copyWith(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.bgCard,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location_rounded, size: 22),
            onPressed: _fitMapBounds,
            tooltip: 'Theo vị trí',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: const BoxDecoration(
              color: AppColors.bgCard,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.route_rounded,
                    color: AppColors.routeLine, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _totalDistance != null
                      ? 'Còn ${DeliveryMapUtils.formatDistance(_totalDistance!)}'
                      : 'Đang tải lộ trình…',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(width: AppSpacing.lg),
                const Icon(Icons.timer_rounded,
                    color: AppColors.warning, size: 20),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  _totalDuration != null
                      ? '≈ ${DeliveryMapUtils.formatDuration(_totalDuration!)}'
                      : '',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.textPrimary),
                ),
                const Spacer(),
                _StatusBadge(status: order.status),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
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
                // Vạch mờ: full chặng (ngữ cảnh)
                if (_routePoints != null && _routePoints!.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints!,
                        color: AppColors.routeLine.withValues(alpha: 0.22),
                        strokeWidth: 5,
                      ),
                    ],
                  ),
                // Vạch xanh đậm: còn lại
                if (remaining != null && remaining.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: remaining,
                        color: AppColors.routeLine,
                        strokeWidth: 5.5,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    DeliveryMapMarkers.pickup(pickupPoint),
                    DeliveryMapMarkers.dropoff(deliveryPoint),
                    if (_driverPos != null)
                      DeliveryMapMarkers.driver(
                        DeliveryMapMarkers.offsetIfNear(
                          DeliveryMapMarkers.offsetIfNear(
                            _driverPos!,
                            pickupPoint,
                          ),
                          deliveryPoint,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Chip đích chặng
          Container(
            width: double.infinity,
            color: AppColors.bgCard,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: Text(
              legHint,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                color: AppColors.bgCard,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _AddressChip(
                        icon: Icons.storefront_rounded,
                        label: 'Lấy: ${order.pickupAddress}',
                        color: AppColors.markerPickup,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      _AddressChip(
                        icon: Icons.location_on_rounded,
                        label: 'Giao: ${order.deliveryAddress}',
                        color: AppColors.markerDrop,
                      ),
                    ],
                  ),
                  if (statusLabel != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    SlideStatusAction(
                      label: statusLabel,
                      isLoading: _isUpdatingStatus,
                      onConfirmed: _isUpdatingStatus ? null : _updateStatus,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'assigned' => 'Đã nhận',
      'picking_up' => 'Đang lấy hàng',
      'delivering' => 'Đang giao',
      _ => status,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.1),
        borderRadius: AppRadius.full,
      ),
      child: Text(label,
          style:
              AppTextStyles.labelSmall.copyWith(color: AppColors.info)),
    );
  }
}

class _AddressChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _AddressChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
