import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/providers/customer_providers.dart';
import '../../../../core/providers/location_providers.dart';
import '../../../../core/providers/driver_position_publisher_provider.dart';
import '../../../../core/location/driver_arrival_fix.dart';
import '../../../../core/location/driver_foreground_location_service.dart';
import '../../../../core/location/driver_active_delivery_tracking_policy.dart';

/// Giữ mẫu mô phỏng khi đóng map; GPS thực thuộc Driver Shell.
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
        ref.read(activeDriverNavigationOrderProvider) != null) {
      return;
    }
    final orderId = widget.orderId;
    final mode = ref.read(driverLocationModeProvider);
    _pending = true;
    try {
      if (DriverActiveDeliveryTrackingPolicy.usesRouteSimulation(
        isWeb: kIsWeb,
        locationMode: mode,
        isTrafficDemo: widget.isTrafficDemo,
      )) {
        if (!_usingRouteSimulation) {
          await DriverForegroundLocationService.stop();
          _usingRouteSimulation = true;
        }
        final driver = ref
            .read(driverByUserIdProvider(widget.driverUserId))
            .valueOrNull;
        final shared = ref.read(driverPhysicalPositionProvider);
        final lat = shared?.latitude ?? driver?.currentLat;
        final lng = shared?.longitude ?? driver?.currentLng;
        if (lat == null || lng == null) return;
        final fix = ref
            .read(driverArrivalFixProvider)
            ?.sampleStationarySimulation(
              current: LatLng(lat, lng),
              currentMode: mode,
              now: DateTime.now(),
            );
        if (fix != null) {
          ref.read(driverArrivalFixProvider.notifier).state = fix;
        }
        await ref
            .read(driverPositionPublisherProvider)
            .publish(
              driverProfileId: widget.driverProfileId,
              driverUserId: widget.driverUserId,
              orderId: orderId,
              fix:
                  fix ??
                  DriverArrivalFix(
                    position: LatLng(lat, lng),
                    capturedAt: DateTime.now(),
                    accuracy: 0,
                    mode: mode,
                    simulated: true,
                  ),
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
