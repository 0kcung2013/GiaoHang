String formatVndDigits(num amount) {
  final rounded = amount.round();
  final negative = rounded < 0;
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();

  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[index]);
  }

  return '${negative ? '-' : ''}$buffer';
}

String formatVnd(num amount) => '${formatVndDigits(amount)}đ';
