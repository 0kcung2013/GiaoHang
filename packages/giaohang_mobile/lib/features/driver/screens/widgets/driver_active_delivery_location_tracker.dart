import 'dart:async';
import '../../../../core/location/driver_arrival_fix.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/location/driver_active_delivery_tracking_policy.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/models/delivery_eta_route_profile.dart';
import '../../../../core/providers/customer_providers.dart';
import '../../../../core/providers/driver_nav_session_provider.dart';
import '../../../../core/providers/location_providers.dart';
import '../../../../core/providers/driver_active_gps_provider.dart';
import '../../../../core/providers/driver_position_publisher_provider.dart';
import '../../../../core/providers/driver_task_priority_provider.dart';
import '../navigation/models/driver_delivery_workflow.dart';
import '../navigation/utils/driver_demo_movement_tracker.dart';
import '../navigation/utils/driver_navigation_route_logic.dart';
import '../../../../core/services/osrm_service.dart';
import '../../monitoring/widgets/driver_monitoring_guard.dart';
import '../../monitoring/widgets/driver_order_location_heartbeat.dart';
import '../../monitoring/driver_monitoring_release_actions.dart';

/// GPS bền vững ở cấp Driver Shell, không phụ thuộc route Map đang mở hay đóng.
class DriverActiveDeliveryLocationTracker extends ConsumerStatefulWidget {
  const DriverActiveDeliveryLocationTracker({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<DriverActiveDeliveryLocationTracker> createState() =>
      _DriverActiveDeliveryLocationTrackerState();
}

class _DriverActiveDeliveryLocationTrackerState
    extends ConsumerState<DriverActiveDeliveryLocationTracker> {
  final _demoMovementTracker = DriverDemoMovementTracker();
  String? _requestedDemoKey;
  String? _monitoredOrderId;
  DateTime? _pickupArrivedAt;

  @override
  void dispose() {
    _demoMovementTracker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(driverLocationOwnerProvider(widget.userId));
    if (active != null) {
      _monitoredOrderId = active.id;
      _pickupArrivedAt = active.pickupArrivedAt;
    }
    final driver = ref.watch(driverByUserIdProvider(widget.userId)).valueOrNull;
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (active != null &&
            driver != null &&
            DriverActiveDeliveryTrackingPolicy.usesRouteSimulation(
              isWeb: kIsWeb,
              locationMode: ref.watch(driverLocationModeProvider),
              isTrafficDemo: active.trafficDemoKey != null,
            ))
          DriverOrderLocationHeartbeat(
            orderId: active.id,
            driverProfileId: driver.id,
            driverUserId: widget.userId,
            isTrafficDemo: active.trafficDemoKey != null,
          ),
        _buildMovement(context),
      ],
    );
    final monitored = _monitoredOrderId;
    return monitored == null
        ? child
        : DriverMonitoringGuard(
            orderId: monitored,
            pickupArrivedAt: _pickupArrivedAt,
            enabled:
                ref.watch(activeDriverNavigationOrderProvider) != monitored,
            onReleased: (ticketId) => handleDriverMonitoringRelease(
              context,
              ref,
              orderId: monitored,
              userId: widget.userId,
              ticketId: ticketId,
            ),
            onInactive: () {
              if (mounted && _monitoredOrderId == monitored) {
                setState(() {
                  _monitoredOrderId = null;
                  _pickupArrivedAt = null;
                });
                ref.invalidate(driverOrdersProvider(widget.userId));
              }
            },
            child: child,
          );
  }

  Widget _buildMovement(BuildContext context) {
    final userId = widget.userId;
    final driver = ref.watch(driverByUserIdProvider(userId)).valueOrNull;
    final activeOrder = ref.watch(driverLocationOwnerProvider(userId));
    if (driver == null || activeOrder == null) {
      _stopDemoPublisher();
      return const SizedBox.shrink();
    }

    final mode = ref.watch(driverLocationModeProvider);
    if (!DriverActiveDeliveryTrackingPolicy.usesRouteSimulation(
      isWeb: kIsWeb,
      locationMode: mode,
      isTrafficDemo: activeOrder.trafficDemoKey != null,
    )) {
      _stopDemoPublisher();
      ref.watch(driverActiveGpsProvider(userId));
      return const SizedBox.shrink();
    }

    final session = ref.watch(driverNavSessionsProvider)[activeOrder.id];
    final locationMode = ref.watch(driverLocationModeProvider);
    // A map for either task owns the single physical publisher.
    final isNavigationMapOpen =
        ref.watch(activeDriverNavigationOrderProvider) != null;
    final hasRestoredNavigationSession =
        session != null &&
        session.canRestoreFor(
          activeOrderId: activeOrder.id,
          activeStatus: activeOrder.status,
          activeLocationMode: locationMode,
        );
    final canSimulateMovement = DriverDeliveryWorkflow.canSimulateMovement(
      status: activeOrder.status,
      pickupConfirmed: session?.pickupConfirmed ?? false,
      arrivedAtTarget: session?.arrivedAtTarget ?? false,
      routeCompleted: session?.routeCompleted ?? false,
    );
    final shouldRunDemoPublisher =
        DriverActiveDeliveryTrackingPolicy.shouldRunDemoPublisher(
          isWeb: kIsWeb,
          locationMode: locationMode,
          isNavigationMapOpen: isNavigationMapOpen,
          hasRestoredNavigationSession: hasRestoredNavigationSession,
          canSimulateMovement: canSimulateMovement,
          isTrafficDemo: activeOrder.trafficDemoKey != null,
        );
    if (!activeOrder.isRecipientHeld &&
        shouldRunDemoPublisher &&
        session?.movementRunning == true) {
      _requestDemoPublisher(
        _DemoPublisherRequest(
          order: activeOrder,
          driverProfileId: driver.id,
          driverUserId: driver.userId,
          session: session!,
        ),
      );
      return const SizedBox.shrink();
    }
    _stopDemoPublisher();

    return const SizedBox.shrink();
  }

