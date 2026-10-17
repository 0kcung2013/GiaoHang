import 'package:flutter/services.dart';

const vietnamPhoneMaxLength = 11;

String normalizeVietnamPhone(String value) {
  var digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';

  if (digits.startsWith('84')) {
    digits = '0${digits.substring(2)}';
  } else if (!digits.startsWith('0')) {
    digits = '0$digits';
  }

  return digits.length > vietnamPhoneMaxLength
      ? digits.substring(0, vietnamPhoneMaxLength)
      : digits;
}

bool isValidVietnamPhone(String value) {
  return RegExp(r'^0\d{9,10}$').hasMatch(value);
}

String? validateVietnamPhone(String? value) {
  final phone = value?.trim() ?? '';
  if (phone.isEmpty) {
    return 'Vui lòng nhập số điện thoại người nhận.';
  }
  if (!phone.startsWith('0')) {
    return 'Số điện thoại phải bắt đầu bằng 0.';
  }
  if (!RegExp(r'^\d+$').hasMatch(phone)) {
    return 'Số điện thoại chỉ được chứa chữ số.';
  }
  if (phone.length < 10) {
    return 'Số điện thoại cần ít nhất 10 chữ số.';
  }
  if (phone.length > vietnamPhoneMaxLength) {
    return 'Số điện thoại tối đa 11 chữ số.';
  }
  return null;
}

class VietnamPhoneInputFormatter extends TextInputFormatter {
  const VietnamPhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final normalized = normalizeVietnamPhone(newValue.text);
    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }
}
