/// Profile contacts must reject extra digits instead of silently truncating them.
String normalizeCustomerContactPhone(String value) {
  final input = value.trim();
  if (!RegExp(r'^\+?[\d\s().-]+$').hasMatch(input)) return '';
  var digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('84')) {
    digits = '0${digits.substring(2)}';
  } else if (!digits.startsWith('0')) {
    digits = '0$digits';
  }
  return RegExp(r'^0\d{9,10}$').hasMatch(digits) ? digits : '';
}
