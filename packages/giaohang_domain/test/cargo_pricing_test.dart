import 'package:test/test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

void main() {
  final settings = BusinessSettings(
    values: {...CargoPricingPolicy.defaults, 'cargo_pricing_enabled': 1},
  );
  CargoDetails calculate(double kg, CargoSizeGroup size) =>
      CargoPricingPolicy.calculate(
        settings: settings,
        weightKg: kg,
        declaration: CargoDetails(sizeGroup: size, packageCount: 3),
      );

  test('takes highest weight or size tier once for the whole order', () {
    for (final size in CargoSizeGroup.values) {
      for (final (kg, weightTier) in [(5.0, 0), (10.0, 1), (20.0, 2)]) {
        final tier = size.index > weightTier ? size.index : weightTier;
        final result = calculate(kg, size);
        expect(result.tier, CargoSizeGroup.values[tier]);
        expect(result.surcharge, [0, 15000, 30000][tier]);
        expect(result.packageCount, 3);
      }
    }
    expect(calculate(5.001, CargoSizeGroup.standard).surcharge, 15000);
    expect(calculate(10.001, CargoSizeGroup.standard).surcharge, 30000);
  });

  test('rejects overweight, nonfinite, invalid count and excess precision', () {
    for (final kg in [
      20.001,
      0.0,
      -1.0,
      double.nan,
      double.infinity,
      1e308,
      0.0001,
    ]) {
      expect(
        () => calculate(kg, CargoSizeGroup.standard),
        throwsFormatException,
      );
    }
    expect(
      () => CargoPricingPolicy.calculate(
        settings: settings,
        weightKg: 1,
        declaration: const CargoDetails(
          sizeGroup: CargoSizeGroup.standard,
          packageCount: 0,
        ),
      ),
      throwsFormatException,
    );
  });

  test('legacy or disabled policy adds no surcharge', () {
    for (final old in [
      BusinessSettings(),
      BusinessSettings(values: CargoPricingPolicy.defaults),
    ]) {
      expect(CargoPricingPolicy.enabled(old), isFalse);
      final result = DeliveryPricingPolicy.calculate(
        distanceMeters: 3000,
        settings: old,
        weightKg: 50,
        cargo: const CargoDetails(sizeGroup: CargoSizeGroup.extraLarge),
      );
      expect(result.total, 23000);
      expect(result.cargoSurcharge, 0);
    }
  });

  test('adds cargo before rounding and fee bases include cargo', () {
    final policy = BusinessSettings(
      values: {
        ...settings.values,
        'cargo_large_fee': 15500,
        'return_fee_rate_bps': 5000,
      },
    );
    final result = DeliveryPricingPolicy.calculate(
      distanceMeters: 3100,
      settings: policy,
      weightKg: 6,
      cargo: const CargoDetails(sizeGroup: CargoSizeGroup.standard),
    );
    expect(result.total, 39000);
    expect(result.cargoSurcharge, 15500);
    expect(result.roundingAdjustment, 0);
    expect(policy.returnFee(result.total), 19500);
    expect(
      BusinessSettings.calculatePlatformFee(result.total.round(), 1000),
      3900,
    );
  });

  test(
    'snapshot survives price change and submission excludes server result',
    () {
      final original = calculate(12, CargoSizeGroup.standard);
      final stored = CargoDetails.fromJson(original.toJson())!;
      final changed = BusinessSettings(
        values: {...settings.values, 'cargo_extra_large_fee': 50000},
      );
      expect(
        CargoPricingPolicy.calculate(
          settings: changed,
          weightKg: 12,
          declaration: original,
        ).surcharge,
        50000,
      );
      expect(stored.surcharge, 30000);
      expect(
        stored.toSubmission().keys,
        unorderedEquals(['size_group', 'package_count']),
      );
      expect(CargoDetails.fromJson(null), isNull);
      expect(
        CargoDetails.fromJson({'size_group': 'invalid', 'package_count': 1}),
        isNull,
      );
    },
  );

  test('rejects descending settings thresholds and fees', () {
    for (final changed in [
      {'cargo_large_weight_g': 5000},
      {'cargo_large_length_cm': 20},
      {'cargo_large_height_cm': 36},
      {'cargo_large_fee': 40000},
    ]) {
      expect(
        CargoPricingPolicy.validateSettings({...settings.values, ...changed}),
        isNotNull,
      );
    }
    expect(CargoPricingPolicy.validateSettings(settings.values), isNull);
  });
}
