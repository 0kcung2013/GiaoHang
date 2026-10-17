import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/customer_providers.dart';
import '../../../../core/providers/location_providers.dart';
import '../../../../core/providers/driver_nav_session_provider.dart';
import '../../../../core/location/driver_foreground_location_service.dart';
import '../../../../core/location/driver_location_producer_policy.dart';
import '../../../../core/location/driver_active_delivery_tracking_policy.dart';

/// Giữ mẫu mới khi đã nhận đơn nhưng chưa mở điều hướng hoặc đang chờ lấy hàng.
class DriverOrderLocationHeartbeat extends ConsumerStatefulWidget {
  const DriverOrderLocationHeartbeat({
    required this.orderId,
    required this.driverProfileId,
    required this.driverUserId,
    this.isTrafficDemo = false,
    super.key,
  });
  final String orderId;
  final String driverProfileId;
  final String driverUserId;
  final bool isTrafficDemo;
  @override
  ConsumerState<DriverOrderLocationHeartbeat> createState() =>
      _DriverOrderLocationHeartbeatState();
}

class _DriverOrderLocationHeartbeatState
    extends ConsumerState<DriverOrderLocationHeartbeat> {
  Timer? _timer;
  bool _pending = false;
  String? _foregroundOrderId;
  bool _usingRouteSimulation = false;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(_sample()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_sample()));
  }

  @override
  void didUpdateWidget(covariant DriverOrderLocationHeartbeat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_sample()));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _sample() async {
    if (!mounted ||
        _pending ||
        ref.read(activeDriverNavigationOrderProvider) == widget.orderId) {
      return;
    }
    final orderId = widget.orderId;
    final mode = ref.read(driverLocationModeProvider);
    _pending = true;
    try {
      final ingest = ref.read(locationIngestServiceProvider);
      if (DriverActiveDeliveryTrackingPolicy.usesRouteSimulation(
        isWeb: kIsWeb,
        locationMode: mode,
        isTrafficDemo: widget.isTrafficDemo,
      )) {
        if (!_usingRouteSimulation) {
          await DriverForegroundLocationService.stop();
          _foregroundOrderId = null;
          _usingRouteSimulation = true;
        }
        final session = ref.read(driverNavSessionsProvider)[orderId];
        final driver = ref
            .read(driverByUserIdProvider(widget.driverUserId))
            .valueOrNull;
        final lat = session?.lat ?? driver?.currentLat;
        final lng = session?.lng ?? driver?.currentLng;
        if (lat == null || lng == null) return;
        await ingest.ingest(
          driverProfileId: widget.driverProfileId,
          driverUserId: widget.driverUserId,
          orderId: orderId,
          lat: lat,
          lng: lng,
          accuracy: 0,
          capturedAt: DateTime.now(),
          prioritySync: true,
          coordinateSpace: LocationIngestCoordinateSpace.mapCoordinates,
        );
      } else {
        _usingRouteSimulation = false;
        if (_foregroundOrderId != orderId) {
          final started = await DriverForegroundLocationService.start(
            driverProfileId: widget.driverProfileId,
            driverUserId: widget.driverUserId,
            orderId: orderId,
          );
          if (started) _foregroundOrderId = orderId;
        }
        if (!mounted) return;
        final position = await ref
            .read(locationServiceProvider)
            .getCurrentPosition();
        if (position == null || !mounted || widget.orderId != orderId) return;
        await ingest.ingest(
          driverProfileId: widget.driverProfileId,
          driverUserId: widget.driverUserId,
          orderId: orderId,
          lat: position.latitude,
          lng: position.longitude,
          accuracy: position.accuracy,
          capturedAt: position.timestamp,
          prioritySync: true,
          coordinateSpace: mode.rawGpsCoordinateSpace,
        );
      }
    } catch (error) {
      debugPrint('[DriverMonitoring] heartbeat pending: $error');
    } finally {
      _pending = false;
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
