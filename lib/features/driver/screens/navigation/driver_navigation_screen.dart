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
import '../../../../core/providers/location_providers.dart';
import '../../../../core/services/driver_location_service.dart';
import '../../../../core/services/osrm_service.dart';
import '../home/utils/driver_home_formatters.dart';
import '../home/widgets/slide_status_action.dart';

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

  /// Tốc độ simulate trên web (số điểm/giây)
  static const int _simPointsPerSecond = 3;

  late final DriverLocationService _locationUploader;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _locationUploader = DriverLocationService();
    _loadRoute();
    _startMovement();
    _startRouteRefresh();
  }

  @override
  void didUpdateWidget(covariant DriverNavigationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.status != widget.order.status) {
      _currentOrder = widget.order;
      _lastRouteStatus = null;
      _arrivedAtTarget = false; // Reset trạng thái đến nơi để kiểm tra cho chặng tiếp theo
      _loadRoute();
    }
  }

  @override
  void dispose() {
    _routeRefreshTimer?.cancel();
    _simTimer?.cancel();
    _posStream?.cancel();
    super.dispose();
  }

  void _startRouteRefresh() {
    if (kIsWeb) return; // Không cần tự động refresh route định kỳ khi đang giả lập trên Web
    _routeRefreshTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _loadRoute());
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

  /// Android/iOS: dùng GPS stream thật từ Geolocator.
  void _startGpsStream() {
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
    LatLng startPos = LatLng(order.pickupLat, order.pickupLng);

    // 1. Thử lấy GPS thực tế của trình duyệt web (nếu người dùng cấp quyền và không bị timeout)
    final gpsPos = ref.read(currentPositionProvider).valueOrNull;
    if (gpsPos != null && gpsPos.latitude != 0.0 && gpsPos.longitude != 0.0) {
      startPos = LatLng(gpsPos.latitude, gpsPos.longitude);
      debugPrint('[GPS_WEB] Initialized driver at browser GPS location: (${startPos.latitude}, ${startPos.longitude})');
    }
    // 2. Nếu không lấy được GPS trình duyệt, lấy vị trí đã lưu trong profile tài xế trên Supabase
    else if (driverId != null && driverId.isNotEmpty) {
      try {
        final driverModel = await ref.read(driverByUserIdProvider(driverId).future);
        if (driverModel != null &&
            driverModel.currentLat != null &&
            driverModel.currentLat != 0.0 &&
            driverModel.currentLng != null &&
            driverModel.currentLng != 0.0) {
          startPos = LatLng(driverModel.currentLat!, driverModel.currentLng!);
          debugPrint('[GPS_WEB] Initialized driver at actual profile location: (${startPos.latitude}, ${startPos.longitude})');
        } else {
          debugPrint('[GPS_WEB] Driver profile has no coordinates. Falling back to order pickup location.');
        }
      } catch (e) {
        debugPrint('[GPS_WEB] Failed to fetch driver profile: $e. Falling back to order pickup location.');
      }
    }

    // Thiết lập vị trí khởi đầu của driver.
    await _onDriverMoved(startPos);
  }

  /// Simulate driver di chuyển theo từng điểm của _routePoints (chỉ dùng web).
  void _startSimulation() {
    _simTimer?.cancel();
    final points = _routePoints;
    if (points == null || points.length < 2) {
      debugPrint('[SIM] Cannot start simulation: _routePoints is null or too short');
      return;
    }

    _simRouteIndex = 0;
    debugPrint('[SIM] Starting simulation with ${points.length} route points');

    _simTimer = Timer.periodic(
      Duration(milliseconds: (1000 / _simPointsPerSecond).round()),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        final pts = _routePoints;
        if (pts == null) {
          // Bỏ qua tick này nếu đang trong lúc load/recalculate route mới, không cancel timer
          return;
        }
        if (_simRouteIndex >= pts.length) {
          debugPrint('[SIM] Reached end of simulation route');
          timer.cancel();
          return;
        }
        final pos = pts[_simRouteIndex];
        _simRouteIndex++;
        _onDriverMoved(pos);
      },
    );
  }

  /// Xử lý mỗi khi driver di chuyển (GPS thật hoặc simulate).
  /// 1. Cập nhật marker trên map
  /// 2. Upload vị trí lên Supabase
  /// 3. Kiểm tra đã tới điểm đích chưa
  Future<void> _onDriverMoved(LatLng newPos) async {
    if (!mounted) return;

    final isFirstPos = _driverPos == null;
    setState(() => _driverPos = newPos);

    // Upload vị trí lên Supabase (fire-and-forget)
    final driverId = _currentOrder.driverId;
    if (driverId != null && driverId.isNotEmpty) {
      unawaited(_locationUploader.updateLocation(
        driverId: driverId,
        lat: newPos.latitude,
        lng: newPos.longitude,
      ));
    }

    // Lần đầu có vị trí → load route ngay
    if (isFirstPos) {
      await _loadRoute();
      return;
    }

    // Kiểm tra tới điểm đích
    _checkArrival(newPos);
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
      _showArrivalBanner();
    }
  }

  void _showArrivalBanner() {
    if (!mounted) return;
    final order = _currentOrder;
    final isPickup = order.status == 'picking_up' || order.status == 'assigned';
    final message = isPickup
        ? '🏪 Bạn đã đến điểm lấy hàng!'
        : '📦 Bạn đã đến điểm giao hàng!';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.labelMedium.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        margin: const EdgeInsets.all(AppSpacing.lg),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
      ),
    );
  }

  List<LatLng> _buildWaypoints(LatLng driverLatLng) {
    final order = _currentOrder;
    final pickupLatLng = LatLng(order.pickupLat, order.pickupLng);
    final deliveryLatLng = LatLng(order.deliveryLat, order.deliveryLng);

    final distanceToPickup = const Distance().as(LengthUnit.Meter, driverLatLng, pickupLatLng);
    final isDriverTooFar = distanceToPickup > 150000; // > 150km

    if (isDriverTooFar) {
      // Driver ở quá xa (ví dụ: giả lập ở Mỹ) — chỉ hiện pickup→delivery
      debugPrint('[OSRM_DEBUG_DRIVER] Driver too far ($distanceToPickup w). Routing [pickup→delivery].');
      return [pickupLatLng, deliveryLatLng];
    }

    // Chỉ dùng 2 waypoints: driver → điểm tiếp theo.
    // KHÔNG dùng 3 waypoints [driver, pickup, delivery] vì OSRM snap
    // điểm giữa (pickup) vào road segment khác nhau cho mỗi leg,
    // gây ra đoạn đường sai/đường thẳng ngang trên bản đồ.
    if (order.status == 'delivering') {
      return [driverLatLng, deliveryLatLng];
    }
    // assigned / picking_up: chỉ điều hướng đến pickup
    return [driverLatLng, pickupLatLng];
  }

  Future<void> _loadRoute() async {
    final pos = ref.read(currentPositionProvider).valueOrNull;
    final order = _currentOrder;

    final hasPos = pos != null && pos.latitude != 0.0 && pos.longitude != 0.0;
    final hasDriverPos = _driverPos != null &&
        _driverPos!.latitude != 0.0 &&
        _driverPos!.longitude != 0.0;

    final LatLng driverLatLng;
    if (kIsWeb) {
      driverLatLng = hasDriverPos
          ? _driverPos!
          : (hasPos
              ? LatLng(pos.latitude, pos.longitude)
              : LatLng(order.pickupLat, order.pickupLng));
    } else {
      driverLatLng = hasPos
          ? LatLng(pos.latitude, pos.longitude)
          : (hasDriverPos
              ? _driverPos!
              : LatLng(order.pickupLat, order.pickupLng));
    }

    final statusKey = '${order.status}_${driverLatLng.latitude.toStringAsFixed(4)}_${driverLatLng.longitude.toStringAsFixed(4)}';
    if (statusKey == _lastRouteStatus) return;
    _lastRouteStatus = statusKey;

    // Tăng key để hủy request cũ, xoá route cũ ngay lập tức nếu không phải Web
    final myKey = ++_routeKey;
    if (mounted && !kIsWeb) {
      setState(() {
        _routePoints = null;
        _totalDistance = null;
        _totalDuration = null;
      });
    }

    final waypoints = _buildWaypoints(driverLatLng);

    debugPrint('[OSRM_DEBUG_DRIVER] loading route for order status: ${order.status}');
    debugPrint('[OSRM_DEBUG_DRIVER] waypoints: ${waypoints.map((w) => '${w.latitude},${w.longitude}').toList()}');

    final result =
        await OsrmService().getRouteWithWaypoints(waypoints: waypoints);

    // Chỉ cập nhật nếu request này vẫn là request mới nhất
    if (!mounted || myKey != _routeKey) return;

    if (result == null) {
      debugPrint('[OSRM_DEBUG_DRIVER] OSRM service returned null');
    } else {
      debugPrint('[OSRM_DEBUG_DRIVER] result: ${result.points.length} points, ${result.distanceMeters}m');
      setState(() {
        _routePoints = result.points;
        _totalDistance = result.distanceMeters;
        _totalDuration = result.durationSeconds;
      });
      _fitMapBounds();

      // Chỉ tự động mô phỏng di chuyển khi tài xế đã xác nhận đi lấy hàng hoặc giao hàng
      if (kIsWeb && (order.status == 'picking_up' || order.status == 'delivering')) {
        _startSimulation();
      }
    }
  }

  void _fitMapBounds() {
    final order = _currentOrder;
    // Chỉ dùng pickup, delivery và driver để tính bounds.
    // Không dùng _routePoints vì hàng trăm điểm polyline sẽ làm camera
    // zoom ra quá rộng và gây ra lỗi hiển thị đường thẳng đứng.
    final allPoints = <LatLng>[
      LatLng(order.pickupLat, order.pickupLng),
      LatLng(order.deliveryLat, order.deliveryLng),
    ];
    if (_driverPos != null) {
      final distanceToPickup = const Distance().as(
        LengthUnit.Meter,
        _driverPos!,
        LatLng(order.pickupLat, order.pickupLng),
      );
      if (distanceToPickup <= 150000) {
        allPoints.add(_driverPos!);
      }
    }

    final validPoints = allPoints.where(_isValidLatLng).toList();
    if (validPoints.isEmpty) return;

    final padding = MediaQuery.of(context).size.width * 0.12;
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: validPoints,
        padding: EdgeInsets.all(padding),
      ),
    );
  }

  bool _isValidLatLng(LatLng p) {
    return p.latitude.isFinite &&
        p.longitude.isFinite &&
        p.latitude >= -90 &&
        p.latitude <= 90 &&
        p.longitude >= -180 &&
        p.longitude <= 180;
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
        // Đơn hoàn tất → hiện dialog thành công rồi pop
        await _showDeliveredDialog();
        if (mounted) Navigator.of(context).pop(true);
      } else {
        // picking_up hoặc delivering → ở lại map, reset route để load lại
        setState(() {
          _currentOrder = _currentOrder.copyWith(status: nextStatus);
          _lastRouteStatus = null; // Buộc reload route với status mới
          _routePoints = null;
          _totalDistance = null;
          _totalDuration = null;
          _arrivedAtTarget = false; // Reset trạng thái đến nơi để kiểm tra chặng tiếp theo
        });
        _loadRoute();
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


  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toInt()}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  String _formatDuration(double seconds) {
    if (seconds < 60) return '${seconds.toInt()}s';
    return '${(seconds / 60).toInt()} phút';
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

    final statusLabel = driverOrderStatusActionLabel(order.status);

    String routeTitle;
    if (order.status == 'assigned' || order.status == 'picking_up') {
      routeTitle = 'Đến điểm lấy hàng';
    } else if (order.status == 'delivering') {
      routeTitle = 'Đến điểm giao hàng';
    } else {
      routeTitle = 'Lộ trình';
    }

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
            tooltip: 'Vị trí hiện tại',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_routePoints != null)
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
                        ? _formatDistance(_totalDistance!)
                        : '',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  const Icon(Icons.timer_rounded,
                      color: AppColors.warning, size: 20),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    _totalDuration != null
                        ? _formatDuration(_totalDuration!)
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
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.datn.giaohang',
                  subdomains: const ['a', 'b', 'c'],
                  maxNativeZoom: 19,
                ),
                if (_routePoints != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints!,
                        color: AppColors.routeLine,
                        strokeWidth: 5,
                      ),
                    ],
                  ),
                MarkerLayer(
                    markers: _buildMarkers(pickupPoint, deliveryPoint)),
              ],
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

  List<Marker> _buildMarkers(LatLng pickup, LatLng delivery) {
    final markers = <Marker>[
      Marker(
        point: pickup,
        width: 36,
        height: 36,
        child: _NavMarker(
            color: AppColors.markerPickup,
            icon: Icons.storefront_rounded,
            size: 36),
      ),
      Marker(
        point: delivery,
        width: 36,
        height: 36,
        child: _NavMarker(
            color: AppColors.markerDrop,
            icon: Icons.location_on_rounded,
            size: 36),
      ),
    ];

    if (_driverPos != null &&
        _driverPos!.latitude != 0.0 &&
        _driverPos!.longitude != 0.0) {
      final distanceToPickup = const Distance().as(
        LengthUnit.Meter,
        _driverPos!,
        pickup,
      );
      if (distanceToPickup <= 150000) {
        markers.add(
          Marker(
            point: _driverPos!,
            width: 40,
            height: 40,
            child: _NavMarker(
                color: AppColors.markerDriver,
                icon: Icons.directions_car_rounded,
                size: 40),
          ),
        );
      }
    }

    return markers;
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

class _NavMarker extends StatelessWidget {
  final Color color;
  final IconData icon;
  final double size;

  const _NavMarker(
      {required this.color, required this.icon, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: AppShadow.elevated,
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.55),
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
