/// Reject stale fixes before updating latest position, maps or the history queue.
abstract final class PhysicalGpsPolicy {
  // Discovery may use browser/network positioning. Arrival and monitoring may not.
  static const onlineAccuracyMeters = 200.0;
  static const deliveryAccuracyMeters = 50.0;
  static bool accepts({
    required DateTime now,
    DateTime? capturedAt,
    double? accuracy,
    bool onlinePresence = false,
  }) =>
      (accuracy == null ||
          (accuracy.isFinite &&
              accuracy >= 0 &&
              accuracy <=
                  (onlinePresence
                      ? onlineAccuracyMeters
                      : deliveryAccuracyMeters))) &&
      (capturedAt == null ||
          (!capturedAt.isBefore(now.subtract(const Duration(seconds: 90))) &&
              !capturedAt.isAfter(now.add(const Duration(seconds: 15)))));
}
