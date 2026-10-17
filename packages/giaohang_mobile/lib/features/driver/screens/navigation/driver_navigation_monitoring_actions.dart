part of 'driver_navigation_screen.dart';

extension _DriverNavigationMonitoringActions on _DriverNavigationScreenState {
  Future<void> _publishMonitoringHeartbeat() async {
    if (!mounted ||
        _monitoringHeartbeatPending ||
        _exitingForOrderCancellation ||
        _authenticatedUser == null) {
      return;
    }
    _monitoringHeartbeatPending = true;
    try {
      final order = _currentOrder;
      if (_usesRouteSimulation) {
        final position = _driverPos;
        if (position == null || order.driverId == null) return;
        await ref
            .read(locationIngestServiceProvider)
            .ingest(
              driverUserId: order.driverId,
              orderId: order.id,
              lat: position.latitude,
              lng: position.longitude,
              accuracy: 0,
              capturedAt: DateTime.now(),
              prioritySync: true,
              speed: _movementSpeedKmh / 3.6,
              coordinateSpace: LocationIngestCoordinateSpace.mapCoordinates,
            );
        unawaited(
          ref
              .read(realtimeServiceProvider)
              .broadcastDriverLocation(
                orderId: order.id,
                lat: position.latitude,
                lng: position.longitude,
                speedKmh: _movementSpeedKmh,
              ),
        );
      } else {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        if (!mounted || _exitingForOrderCancellation) return;
        await _onDriverMoved(
          LatLng(position.latitude, position.longitude),
          source: DriverPositionSource.deviceGps,
          gpsTimestamp: position.timestamp,
          gpsAccuracy: position.accuracy,
        );
      }
    } finally {
      _monitoringHeartbeatPending = false;
    }
  }

  Future<void> _recoverMonitoringGps() async {
    if (!_usesRouteSimulation) {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('LOCATION_PERMISSION_REQUIRED');
      }
      if (!mounted) return;
      await _startGpsStream();
      await _startForegroundLocationService();
    }
    await _publishMonitoringHeartbeat();
    if (mounted) ref.invalidate(driverMonitoringProvider(_currentOrder.id));
  }

  Future<void> _handleMonitoringRelease(String? ticketId) async {
    if (_exitingForOrderCancellation || !mounted) return;
    _exitingForOrderCancellation = true;
    _simTimer?.cancel();
    _routeRefreshTimer?.cancel();
    _monitoringHeartbeatTimer?.cancel();
    await _posStream?.cancel();
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
