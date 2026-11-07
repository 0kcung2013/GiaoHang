part of 'driver_navigation_screen.dart';

extension _DriverNavigationMonitoringActions on _DriverNavigationScreenState {
  Future<void> _publishMonitoringHeartbeat() async {
    if (!mounted ||
        _navigationOwner.state != _currentOrder.id ||
        _monitoringHeartbeatPending ||
        _exitingForOrderCancellation ||
        _authenticatedUser == null) {
      return;
    }
    // Real GPS is owned by Driver Shell, regardless of the displayed order.
    if (!_usesRouteSimulation) return;
    _monitoringHeartbeatPending = true;
    try {
      final position = ref.read(driverPhysicalPositionProvider);
      final order = _currentOrder;
      if (position == null || order.driverId == null) return;
      await ref
          .read(driverPositionPublisherProvider)
          .publish(
            driverUserId: order.driverId!,
            orderId: order.id,
            speedKmh: _movementSpeedKmh,
            fix: DriverArrivalFix(
              position: position,
              capturedAt: DateTime.now(),
              accuracy: 0,
              mode: ref.read(driverLocationModeProvider),
              simulated: true,
              trafficDemoKey: order.trafficDemoKey,
            ),
          );
    } finally {
      _monitoringHeartbeatPending = false;
    }
  }

  Future<void> _recoverMonitoringGps() async {
    if (_usesRouteSimulation) {
      await _publishMonitoringHeartbeat();
    } else {
      final position = await ref
          .read(locationServiceProvider)
          .getCurrentPosition();
      if (position == null) throw StateError('LOCATION_PERMISSION_REQUIRED');
      if (!mounted) return;
      await _onDriverMoved(
        LatLng(position.latitude, position.longitude),
        source: DriverPositionSource.deviceGps,
        gpsTimestamp: position.timestamp,
        gpsAccuracy: position.accuracy,
        forceSync: true,
      );
    }
    if (mounted) ref.invalidate(driverMonitoringProvider(_currentOrder.id));
  }

  Future<void> _handleMonitoringRelease(String? ticketId) async {
    if (_exitingForOrderCancellation || !mounted) return;
    _exitingForOrderCancellation = true;
    _simTimer?.cancel();
    _routeRefreshTimer?.cancel();
    _monitoringHeartbeatTimer?.cancel();
    if (!mounted) return;
    await handleDriverMonitoringRelease(
      context,
      ref,
      orderId: _currentOrder.id,
      userId: _authenticatedUser!.id,
      ticketId: ticketId,
    );
  }
}
