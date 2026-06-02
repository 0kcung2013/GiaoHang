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

String serviceTypeLabel(String value) {
  return switch (value) {
    'express' => 'Nhanh',
    'standard' => 'Tiêu chuẩn',
    _ => 'Tiêu chuẩn',
  };
}

String paymentMethodLabel(String value) {
  return switch (value) {
    'cash' => 'COD / Tiền mặt',
    _ => 'COD / Tiền mặt',
  };
}
