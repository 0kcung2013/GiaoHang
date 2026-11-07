part of 'driver_navigation_screen.dart';

extension _DriverNavigationLocationActions on _DriverNavigationScreenState {
  bool get _hasFreshDriverFix =>
      ref
          .read(driverArrivalFixProvider)
          ?.canRestore(
            now: DateTime.now(),
            currentMode: ref.read(driverLocationModeProvider),
            currentTrafficDemoKey: _currentOrder.trafficDemoKey,
          ) ??
      false;

  Future<void> _seedDriverPosition() async {
    if (ref.read(driverPhysicalPositionProvider) != null) return;
    final id = _currentOrder.driverId;
    if (id != null && id.isNotEmpty) {
      try {
        final driver = await ref.read(driverByUserIdProvider(id).future);
        if (!mounted) return;
        if (driver?.currentLat != null && driver?.currentLng != null) {
          ref
              .read(driverPositionPublisherProvider)
              .seedLastKnown(LatLng(driver!.currentLat!, driver.currentLng!));
        }
      } catch (_) {
        /* GPS stream may still supply the first capture. */
      }
    }
    if (!mounted || ref.read(driverPhysicalPositionProvider) != null) return;
    final mode = ref.read(driverLocationModeProvider);
    if (mode == DriverLocationMode.demoHcm) {
      final point = mode.resolveRawGps(
        email: _authenticatedUser?.email,
        lat: 0,
        lng: 0,
      );
      if (point.latitude != 0 || point.longitude != 0) {
        ref.read(driverPositionPublisherProvider).seedLastKnown(point);
      }
    }
  }

  void _restoreNavSession() {
    final saved = ref.read(driverNavSessionsProvider)[_currentOrder.id];
    _driverPos = ref.read(driverPhysicalPositionProvider);
    if (saved == null || saved.status == 'returning') return;
    if (!saved.canRestoreFor(
      activeOrderId: _currentOrder.id,
      activeStatus: _currentOrder.status,
      activeLocationMode: ref.read(driverLocationModeProvider),
    )) {
      return;
    }
    _pickupConfirmed =
        _currentOrder.status == 'picking_up' &&
        (saved.pickupConfirmed || _currentOrder.actualPickedUpAt != null);
    _simulationRequested = _usesRouteSimulation && saved.movementRunning;
    // Coordinates, arrival and route index belong to a past route, not this driver fix.
    _simRouteIndex = 0;
    _restoreArrivalFromDriverFix();
  }

  void _restoreArrivalFromDriverFix() {
    final current = ref.read(driverPhysicalPositionProvider);
    final fix = ref.read(driverArrivalFixProvider);
    _driverPos = current;
    final target = DeliveryMapUtils.nextTarget(
      status: _currentOrder.status,
      pickupLat: _currentOrder.pickupLat,
      pickupLng: _currentOrder.pickupLng,
      deliveryLat: _currentOrder.deliveryLat,
      deliveryLng: _currentOrder.deliveryLng,
    );
    _arrivedAtTarget =
        _ownsDeliveryNavigation &&
        current != null &&
        fix != null &&
        _hasFreshDriverFix &&
        DriverArrivalPolicy.isWithinArrivalRadius(
          current: fix.position,
          target: target,
        ) &&
        DriverArrivalPolicy.isWithinArrivalRadius(
          current: current,
          target: target,
        );
    _routeCompleted =
        _usesRouteSimulation &&
        _arrivedAtTarget &&
        (_routeCompleted ||
            (ref.read(driverNavSessionsProvider)[_currentOrder.id]?.status ==
                    _currentOrder.status &&
                ref
                        .read(driverNavSessionsProvider)[_currentOrder.id]
                        ?.routeCompleted ==
                    true));
    if (_routeCompleted) _simulationRequested = false;
  }

  void _applySharedPosition(LatLng? position) {
    if (!mounted) return;
    final previous = _driverPos;
    final wasArrived = _arrivedAtTarget;
    _restoreArrivalFromDriverFix();
    _updateUi(() => _driverPos = position);
    if (position == null) return;
    final route = _routePoints;
    final offRoute =
        route != null &&
        DriverNavigationRouteLogic.distanceFromRoute(route, position) > 60;
    if (offRoute) {
      _routePoints = null;
      _navigationSteps = const [];
      _totalDistance = null;
      _totalDuration = null;
      _lastRouteStatus = null;
    }
    if (_navigationOwner.state == _currentOrder.id) {
      final fix = ref.read(driverArrivalFixProvider);
      if (fix != null && _hasFreshDriverFix) {
        _observeEtaDeparture(
          position,
          fix.simulated
              ? DriverPositionSource.simulation
              : DriverPositionSource.deviceGps,
          fix.capturedAt,
          fix.accuracy,
        );
      }
      _persistNavSession();
      _advanceNavigationStep(position);
      _followCamera(
        position,
        force: previous == null || (!wasArrived && _arrivedAtTarget),
      );
      if (!_isRouting && (_routePoints == null || offRoute)) {
        unawaited(_loadRoute());
      }
    }
  }

