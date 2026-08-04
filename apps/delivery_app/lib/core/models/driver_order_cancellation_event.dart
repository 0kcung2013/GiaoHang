class DriverOrderCancellationEvent {
  const DriverOrderCancellationEvent({
    required this.eventId,
    required this.orderId,
    required this.orderCode,
    this.driverId,
  });

  final String eventId;
  final String orderId;
  final String? driverId;
  final String orderCode;

  static DriverOrderCancellationEvent? fromBroadcastPayload(
    Map<String, dynamic> payload,
  ) {
    final eventId = payload['eventId']?.toString().trim() ?? '';
    final orderId = payload['orderId']?.toString().trim() ?? '';
    final orderCode = payload['orderCode']?.toString().trim() ?? '';
    final rawDriverId = payload['driverId']?.toString().trim() ?? '';

    if (eventId.isEmpty || orderId.isEmpty || orderCode.isEmpty) {
      return null;
    }

    return DriverOrderCancellationEvent(
      eventId: eventId,
      orderId: orderId,
      driverId: rawDriverId.isEmpty ? null : rawDriverId,
      orderCode: orderCode,
    );
  }

  Map<String, dynamic> toBroadcastPayload() {
    return {
      'eventId': eventId,
      'orderId': orderId,
      if (driverId != null) 'driverId': driverId,
      'orderCode': orderCode,
    };
  }

  bool isRelevantTo({
    required String driverUserId,
    required Set<String> availableOrderIds,
  }) {
    final assignedDriverId = driverId;
    if (assignedDriverId != null) {
      return assignedDriverId == driverUserId;
    }
    return availableOrderIds.contains(orderId);
  }
}
