String formatDeliveryFee(double? fee) {
  if (fee == null || fee <= 0) {
    return 'Phí giao hàng sẽ được tính sau khi xác nhận.';
  }

  final value = fee.round().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < value.length; i++) {
    final remaining = value.length - i;
    buffer.write(value[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write('.');
    }
  }

  return '$bufferđ';
}

String paymentMethodLabel(String value) {
  return switch (value) {
    'vnpay' => 'Thanh toán qua VNPAY',
    'cash' => 'Thanh toán khi nhận hàng',
    _ => 'Thanh toán khi nhận hàng',
  };
}
