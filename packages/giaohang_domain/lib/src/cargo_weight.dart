/// Khối lượng khai báo theo kg; đơn cũ có thể chưa có dữ liệu.
double? parseCargoWeightKg(Object? value) {
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString().trim().replaceAll(',', '.') ?? '');
  return parsed != null && parsed.isFinite && parsed > 0 ? parsed : null;
}

bool isCargoWeightInput(String value) =>
    RegExp(r'^(?:\d+(?:[.,]\d{1,3})?|[.,]\d{1,3})$').hasMatch(value.trim()) &&
    parseCargoWeightKg(value) != null;

String formatCargoWeightKg(double? value) {
  if (value == null || !value.isFinite || value <= 0) return 'Chưa khai báo';
  final number = value
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'\.?0+$'), '')
      .replaceAll('.', ',');
  return '$number kg';
}