  void _requestDemoPublisher(_DemoPublisherRequest request) {
    if (_requestedDemoKey == request.key) return;
    _requestedDemoKey = request.key;
    _demoMovementTracker.stop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _requestedDemoKey == request.key) {
        unawaited(_startDemoPublisher(request));
      }
    });
  }

  void _stopDemoPublisher() {
    _requestedDemoKey = null;
    _demoMovementTracker.stop();
  }

  Future<void> _startDemoPublisher(_DemoPublisherRequest request) async {
    // Another task may have moved since this task's session was saved.
    final driver = ref.read(driverByUserIdProvider(widget.userId)).valueOrNull;
    final shared = ref.read(driverPhysicalPositionProvider);
    final latest = driver?.currentLat != null && driver?.currentLng != null
        ? LatLng(driver!.currentLat!, driver.currentLng!)
        : null;
    final initialPosition = shared ?? latest;
    if (initialPosition == null) return;
    final waypoints = DriverNavigationRouteLogic.buildWaypoints(
      order: request.order,
      driverPosition: initialPosition,
    );
    final candidate = request.order.trafficDemoKey == null
        ? null
        : DeliveryEtaRouteProfile.forOrder(request.order);
    final profile =
        candidate != null &&
            DriverNavigationRouteLogic.distanceFromRoute(
                  candidate.points,
                  initialPosition,
                ) <=
                30 &&
            const Distance()(candidate.points.last, waypoints.last) <= 100
        ? candidate
        : null;
    if (request.order.trafficDemoKey != null && candidate == null) return;
    final route = profile != null
        ? null
        : await OsrmService().getRouteWithWaypoints(waypoints: waypoints);
    if (!_ownsDemoPublisher(request)) return;

    final points = profile?.points ?? route?.points;
    if (points == null) return;
    if (points.length < 2) return;

    final nearest = DriverNavigationRouteLogic.nearestRouteIndex(
      points,
      initialPosition,
    );
    var nextRouteIndex = request.session.simRouteIndex;
    if (nextRouteIndex <= nearest ||
        nextRouteIndex >= points.length ||
        (nextRouteIndex - nearest).abs() > 8) {
      nextRouteIndex = (nearest + 1).clamp(1, points.length);
    }

    _demoMovementTracker.start(
      route: points,
      currentPosition: initialPosition,
      nextRouteIndex: nextRouteIndex,
      speedKmhAt: (point) => profile?.speedAt(point) ?? 25,
      metersForDuration: profile?.metersForDuration,
      geometryScale: profile?.geometryScale ?? 1,
      canMove: () =>
          _ownsDemoPublisher(request) &&
          ref
                  .read(driverNavSessionsProvider)[request.order.id]
                  ?.movementRunning ==
              true &&
          _requestedDemoKey == request.key &&
          DriverDeliveryWorkflow.canSimulateMovement(
            status: request.order.status,
            pickupConfirmed: request.session.pickupConfirmed,
            arrivedAtTarget: request.session.arrivedAtTarget,
            routeCompleted: request.session.routeCompleted,
          ),
      onPosition: (position, nextIndex, reachedEnd) {
        unawaited(
          _publishDemoPosition(
            request: request,
            position: position,
            nextRouteIndex: nextIndex,
            reachedEnd: reachedEnd,
            speedKmh: reachedEnd ? 0 : profile?.speedAt(position) ?? 25,
          ),
        );
      },
    );
  }

  Future<void> _publishDemoPosition({
    required _DemoPublisherRequest request,
    required LatLng position,
    required int nextRouteIndex,
    required bool reachedEnd,
    required double speedKmh,
  }) async {
    if (!_ownsDemoPublisher(request)) return;
    await ref
        .read(driverPositionPublisherProvider)
        .publish(
          driverUserId: request.driverUserId,
          driverProfileId: request.driverProfileId,
          orderId: request.order.id,
          speedKmh: speedKmh,
          fix: DriverArrivalFix(
            position: position,
            capturedAt: DateTime.now(),
            accuracy: 0,
            simulated: true,
            mode: ref.read(driverLocationModeProvider),
            trafficDemoKey: request.order.trafficDemoKey,
          ),
        );
    if (!_ownsDemoPublisher(request)) return;
    await ref
        .read(driverNavSessionsProvider.notifier)
        .upsert(
          request.session.copyWith(
            lat: position.latitude,
            lng: position.longitude,
            simRouteIndex: nextRouteIndex,
            arrivedAtTarget: reachedEnd || request.session.arrivedAtTarget,
            routeCompleted: reachedEnd || request.session.routeCompleted,
            movementRunning: !reachedEnd,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  bool _ownsDemoPublisher(_DemoPublisherRequest request) =>
      mounted &&
      _requestedDemoKey == request.key &&
      ref.read(activeDriverNavigationOrderProvider) == null &&
      ref.read(driverLocationOwnerProvider(widget.userId))?.id ==
          request.order.id;
}

class _DemoPublisherRequest {
  const _DemoPublisherRequest({
    required this.order,
    required this.driverProfileId,
    required this.driverUserId,
    required this.session,
  });

  final OrderModel order;
  final String driverProfileId;
  final String driverUserId;
  final DriverNavSession session;

  String get key =>
      '${order.id}:${order.status}:${session.pickupConfirmed}:${session.movementRunning}:${order.deliveryEtaData?['computed_at']}';
}
