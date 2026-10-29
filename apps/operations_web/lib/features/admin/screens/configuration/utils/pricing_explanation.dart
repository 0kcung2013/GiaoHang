import 'package:giaohang_domain/giaohang_domain.dart';

String formatPricingKm(num km) => km
    .toStringAsFixed(3)
    .replaceFirst(RegExp(r'0+$'), '')
    .replaceFirst(RegExp(r'\.$'), '')
    .replaceAll('.', ',');

String explainPricing(BusinessSettings settings) {
  final included = formatPricingKm(
    settings.number('included_distance_m') / 1000,
  );
  final base = formatVnd(settings.number('base_fee'));
  final rate = formatVnd(settings.number('standard_per_km'));
  final rounding = formatVnd(settings.number('rounding_unit'));
  if (settings.usesLegacyPricing) {
    final threshold = formatPricingKm(
      settings.number('long_distance_threshold_m') / 1000,
    );
    final longRate = formatVnd(settings.number('long_distance_per_km'));
    return '$base gồm $included km đầu; phần tiếp theo đến $threshold km tính $rate/km; phần vượt $threshold km tính $longRate/km. Làm tròn lên theo $rounding.';
  }
  return '$base gồm $included km đầu. Mỗi km vượt $included km tính $rate/km. Tổng phí làm tròn lên theo $rounding.';
}
