/// Khoảng cách theo tuyến đường; tổng chỉ có khi xác định được cả hai chặng.
class OrderRouteDistance {
  const OrderRouteDistance({this.pickupMeters, this.deliveryMeters});

  final double? pickupMeters;
  final double? deliveryMeters;

  double? get totalMeters =>
      isValidMeters(pickupMeters) && isValidMeters(deliveryMeters)
      ? pickupMeters! + deliveryMeters!
      : null;

  static bool isValidMeters(double? value) =>
      value != null && value.isFinite && value >= 0;

  /// Chỉ đọc dự báo đã chốt cho đúng tài xế, không ghi lại hoặc tính lại ETA.
  static OrderRouteDistance? fromFixedEta(dynamic value, String? driverId) {
    if (value is! Map ||
        driverId == null ||
        driverId.isEmpty ||
        value['driver_id'] != driverId ||
        value['calculation_mode'] != 'assignment_once_v1') {
      return null;
    }
    final pickup = _legMeters(value['approach']);
    final delivery = _legMeters(value['delivery']);
    if (pickup == null || delivery == null) return null;
    return OrderRouteDistance(pickupMeters: pickup, deliveryMeters: delivery);
  }

  static double? _legMeters(dynamic leg) {
    if (leg is! Map || leg['distance_meters'] is! num) return null;
    final meters = (leg['distance_meters'] as num).toDouble();
    return isValidMeters(meters) ? meters : null;
  }
}
