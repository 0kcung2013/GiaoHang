import 'package:flutter/services.dart';
import 'package:giaohang_domain/giaohang_domain.dart' show formatVndDigits;

/// Nhóm tiền theo hàng nghìn và giữ con trỏ tại phần số đang chỉnh sửa.
class SettingsCurrencyFormatter extends TextInputFormatter {
  const SettingsCurrencyFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    final digits = newValue.text.replaceAll('.', '');
    if (digits.isEmpty) return TextEditingValue.empty;
    if (!RegExp(r'^\d+$').hasMatch(digits)) return oldValue;
    final amount = int.tryParse(digits);
    if (amount == null) return oldValue;

    final formatted = formatVndDigits(amount);
    final offset = newValue.selection.isValid
        ? newValue.selection.extentOffset.clamp(0, newValue.text.length)
        : newValue.text.length;
    var digitsToRight = RegExp(
      r'\d',
    ).allMatches(newValue.text.substring(offset)).length;
    var caret = formatted.length;
    while (caret > 0 && digitsToRight > 0) {
      caret--;
      if (formatted[caret] != '.') digitsToRight--;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: caret),
    );
  }
}
