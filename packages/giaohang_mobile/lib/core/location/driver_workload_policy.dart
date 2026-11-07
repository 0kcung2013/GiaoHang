import '../models/order_model.dart';

/// A driver has one physical position, regardless of the parcel being viewed.
class DriverWorkloadPolicy {
  static bool isWorking(OrderModel o) =>
      const {
        'assigned',
        'picking_up',
        'delivering',
        'return_approved',
        'returning',
      }.contains(o.status) &&
      !o.isRecipientHeld;

  static OrderModel? locationOwner(
    Iterable<OrderModel> orders, {
    String? preferredOrderId,
  }) {
    final working = orders.where(isWorking);
    if (working.isNotEmpty) {
      return working.where((o) => o.id == preferredOrderId).firstOrNull ??
          working
              .where((o) => o.recipientHold?.state == 'resumed')
              .firstOrNull ??
          working.first;
    }
    return orders.where((o) => o.isRecipientHeld).firstOrNull;
  }

  static bool canReceive(Iterable<OrderModel> orders, DateTime now) =>
      !orders.any(isWorking) &&
      !orders.any(
        (o) => o.isRecipientHeld && !now.isBefore(o.recipientHold!.until),
      );

  static bool canRestoreOrderPosition({
    required bool deviceGps,
    required bool hasHoldHistory,
  }) => !deviceGps && !hasHoldHistory;
}
