part of 'driver_navigation_screen.dart';

extension _DriverNavigationRouteActions on _DriverNavigationScreenState {
  void _startRouteRefresh() {
    _routeRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted ||
          _driverPos == null ||
          _isRouting ||
          _navigationOwner.state != _currentOrder.id) {
        return;
      }
      _lastRouteStatus = null;
      _restoreArrivalFromDriverFix();
      unawaited(_loadRoute());
    });
  }

  LatLng? _otherTaskDestination() {
    final orders =
        ref
            .watch(driverOrdersProvider(_currentOrder.driverId ?? ''))
            .valueOrNull ??
        [];
    final other = orders
        .where(
          (o) =>
              o.id != _currentOrder.id &&
              (DriverWorkloadPolicy.isWorking(o) || o.isRecipientHeld),
        )
        .firstOrNull;
    if (other == null) return null;
    return DeliveryMapUtils.nextTarget(
      status: other.status,
      pickupLat: other.pickupLat,
      pickupLng: other.pickupLng,
      deliveryLat: other.deliveryLat,
      deliveryLng: other.deliveryLng,
    );
  }

  Future<void> _loadRoute() async {
    if (_routeCompleted && _arrivedAtTarget) return;
    final origin = ref.read(driverPhysicalPositionProvider);
    if (!mounted || origin == null) return;
    if (!_usesRouteSimulation && !_hasFreshDriverFix) {
      _updateUi(() {
        _routePoints = null;
        _navigationSteps = const [];
        _isRouting = false;
        _totalDistance = null;
        _totalDuration = null;
      });
      return;
    }
    final order = _currentOrder;
    final waypoints = DriverNavigationRouteLogic.buildWaypoints(
      order: order,
      driverPosition: origin,
    );
    final statusKey =
        '${order.id}:${order.status}:${waypoints.last}:${origin.latitude.toStringAsFixed(4)}:${origin.longitude.toStringAsFixed(4)}';
    if (statusKey == _lastRouteStatus && (_isRouting || _routePoints != null)) {
      return;
    }
    _lastRouteStatus = statusKey;
    final key = ++_routeKey;
    _updateUi(() {
      _isRouting = true;
      _routeFailed = false;
    });
    OsrmRouteResult? result;
    try {
      final profile = order.trafficDemoKey == null ? null : _speedProfile;
      if (profile != null &&
          DriverNavigationRouteLogic.distanceFromRoute(
                profile.points,
                origin,
              ) <=
              30 &&
          const Distance()(profile.points.last, waypoints.last) <= 100) {
        final remaining = DeliveryMapUtils.remainingRoute(
          fullRoute: profile.points,
          current: origin,
        );
        result = OsrmRouteResult(
          points: [origin, ...remaining],
          distanceMeters: DeliveryMapUtils.remainingMeters(remaining),
          durationSeconds: profile.remainingMinutes(origin) * 60,
        );
      } else {
        result = await ref
            .read(driverNavigationRoutingProvider)
            .getRouteWithWaypoints(waypoints: waypoints);
      }
    } catch (error) {
      debugPrint('[DriverRoute] route pending: $error');
    }
    if (!mounted || key != _routeKey) return;
    final current = ref.read(driverPhysicalPositionProvider);
    if (current == null) {
      _updateUi(() => _isRouting = false);
      return;
    }
    if (result == null || result.points.length < 2) {
      _updateUi(() {
        _isRouting = false;
        _routeFailed = true;
        _routePoints = null;
        _navigationSteps = const [];
        _totalDistance = null;
        _totalDuration = null;
      });
      return;
    }
    // A route calculated before the driver moved must not pull the marker back.
    if (DriverNavigationRouteLogic.distanceFromRoute(result.points, current) >
        60) {
      _isRouting = false;
      _lastRouteStatus = null;
      if (const Distance()(origin, current) >= 30) {
        unawaited(_loadRoute());
      } else {
        _updateUi(() {
          _routeFailed = true;
          _routePoints = null;
        });
      }
      return;
    }
    final points = DeliveryMapUtils.remainingRoute(
      fullRoute: result.points,
      current: current,
    );
    _updateUi(() {
      _isRouting = false;
      _routeFailed = false;
      _routePoints = points;
      _navigationSteps = result!.steps;
      _activeNavigationStepIndex = 0;
      _totalDistance = DeliveryMapUtils.remainingMeters(points);
      _totalDuration = result.durationSeconds;
      _routeCompleted = false;
      _simRouteIndex = 0;
    });
    _fitMapBounds();
    if (_canSimulateMovement && !(_simTimer?.isActive ?? false)) {
      _startSimulation();
    }
  }
}
