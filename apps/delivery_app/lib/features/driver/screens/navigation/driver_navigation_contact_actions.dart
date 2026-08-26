part of 'driver_navigation_screen.dart';

extension _DriverNavigationContactActions on _DriverNavigationScreenState {
  Future<void> _openOrderChat() async {
    final order = _currentOrder;
    final isDelivery =
        order.status == 'delivering' || order.status == 'delivered';
    final recipientName = order.recipientName?.trim() ?? '';
    final currentUserId =
        _authenticatedUser?.id ?? order.driverId ?? 'driver-demo';

    await showOrderContactChatSheet(
      context: context,
      orderId: order.id,
      currentUserId: currentUserId,
      currentRole: OrderContactSenderRole.driver,
      counterpartName: isDelivery && recipientName.isNotEmpty
          ? recipientName
          : isDelivery
          ? OrderContactStrings.recipientName
          : OrderContactStrings.customerName,
      stage: isDelivery ? OrderContactStage.delivery : OrderContactStage.pickup,
    );
  }

  Future<void> _openActiveOrderContact() async {
    final order = _currentOrder;
    final isDelivery =
        order.status == 'delivering' || order.status == 'delivered';
    final contactLabel = isDelivery ? 'người nhận' : 'người tạo đơn';
    final address = isDelivery ? order.deliveryAddress : order.pickupAddress;
    var contactName = isDelivery ? (order.recipientName?.trim() ?? '') : '';
    var phone = isDelivery ? order.recipientPhone?.trim() : null;

    if (!isDelivery) {
      try {
        final senderContact = await ref
            .read(customerOrderServiceProvider)
            .getOrderSenderContact(order.id);
        contactName = senderContact?.name ?? '';
        phone = senderContact?.phone;
      } catch (error) {
        debugPrint('[OrderContact] Cannot load order sender contact: $error');
      }
      if (!mounted) return;
    }

    if (contactName.isEmpty) {
      contactName = isDelivery ? 'Người nhận hàng' : 'Người tạo đơn';
    }

    final action = await showArrivalContactSheet(
      context: context,
      contactLabel: contactLabel,
      contactName: contactName,
      phone: phone,
      address: address,
    );
    if (!mounted || action == null) return;

    if (action == ArrivalContactAction.call) {
      final normalizedPhone = phone?.trim() ?? '';
      if (normalizedPhone.isEmpty) return;
      await showDemoCallSheet(
        context: context,
        contactLabel: contactLabel,
        contactName: contactName,
        phone: normalizedPhone,
      );
      return;
    }

    final currentUserId =
        _authenticatedUser?.id ?? order.driverId ?? 'driver-demo';
    await showOrderContactChatSheet(
      context: context,
      orderId: order.id,
      currentUserId: currentUserId,
      currentRole: OrderContactSenderRole.driver,
      counterpartName: contactName,
      stage: isDelivery ? OrderContactStage.delivery : OrderContactStage.pickup,
    );
  }
}
