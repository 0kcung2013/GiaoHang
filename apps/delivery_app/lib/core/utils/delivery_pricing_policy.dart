class DeliveryFeeBreakdown {
  const DeliveryFeeBreakdown({
    required this.baseFee,
    required this.standardDistanceFee,
    required this.longDistanceFee,
    required this.includedDistanceKm,
    required this.standardBillableKm,
    required this.longBillableKm,
    required this.total,
  });

  final double baseFee;
  final double standardDistanceFee;
  final double longDistanceFee;
  final double includedDistanceKm;
  final double standardBillableKm;
  final double longBillableKm;
  final double total;

  double get distanceFee => standardDistanceFee + longDistanceFee;
}

/// Chính sách giá cố định, minh bạch cho dịch vụ giao hàng tiêu chuẩn.
///
/// Không áp dụng surge pricing, thời tiết, khuyến mãi hoặc phụ phí ẩn vì hệ
/// thống hiện chưa có nguồn dữ liệu đủ tin cậy cho các yếu tố đó.
class DeliveryPricingPolicy {
  DeliveryPricingPolicy._();

  static const double includedDistanceKm = 2;
  static const double longDistanceThresholdKm = 10;
  static const double baseFee = 18000;
  static const double standardPerKm = 5000;
  static const double longDistancePerKm = 4000;
  static const double roundingUnit = 1000;

  static DeliveryFeeBreakdown calculate({required double distanceMeters}) {
    final distanceKm = distanceMeters > 0 ? distanceMeters / 1000 : 0.0;
    final standardBillableKm = (distanceKm - includedDistanceKm)
        .clamp(0, longDistanceThresholdKm - includedDistanceKm)
        .toDouble();
    final longBillableKm = (distanceKm - longDistanceThresholdKm)
        .clamp(0, double.infinity)
        .toDouble();

    final standardDistanceFee = standardBillableKm * standardPerKm;
    final longDistanceFee = longBillableKm * longDistancePerKm;
    final subtotal = baseFee + standardDistanceFee + longDistanceFee;
    final total = (subtotal / roundingUnit).ceil() * roundingUnit;

    return DeliveryFeeBreakdown(
      baseFee: baseFee,
      standardDistanceFee: standardDistanceFee,
      longDistanceFee: longDistanceFee,
      includedDistanceKm: includedDistanceKm,
      standardBillableKm: standardBillableKm,
      longBillableKm: longBillableKm,
      total: total,
    );
  }
}
