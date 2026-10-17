part of 'driver_navigation_screen.dart';

extension _DriverNavigationSupportActions on _DriverNavigationScreenState {
  void _handleDriverOrderCancellation() {
    if (!mounted || _exitingForOrderCancellation) return;
    _exitingForOrderCancellation = true;
    _simTimer?.cancel();
    _routeRefreshTimer?.cancel();
    unawaited(_posStream?.cancel());
    _navigationOwner.state = null;
  }

  Future<void> _handleSupportCancellation() async {
    if (_exitingForOrderCancellation || !mounted) return;
    _exitingForOrderCancellation = true;
    _simTimer?.cancel();
    _routeRefreshTimer?.cancel();
    await _posStream?.cancel();
    _navigationOwner.state = null;
    final order = _currentOrder;
    final driverId = order.driverId;
    try {
      await _navSessionsNotifier.remove(order.id);
      await DriverForegroundLocationService.stop();
    } catch (error) {
      debugPrint('[SupportCancellation] navigation cleanup: $error');
    }
    if (!mounted) return;
    if (driverId != null) {
      ref.invalidate(driverAcceptanceStateProvider(driverId));
      ref.invalidate(driverByUserIdProvider(driverId));
      ref.invalidate(availableOrdersProvider(driverId));
      ref.invalidate(driverOrdersProvider(driverId));
    }
    ref.invalidate(orderByIdProvider(order.id));
    ref.invalidate(driverWalletSummaryProvider);
    ref.invalidate(driverWalletTransactionsProvider);
    final navigator = Navigator.of(context, rootNavigator: true);
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go('/driver-home');
    } else {
      navigator.popUntil((route) => route.isFirst);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator.mounted) {
        showDriverSupportCancellationDialog(navigator.context);
      }
    });
  }
}
