enum OrderPaymentMode {
  prepaid,
  cod;

  String get databaseValue => name;

  static OrderPaymentMode fromValue(Object? value) {
    return value?.toString().toLowerCase() == prepaid.name ? prepaid : cod;
  }
}

enum DeliveryFeePayer {
  sender,
  recipient;

  String get databaseValue => name;

  static DeliveryFeePayer fromValue(Object? value) {
    return value?.toString().toLowerCase() == sender.name ? sender : recipient;
  }
}

enum OrderPaymentStatus {
  notRequired('not_required'),
  pending('pending'),
  paid('paid'),
  failed('failed'),
  expired('expired'),
  refundRequired('refund_required'),
  refunded('refunded');

  const OrderPaymentStatus(this.databaseValue);

  final String databaseValue;

  static OrderPaymentStatus fromValue(Object? value) {
    final normalized = value?.toString().toLowerCase();
    return values.firstWhere(
      (status) => status.databaseValue == normalized,
      orElse: () => OrderPaymentStatus.notRequired,
    );
  }
}

class OrderFinance {
  const OrderFinance.calculate({
    required this.deliveryFeePayer,
    required this.goodsValue,
    required this.codCollectionAmount,
    required this.deliveryFee,
  }) : driverNetEarning = deliveryFee,
       driverAdvanceAmount = codCollectionAmount,
       receiverCollectionAmount =
           codCollectionAmount +
           (deliveryFeePayer == DeliveryFeePayer.recipient ? deliveryFee : 0),
       senderVnpayAmount = deliveryFeePayer == DeliveryFeePayer.sender
           ? deliveryFee
           : 0;

  final DeliveryFeePayer deliveryFeePayer;
  final int goodsValue;
  final int codCollectionAmount;
  final int deliveryFee;
  final int driverNetEarning;
  final int driverAdvanceAmount;
  final int receiverCollectionAmount;
  final int senderVnpayAmount;

  OrderPaymentMode get paymentMode =>
      deliveryFeePayer == DeliveryFeePayer.sender
      ? OrderPaymentMode.prepaid
      : OrderPaymentMode.cod;

  int get totalPrice => deliveryFee + codCollectionAmount;

  int get requiredWalletBalance => driverAdvanceAmount;
}
