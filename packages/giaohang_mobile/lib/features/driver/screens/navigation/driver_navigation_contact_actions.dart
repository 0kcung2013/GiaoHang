part of 'driver_navigation_screen.dart';

extension _DriverNavigationContactActions on _DriverNavigationScreenState {
  Future<void> _openOrderChat() async {
    final order = _currentOrder;
    final workflow = DriverDeliveryWorkflow.fromStatus(
      order.status,
      pickupConfirmed: _pickupConfirmed,
    );
    if (!workflow.allowsContactChat) return;

    var senderName = '';
    try {
      final senderContact = await ref
          .read(customerOrderServiceProvider)
          .getOrderSenderContact(order.id);
      senderName = senderContact?.name.trim() ?? '';
    } catch (error) {
      debugPrint('[OrderContact] Cannot load order sender contact: $error');
    }
    if (!mounted) return;

    final currentUserId =
        _authenticatedUser?.id ?? order.driverId ?? 'driver-demo';

    await showOrderContactChatSheet(
      context: context,
      orderId: order.id,
      currentUserId: currentUserId,
      currentRole: OrderContactSenderRole.driver,
      counterpartName: senderName.isEmpty
          ? OrderContactStrings.senderName
          : senderName,
      stage: OrderContactStage.pickup,
    );
  }

  Future<void> _openActiveOrderContact() async {
    final order = _currentOrder;
    final workflow = DriverDeliveryWorkflow.fromStatus(
      order.status,
      pickupConfirmed: _pickupConfirmed,
    );
    final isRecipient = workflow.contactsRecipient;
    var senderName = '';
    var senderPhone = '';
    try {
      final senderContact = await ref
          .read(customerOrderServiceProvider)
          .getOrderSenderContact(order.id);
      senderName = senderContact?.name.trim() ?? '';
      senderPhone = senderContact?.phone.trim() ?? '';
    } catch (error) {
      debugPrint('[OrderContact] Cannot load order sender contact: $error');
    }
    if (!mounted) return;

    final recipientName = order.recipientName?.trim() ?? '';
    final recipientPhone = order.recipientPhone?.trim() ?? '';
    final sender = OrderCallContact(
      roleLabel: OrderContactStrings.senderName,
      name: senderName.isEmpty ? OrderContactStrings.senderName : senderName,
      phone: senderPhone,
      address: order.pickupAddress,
    );
    final recipient = OrderCallContact(
      roleLabel: OrderContactStrings.recipientRole,
      name: recipientName.isEmpty
          ? OrderContactStrings.recipientRole
          : recipientName,
      phone: recipientPhone,
      address: order.deliveryAddress,
    );
    final currentContact = isRecipient ? recipient : sender;

    final action = await showArrivalContactSheet(
      context: context,
      contactTitle: workflow.contactTitle,
      contactName: currentContact.name,
      phone: currentContact.phone,
      address: currentContact.address,
      callActionLabel: workflow.callContactLabel,
      callActionDetail: OrderContactStrings.callTargetHint,
      chatActionLabel: workflow.chatContactLabel,
    );
    if (!mounted || action == null) return;

    if (action == ArrivalContactAction.call) {
      final selectedContact = await showCallContactPickerSheet(
        context: context,
        sender: sender,
        recipient: recipient,
      );
      if (!mounted || selectedContact == null) return;
      await showDemoCallSheet(
        context: context,
        contactLabel: selectedContact.roleLabel,
        contactName: selectedContact.name,
        phone: selectedContact.phone,
      );
      return;
    }

    if (!workflow.allowsContactChat) return;

    final currentUserId =
        _authenticatedUser?.id ?? order.driverId ?? 'driver-demo';
    await showOrderContactChatSheet(
      context: context,
      orderId: order.id,
      currentUserId: currentUserId,
      currentRole: OrderContactSenderRole.driver,
      counterpartName: currentContact.name,
      stage: OrderContactStage.pickup,
    );
  }
}
