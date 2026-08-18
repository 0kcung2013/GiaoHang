import 'package:flutter/services.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

class VndInputFormatter extends TextInputFormatter {
  const VndInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return TextEditingValue.empty;

    final amount = int.tryParse(digits);
    if (amount == null) return oldValue;
    final formatted = formatVndDigits(amount);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

int parseVndInput(String value) {
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  return int.tryParse(digits) ?? 0;
}
