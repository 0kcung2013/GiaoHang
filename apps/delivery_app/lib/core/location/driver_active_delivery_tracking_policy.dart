/// Chọn nguồn vị trí khi tài xế đang có đơn active.
class DriverActiveDeliveryTrackingPolicy {
  const DriverActiveDeliveryTrackingPolicy._();

  /// Navigation session chỉ phục vụ khôi phục UI của map. Khi map đã đóng,
  /// shell phải luôn quay lại GPS live, kể cả với session demo đã lưu.
  static bool shouldUseLiveGps({
    required bool isNavigationMapOpen,
    required bool hasRestoredNavigationSession,
  }) {
    return switch ((isNavigationMapOpen, hasRestoredNavigationSession)) {
      (true, _) => false,
      (false, true) || (false, false) => true,
    };
  }

  /// Chỉ map mới sở hữu simulation trong phiên điều hướng hiện tại.
  static bool shouldRunDemoPublisher({
    required bool isNavigationMapOpen,
    required bool hasRestoredNavigationSession,
    required bool canSimulateMovement,
  }) {
    return !isNavigationMapOpen &&
        hasRestoredNavigationSession &&
        canSimulateMovement;
  }
}
