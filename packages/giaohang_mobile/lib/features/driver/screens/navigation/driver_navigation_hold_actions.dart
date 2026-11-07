part of 'driver_navigation_screen.dart';

extension _DriverNavigationHoldActions on _DriverNavigationScreenState {
  Future<void> _holdOrder() async {
    if (_isUpdatingStatus) return;
    _updateUi(() => _isUpdatingStatus = true);
    try {
      final arrival = await DriverDeliveryArrivalRepository().read(
        _currentOrder.id,
      );
      if (!mounted) return;
      if (arrival.arrivedAt == null) {
        _showWorkflowMessage(RecipientHoldStrings.arrivalRequired);
        return;
      }
      final minutes = await showRecipientHoldSheet(context);
      if (minutes == null || !mounted) return;
      await _prepareDeliveryArrival();
      final held = await ref
          .read(recipientHoldRepositoryProvider)
          .update(_currentOrder.id, minutes: minutes);
      if (!mounted) return;
      _simTimer?.cancel();
      _simulationRequested = false;
      // Remove this order's old navigation position before another job starts.
      await _navSessionsNotifier.remove(held.id);
      if (!mounted) return;
      _exitingForOrderCancellation = true;
      ref.invalidate(driverOrdersProvider(held.driverId!));
      ref.invalidate(availableOrdersProvider(held.driverId!));
      ref.invalidate(driverByUserIdProvider(held.driverId!));
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) _showWorkflowMessage(RecipientHoldStrings.failed);
    } finally {
      if (mounted) _updateUi(() => _isUpdatingStatus = false);
    }
  }
}
