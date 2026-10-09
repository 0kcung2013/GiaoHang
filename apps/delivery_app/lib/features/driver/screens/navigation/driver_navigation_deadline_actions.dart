part of 'driver_navigation_screen.dart';

extension _DriverNavigationDeadlineActions on _DriverNavigationScreenState {
  Future<void> _ensureDeliveryDeadline() async {
    if (_currentOrder.estimatedDeliveryAt != null ||
        !const {
          'assigned',
          'picking_up',
          'delivering',
        }.contains(_currentOrder.status))
      return;
    final orderId = _currentOrder.id;
    try {
      final response = await acceptDriverOrderWithDeadline(
        Supabase.instance.client,
        orderId,
        existingOnly: true,
      );
      final rows = response is List ? response : [response];
      if (rows.isEmpty || rows.first is! Map) return;
      final deadline = DateTime.tryParse(
        rows.first['estimated_delivery_at']?.toString() ?? '',
      );
      if (mounted && _currentOrder.id == orderId && deadline != null) {
        setState(
          () => _currentOrder = _currentOrder.copyWith(
            estimatedDeliveryAt: deadline,
          ),
        );
      }
    } catch (error) {
      if (kDebugMode) debugPrint('[DeliveryDeadline] not available: $error');
    }
  }
}