  void _persistNavSession() {
    if (_exitingForOrderCancellation || !_ownsDeliveryNavigation) return;
    final pos = _driverPos;
    if (pos == null) return;
    final snapshot = DriverNavSession(
      orderId: _currentOrder.id,
      status: _currentOrder.status,
      lat: pos.latitude,
      lng: pos.longitude,
      arrivedAtTarget: _arrivedAtTarget,
      routeCompleted: _routeCompleted,
      pickupConfirmed: _pickupConfirmed,
      simRouteIndex: 0,
      movementRunning: _canSimulateMovement,
      locationMode: _navigationLocationMode.state,
      updatedAt: DateTime.now(),
    );
    Future<void>(() async {
      if (_navSessionsNotifier.mounted) {
        await _navSessionsNotifier.upsert(snapshot);
      }
    });
  }

  Future<void> _onDriverMoved(
    LatLng newPos, {
    required DriverPositionSource source,
    bool forceSync = false,
    bool reachedRouteEnd = false,
    DateTime? gpsTimestamp,
    double? gpsAccuracy,
  }) async {
    if (!mounted ||
        !_ownsDeliveryNavigation ||
        _navigationOwner.state != _currentOrder.id) {
      return;
    }
    if (source == DriverPositionSource.simulation && !_canSimulateMovement) {
      return;
    }
    DriverArrivalFix? fix;
    if (source == DriverPositionSource.simulation) {
      fix = DriverArrivalFix(
        position: newPos,
        capturedAt: DateTime.now(),
        accuracy: 0,
        mode: ref.read(driverLocationModeProvider),
        simulated: true,
        trafficDemoKey: _currentOrder.trafficDemoKey,
      );
    } else if (source == DriverPositionSource.deviceGps &&
        gpsTimestamp != null &&
        gpsAccuracy != null) {
      fix = DriverArrivalFix(
        position: newPos,
        capturedAt: gpsTimestamp,
        accuracy: gpsAccuracy,
        mode: ref.read(driverLocationModeProvider),
      );
    } else if (forceSync && _usesRouteSimulation) {
      final current = ref.read(driverPhysicalPositionProvider);
      if (current != null) {
        fix = ref
            .read(driverArrivalFixProvider)
            ?.sampleStationarySimulation(
              current: current,
              currentMode: ref.read(driverLocationModeProvider),
              now: DateTime.now(),
            );
      }
    }
    if (fix != null && _currentOrder.driverId != null) {
      final accepted = await ref
          .read(driverPositionPublisherProvider)
          .publish(
            fix: fix,
            driverUserId: _currentOrder.driverId!,
            orderId: _currentOrder.id,
            force: forceSync,
            speedKmh: fix.simulated ? _movementSpeedKmh : null,
          );
      if (!accepted && forceSync) throw StateError('DELIVERY_LOCATION_STALE');
    }
    if (!mounted) return;
    _applySharedPosition(ref.read(driverPhysicalPositionProvider));
    if (reachedRouteEnd && _arrivedAtTarget) {
      _updateUi(() => _routeCompleted = true);
      _persistNavSession();
    }
  }

  void _startSimulation({bool resume = true}) {
    _simTimer?.cancel();
    if (!_canSimulateMovement) return;
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

    _simTimer = Timer.periodic(_DriverNavigationScreenState._simulationTick, (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_canSimulateMovement) {
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
            (_speedProfile?.metersForDuration(
                  current,
                  _DriverNavigationScreenState._simulationTick,
                ) ??
                25 /
                    3.6 *
                    _DriverNavigationScreenState
                        ._simulationTick
                        .inMilliseconds /
                    1000) *
            (_speedProfile?.geometryScale ?? 1),
      );
      _simRouteIndex = step.nextRouteIndex;
      if (step.reachedEnd) {
        debugPrint('[SIM] Reached end of simulation route');
        timer.cancel();
      }
      unawaited(
        _onDriverMoved(
          step.position,
          source: DriverPositionSource.simulation,
          reachedRouteEnd: step.reachedEnd,
        ),
      );
    });
  }

  void _startSimulationFromMap() {
    if (!_usesRouteSimulation ||
        !_ownsDeliveryNavigation ||
        !DriverDeliveryWorkflow.canSimulateMovement(
          status: _currentOrder.status,
          pickupConfirmed: _pickupConfirmed,
          arrivedAtTarget: _arrivedAtTarget,
          routeCompleted: _routeCompleted,
        ) ||
        _routePoints == null ||
        _routePoints!.length < 2) {
      return;
    }
    _updateUi(() => _simulationRequested = true);
    _persistNavSession();
    _startSimulation(resume: true);
  }

  void _stopSimulationFromMap() {
    _simTimer?.cancel();
    _updateUi(() => _simulationRequested = false);
    _persistNavSession();
    final point = _driverPos;
    if (point != null) {
      unawaited(
        _onDriverMoved(
          point,
          source: DriverPositionSource.restoredSession,
          forceSync: true,
        ),
      );
    }
  }

  Future<void> _resumeAfterReturnCancelled(
    ReturnRedeliveryResult result,
  ) async {
    _simTimer?.cancel();
    _simulationRequested = false;
    _updateUi(() {
      _currentOrder = result.order;
      _driverPos = ref.read(driverPhysicalPositionProvider);
      _arrivedAtTarget = false;
      _routeCompleted = false;
      _pickupConfirmed = false;
      _lastRouteStatus = null;
      _routePoints = null;
      _simRouteIndex = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _navigationOwner.state = _currentOrder.id;
    });
    _persistNavSession();
    if (mounted) await _loadRoute();
  }
}
