import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/location/driver_active_delivery_tracking_policy.dart';
import '../../../../core/location/driver_location_producer_policy.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/providers/customer_providers.dart';
import '../../../../core/providers/driver_nav_session_provider.dart';
import '../../../../core/providers/location_providers.dart';
import '../home/utils/driver_home_formatters.dart';
import '../navigation/models/driver_delivery_workflow.dart';
import '../navigation/utils/driver_demo_movement_tracker.dart';
import '../navigation/utils/driver_navigation_route_logic.dart';
import '../../../../core/services/osrm_service.dart';

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

  @override
  void dispose() {
    _demoMovementTracker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.userId;
    final driver = ref.watch(driverByUserIdProvider(userId)).valueOrNull;
    final orders = ref.watch(driverOrdersProvider(userId)).valueOrNull;
    final activeOrders =
        orders?.where(isActiveDriverOrder).toList() ?? const <OrderModel>[];
    final activeOrder = activeOrders.isEmpty ? null : activeOrders.first;
    if (driver == null || activeOrder == null) return const SizedBox.shrink();

    final session = ref.watch(driverNavSessionsProvider)[activeOrder.id];
    final isNavigationMapOpen =
        ref.watch(activeDriverNavigationOrderProvider) == activeOrder.id;
    final hasRestoredNavigationSession =
        session != null &&
        session.canRestoreFor(
          activeOrderId: activeOrder.id,
          activeStatus: activeOrder.status,
        );
    final canSimulateMovement = DriverDeliveryWorkflow.canSimulateMovement(
      status: activeOrder.status,
      pickupConfirmed: session?.pickupConfirmed ?? false,
      arrivedAtTarget: session?.arrivedAtTarget ?? false,
    );
    final shouldRunDemoPublisher =
        kIsWeb &&
        DriverActiveDeliveryTrackingPolicy.shouldRunDemoPublisher(
          isNavigationMapOpen: isNavigationMapOpen,
          hasRestoredNavigationSession: hasRestoredNavigationSession,
          canSimulateMovement: canSimulateMovement,
        );
    if (shouldRunDemoPublisher) {
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

    if (!DriverActiveDeliveryTrackingPolicy.shouldUseLiveGps(
      isNavigationMapOpen: isNavigationMapOpen,
      hasRestoredNavigationSession: hasRestoredNavigationSession,
    )) {
      return const SizedBox.shrink();
    }

    ref.watch(driverLocationStreamProvider(driver.id));
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
    final initialPosition = LatLng(request.session.lat, request.session.lng);
    final waypoints = DriverNavigationRouteLogic.buildWaypoints(
      order: request.order,
      driverPosition: initialPosition,
    );
    final route = await OsrmService().getRouteWithWaypoints(
      waypoints: waypoints,
    );
    if (!mounted || _requestedDemoKey != request.key) return;

    final points = route?.points ?? waypoints;
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
      canMove: () =>
          mounted &&
          _requestedDemoKey == request.key &&
          DriverDeliveryWorkflow.canSimulateMovement(
            status: request.order.status,
            pickupConfirmed: request.session.pickupConfirmed,
            arrivedAtTarget: request.session.arrivedAtTarget,
          ),
      onPosition: (position, nextIndex, reachedEnd) {
        unawaited(
          _publishDemoPosition(
            request: request,
            position: position,
            nextRouteIndex: nextIndex,
            reachedEnd: reachedEnd,
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
  }) async {
    if (!mounted || _requestedDemoKey != request.key) return;

    unawaited(
      ref
          .read(realtimeServiceProvider)
          .broadcastDriverLocation(
            orderId: request.order.id,
            lat: position.latitude,
            lng: position.longitude,
          ),
    );
    unawaited(
      ref
          .read(locationIngestServiceProvider)
          .ingest(
            driverProfileId: request.driverProfileId,
            driverUserId: request.driverUserId,
            orderId: request.order.id,
            lat: position.latitude,
            lng: position.longitude,
            prioritySync: true,
            coordinateSpace: LocationIngestCoordinateSpace.mapCoordinates,
          ),
    );
    await ref
        .read(driverNavSessionsProvider.notifier)
        .upsert(
          request.session.copyWith(
            lat: position.latitude,
            lng: position.longitude,
            simRouteIndex: nextRouteIndex,
            arrivedAtTarget: reachedEnd || request.session.arrivedAtTarget,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }
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

  String get key => '${order.id}:${order.status}:${session.pickupConfirmed}';
}
