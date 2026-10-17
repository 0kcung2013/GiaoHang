part of 'driver_navigation_screen.dart';

extension _DriverNavigationEtaActions on _DriverNavigationScreenState {
  void _observeEtaDeparture(
    LatLng position,
    DriverPositionSource source,
    DateTime? timestamp,
    double? accuracy,
  ) {
    // Phiên mới để server xác nhận GPS và bỏ 5 phút chuẩn bị đúng một lần.
    if (_currentOrder.driverMonitoring != null) return;
    if (_authenticatedUser != null &&
        !_etaDepartureRecorded &&
        ((source == DriverPositionSource.deviceGps && timestamp != null) ||
            source == DriverPositionSource.simulation) &&
        _etaDepartureDetector.add(
          position,
          timestamp ?? DateTime.now(),
          accuracyMeters: accuracy ?? 0,
          now: DateTime.now(),
        )) {
      unawaited(_recordEtaDeparture());
    }
  }

  Future<void> _recordEtaDeparture() async {
    if (_etaDeparturePending ||
        _etaDepartureRecorded ||
        (_etaDepartureRetryAt != null &&
            DateTime.now().isBefore(_etaDepartureRetryAt!)) ||
        !const {'assigned', 'picking_up'}.contains(_currentOrder.status)) {
      return;
    }
    _etaDeparturePending = true;
    final orderId = _currentOrder.id;
    try {
      await Supabase.instance.client.rpc(
        'mark_driver_eta_departure',
        params: {'p_order_id': orderId},
      );
      _etaDepartureRecorded = true;
      if (mounted) ref.invalidate(orderEtaProvider(orderId));
    } catch (error) {
      _etaDepartureRetryAt = DateTime.now().add(const Duration(seconds: 10));
      if (kDebugMode) debugPrint('[OrderETA] departure pending: $error');
    } finally {
      _etaDeparturePending = false;
    }
  }
}
