part of 'driver_return_navigation_screen.dart';

extension _DriverReturnNavigationSession on _DriverReturnNavigationScreenState {
  Future<void> _restoreNavigationSession() async {
    final sessions = ref.read(driverNavSessionsProvider.notifier);
    await sessions.ready;
    if (!mounted ||
        _mission.status != OrderReturnStatus.returning ||
        _position != null) {
      return;
    }
    final saved = ref.read(driverNavSessionsProvider)[widget.order.id];
    if (saved == null ||
        !saved.canRestoreFor(
          activeOrderId: widget.order.id,
          activeStatus: 'returning',
          activeLocationMode: ref.read(driverLocationModeProvider),
        )) {
      return;
    }
    _position = LatLng(saved.lat, saved.lng);
    _positionSource = DriverPositionSource.restoredSession;
  }

  Future<void> _saveNavigationSession() async {
    final position = _position;
    if (_mission.status != OrderReturnStatus.returning ||
        position == null ||
        _positionSource == DriverPositionSource.targetFallback) {
      return;
    }
    final arrived = ReturnCompletionGuard.canComplete(_handoffDistance);
    await ref
        .read(driverNavSessionsProvider.notifier)
        .upsert(
          DriverNavSession(
            orderId: widget.order.id,
            status: 'returning',
            lat: position.latitude,
            lng: position.longitude,
            arrivedAtTarget: arrived,
            routeCompleted: _atRouteEnd,
            locationMode: ref.read(driverLocationModeProvider),
            updatedAt: DateTime.now(),
          ),
        );
  }
}
