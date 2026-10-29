import 'business_settings.dart';

class DeliveryFeeBreakdown {
  const DeliveryFeeBreakdown({
    required this.baseFee,
    required this.standardDistanceFee,
    required this.longDistanceFee,
    required this.includedDistanceKm,
    required this.standardBillableKm,
    required this.longBillableKm,
    required this.total,
    this.standardPerKm = 5000,
    this.longDistancePerKm = 4000,
  });

  final double baseFee;
  final double standardDistanceFee;
  final double longDistanceFee;
  final double includedDistanceKm;
  final double standardBillableKm;
  final double longBillableKm;
  final double total;
  final double standardPerKm;
  final double longDistancePerKm;

  double get distanceFee => standardDistanceFee + longDistanceFee;
  double get roundingAdjustment => total - baseFee - distanceFee;
}

/// Giá đơn mới: phí cơ bản + một đơn giá cho phần khoảng cách vượt gói.
/// Snapshot cũ có đủ hai trường đường dài tiếp tục dùng công thức theo bậc cũ.
class DeliveryPricingPolicy {
  DeliveryPricingPolicy._();

  static const double includedDistanceKm = 2;
  static const double longDistanceThresholdKm = 10;
  static const double baseFee = 18000;
  static const double standardPerKm = 5000;
  static const double longDistancePerKm = 4000;
  static const double roundingUnit = 1000;

  static DeliveryFeeBreakdown calculate({
    required double distanceMeters,
    BusinessSettings? settings,
  }) {
    final values = settings ?? BusinessSettings();
    final includedDistanceKm = values.number('included_distance_m') / 1000;
    final legacy = values.usesLegacyPricing;
    final longDistanceThresholdKm = legacy
        ? values.number('long_distance_threshold_m') / 1000
        : double.infinity;
    final baseFee = values.number('base_fee').toDouble();
    final standardPerKm = values.number('standard_per_km').toDouble();
    final longDistancePerKm = legacy
        ? values.number('long_distance_per_km').toDouble()
        : 0.0;
    final roundingUnit = values.number('rounding_unit').toDouble();
    final distanceKm = distanceMeters > 0 ? distanceMeters / 1000 : 0.0;
    final standardBillableKm = (distanceKm - includedDistanceKm)
        .clamp(0, longDistanceThresholdKm - includedDistanceKm)
        .toDouble();
    final longBillableKm = (distanceKm - longDistanceThresholdKm)
        .clamp(0, double.infinity)
        .toDouble();
    final standardDistanceFee = standardBillableKm * standardPerKm;
    final longDistanceFee = longBillableKm * longDistancePerKm;
    final total =
        ((baseFee + standardDistanceFee + longDistanceFee) / roundingUnit)
            .ceil() *
        roundingUnit;
    return DeliveryFeeBreakdown(
      baseFee: baseFee,
      standardDistanceFee: standardDistanceFee,
      longDistanceFee: longDistanceFee,
      includedDistanceKm: includedDistanceKm,
      standardBillableKm: standardBillableKm,
      longBillableKm: longBillableKm,
      total: total,
      standardPerKm: standardPerKm,
      longDistancePerKm: longDistancePerKm,
    );
  }
}
