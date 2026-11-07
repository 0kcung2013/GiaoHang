import 'business_settings.dart';

enum CargoSizeGroup {
  standard('Tiêu chuẩn'),
  large('Lớn'),
  extraLarge('Rất lớn');

  const CargoSizeGroup(this.label);
  final String label;
  String get databaseValue => switch (this) {
    standard => 'standard',
    large => 'large',
    extraLarge => 'extra_large',
  };

  static CargoSizeGroup? parse(Object? value) {
    for (final group in values) {
      if (group.databaseValue == value) return group;
    }
    return null;
  }
}

/// Khai báo của khách và kết quả do server chốt trên đơn.
class CargoDetails {
  const CargoDetails({
    required this.sizeGroup,
    this.packageCount = 1,
    this.tier,
    this.surcharge = 0,
  });

  final CargoSizeGroup sizeGroup;
  final int packageCount;
  final CargoSizeGroup? tier;
  final int surcharge;

  Map<String, dynamic> toSubmission() => {
    'size_group': sizeGroup.databaseValue,
    'package_count': packageCount,
  };

  Map<String, dynamic> toJson() => {
    ...toSubmission(),
    if (tier != null) 'tier': tier!.databaseValue,
    'surcharge': surcharge,
  };

  static CargoDetails? fromJson(Object? value) {
    if (value is! Map) return null;
    final size = CargoSizeGroup.parse(value['size_group']);
    final count = value['package_count'];
    final fee = value['surcharge'];
    if (size == null ||
        count is! num ||
        !count.isFinite ||
        count < 1 ||
        count > 100 ||
        count != count.round()) {
      return null;
    }
    return CargoDetails(
      sizeGroup: size,
      packageCount: count.toInt(),
      tier: CargoSizeGroup.parse(value['tier']),
      surcharge: fee is num && fee.isFinite && fee >= 0 ? fee.toInt() : 0,
    );
  }
}

abstract final class CargoPricingPolicy {
  // Preset để Admin xem xét trước khi bật; không tự bổ sung vào policy cũ.
  static const defaults = <String, int>{
    'cargo_pricing_enabled': 0,
    'cargo_standard_weight_g': 5000,
    'cargo_standard_length_cm': 30,
    'cargo_standard_width_cm': 25,
    'cargo_standard_height_cm': 20,
    'cargo_large_weight_g': 10000,
    'cargo_large_length_cm': 40,
    'cargo_large_width_cm': 35,
    'cargo_large_height_cm': 30,
    'cargo_extra_large_weight_g': 20000,
    'cargo_extra_large_length_cm': 50,
    'cargo_extra_large_width_cm': 40,
    'cargo_extra_large_height_cm': 40,
    'cargo_large_fee': 15000,
    'cargo_extra_large_fee': 30000,
  };

  static bool supported(BusinessSettings settings) =>
      defaults.keys.every(settings.values.containsKey);
  static bool enabled(BusinessSettings settings) =>
      supported(settings) && settings.number('cargo_pricing_enabled') == 1;

  static String prefix(CargoSizeGroup group) => 'cargo_${group.databaseValue}';

  static String dimensions(BusinessSettings settings, CargoSizeGroup group) {
    final key = prefix(group);
    return '${settings.number('${key}_length_cm')} × '
        '${settings.number('${key}_width_cm')} × '
        '${settings.number('${key}_height_cm')} cm';
  }

  /// Chỉ lấy bậc cao nhất, không cộng phụ phí cân nặng và kích thước.
  static CargoDetails calculate({
    required BusinessSettings settings,
    required double weightKg,
    required CargoDetails declaration,
  }) {
    if (!enabled(settings)) {
      return CargoDetails(
        sizeGroup: declaration.sizeGroup,
        packageCount: declaration.packageCount,
      );
    }
    if (!weightKg.isFinite ||
        weightKg <= 0 ||
        weightKg > 100 ||
        (weightKg * 1000 - (weightKg * 1000).round()).abs() > 0.000001 ||
        declaration.packageCount < 1 ||
        declaration.packageCount > 100) {
      throw const FormatException('Thông tin kiện hàng không hợp lệ.');
    }
    final grams = (weightKg * 1000).round();
    if (grams > settings.number('cargo_extra_large_weight_g')) {
      throw const FormatException(
        'Hàng vượt giới hạn cân nặng nhận vận chuyển.',
      );
    }
    final weightTier = CargoSizeGroup.values.firstWhere(
      (group) => grams <= settings.number('${prefix(group)}_weight_g'),
    );
    final tier =
        CargoSizeGroup.values[weightTier.index > declaration.sizeGroup.index
            ? weightTier.index
            : declaration.sizeGroup.index];
    return CargoDetails(
      sizeGroup: declaration.sizeGroup,
      packageCount: declaration.packageCount,
      tier: tier,
      surcharge: tier == CargoSizeGroup.standard
          ? 0
          : settings.number('${prefix(tier)}_fee'),
    );
  }

  static String? validateSettings(Map<String, dynamic> values) {
    if (!defaults.keys.every(values.containsKey)) return null;
    int n(String key) => (values[key] as num).toInt();
    for (final suffix in ['weight_g', 'length_cm', 'width_cm', 'height_cm']) {
      final a = n('cargo_standard_$suffix');
      final b = n('cargo_large_$suffix');
      final c = n('cargo_extra_large_$suffix');
      if (suffix == 'weight_g' ? !(a < b && b < c) : !(a <= b && b <= c)) {
        return 'Giới hạn nhóm hàng phải tăng dần từ Tiêu chuẩn đến Rất lớn.';
      }
    }
    for (final group in CargoSizeGroup.values) {
      final key = prefix(group);
      if (n('${key}_length_cm') < n('${key}_width_cm') ||
          n('${key}_width_cm') < n('${key}_height_cm')) {
        return 'Kích thước cần theo thứ tự cạnh dài ≥ cạnh vừa ≥ cạnh ngắn.';
      }
    }
    if (n('cargo_large_fee') > n('cargo_extra_large_fee')) {
      return 'Phụ phí nhóm Rất lớn phải lớn hơn hoặc bằng nhóm Lớn.';
    }
    return null;
  }
}
