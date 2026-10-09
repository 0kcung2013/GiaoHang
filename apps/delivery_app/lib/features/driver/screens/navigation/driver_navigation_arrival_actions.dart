part of 'driver_navigation_screen.dart';

extension _DriverNavigationArrivalActions on _DriverNavigationScreenState {
  Future<void> _prepareDeliveryArrival() async {
    if (_currentOrder.status != 'delivering' || !_arrivedAtTarget) {
      throw StateError('DELIVERY_ARRIVAL_REQUIRED');
    }
    if (_usesRouteSimulation) {
      final position = _driverPos;
      if (position == null) throw StateError('DELIVERY_LOCATION_REQUIRED');
      await _onDriverMoved(
        position,
        source: DriverPositionSource.restoredSession,
        forceSync: true,
      );
    } else {
      final fix = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      await _onDriverMoved(
        LatLng(fix.latitude, fix.longitude),
        source: DriverPositionSource.deviceGps,
        forceSync: true,
      );
    }
  }

  Future<void> _reportUnreachableRecipient() async {
    final result = await showRiskReportSheet(
      context,
      order: _currentOrder,
      role: RiskReporterRole.driver,
      initialCategory: RiskCategory.contactIssue,
      initialLatitude: _driverPos?.latitude,
      initialLongitude: _driverPos?.longitude,
    );
    if (result != null && mounted) {
      _showWorkflowMessage(
        'Đã gửi báo cáo. CSKH sẽ kiểm tra ảnh cuộc gọi và hướng dẫn xử lý.',
      );
    }
  }

  Future<void> _confirmPickupArrival() async {
    if (_isUpdatingStatus || !_arrivedAtTarget || _driverPos == null) return;
    _updateUi(() => _isUpdatingStatus = true);
    try {
      final arrived = await ref
          .read(driverCancellationRepositoryProvider)
          .confirmArrival(
            orderId: _currentOrder.id,
            latitude: _driverPos!.latitude,
            longitude: _driverPos!.longitude,
          );
      if (!mounted) return;
      _updateUi(
        () => _currentOrder = _currentOrder.copyWith(pickupArrivedAt: arrived),
      );
      _persistNavSession();
      _showWorkflowMessage(DriverCancellationStrings.arrived);
    } catch (error) {
      _showStatusError(error);
    } finally {
      if (mounted) _updateUi(() => _isUpdatingStatus = false);
    }
  }
}
