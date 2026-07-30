import 'dart:math' as math;

class DeliveryEtaEstimate {
  const DeliveryEtaEstimate({
    required this.minMinutes,
    required this.maxMinutes,
    required this.calibratedTravelMinutes,
    required this.handlingMinutes,
    required this.rawRouteMinutes,
    required this.usedRouteDuration,
    required this.isPeakHour,
  });

  final int minMinutes;
  final int maxMinutes;
  final double calibratedTravelMinutes;
  final int handlingMinutes;
  final double? rawRouteMinutes;
  final bool usedRouteDuration;
  final bool isPeakHour;

  String get rangeLabel => '$minMinutes–$maxMinutes phút';
}

/// ETA thông thường, không dùng AI và không giả định có dữ liệu giao thông sống.
///
/// OSRM là một tín hiệu đầu vào. Kết quả được kiểm tra bằng vận tốc trung bình,
/// hiệu chỉnh theo khung giờ và cộng thời gian nhận/giao hàng. UI hiển thị một
/// khoảng để phản ánh độ bất định thay vì cam kết một con số tuyệt đối.
class DeliveryEtaCalculator {
  DeliveryEtaCalculator._();

  static const double normalReferenceSpeedKmh = 28;
  static const double peakReferenceSpeedKmh = 22;
  static const double normalRouteFactor = 1.10;
  static const double peakRouteFactor = 1.25;
  static const double minPlausibleSpeedKmh = 5;
  static const double maxPlausibleSpeedKmh = 55;
  static const int handlingMinutes = 6;

  static DeliveryEtaEstimate calculate({
    required double distanceMeters,
    double? routeDurationSeconds,
    DateTime? quotedAt,
  }) {
    final now = quotedAt ?? DateTime.now();
    final peakHour = _isPeakHour(now);
    final distanceKm = math.max(0, distanceMeters) / 1000;
    final rawRouteMinutes =
        routeDurationSeconds != null && routeDurationSeconds > 0
        ? routeDurationSeconds / 60
        : null;

    final routeSpeedKmh = rawRouteMinutes == null || rawRouteMinutes <= 0
        ? null
        : distanceKm / (rawRouteMinutes / 60);
    final routeDurationIsPlausible =
        routeSpeedKmh != null &&
        routeSpeedKmh >= minPlausibleSpeedKmh &&
        routeSpeedKmh <= maxPlausibleSpeedKmh;

    final referenceSpeed = peakHour
        ? peakReferenceSpeedKmh
        : normalReferenceSpeedKmh;
    final distanceBasedMinutes = distanceKm == 0
        ? 0.0
        : distanceKm / referenceSpeed * 60;
    final routeBasedMinutes = routeDurationIsPlausible
        ? rawRouteMinutes! * (peakHour ? peakRouteFactor : normalRouteFactor)
        : 0.0;

    final calibratedTravelMinutes = math.max(
      distanceBasedMinutes,
      routeBasedMinutes,
    );
    final centerMinutes = math.max(
      8.0,
      calibratedTravelMinutes + handlingMinutes,
    );
    final minMinutes = math.max(10, _floorToFive(centerMinutes));
    final maxMinutes = math.max(
      minMinutes + 5,
      _ceilToFive(centerMinutes * 1.25),
    );

    return DeliveryEtaEstimate(
      minMinutes: minMinutes,
      maxMinutes: maxMinutes,
      calibratedTravelMinutes: calibratedTravelMinutes,
      handlingMinutes: handlingMinutes,
      rawRouteMinutes: rawRouteMinutes,
      usedRouteDuration: routeDurationIsPlausible,
      isPeakHour: peakHour,
    );
  }

  static bool _isPeakHour(DateTime value) {
    final minuteOfDay = value.hour * 60 + value.minute;
    final morningPeak = minuteOfDay >= 6 * 60 + 30 && minuteOfDay < 9 * 60;
    final eveningPeak =
        minuteOfDay >= 16 * 60 + 30 && minuteOfDay < 19 * 60 + 30;
    return morningPeak || eveningPeak;
  }

  static int _floorToFive(double value) => (value / 5).floor() * 5;

  static int _ceilToFive(double value) => (value / 5).ceil() * 5;
}
