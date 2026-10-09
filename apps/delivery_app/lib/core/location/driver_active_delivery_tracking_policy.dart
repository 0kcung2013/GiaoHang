import 'driver_location_producer_policy.dart';

/// Chọn nguồn vị trí khi tài xế đang có đơn active.
class DriverActiveDeliveryTrackingPolicy {
  const DriverActiveDeliveryTrackingPolicy._();

  /// Web không có foreground GPS ổn định. Android/iOS cũng dùng mô phỏng tuyến
  /// khi tài xế chủ động chọn vị trí demo, thay vì để GPS thật ghi đè demo.
  static bool usesRouteSimulation({
    required bool isWeb,
    required DriverLocationMode locationMode,
  }) {
    return isWeb || locationMode != DriverLocationMode.deviceGps;
  }

  /// Khi map đóng, GPS thật tiếp tục chạy ở device mode. Với session mô phỏng,
  /// giữ quyền publish cho demo để GPS thiết bị không kéo marker về điểm đầu.
  static bool shouldUseLiveGps({
    required bool isWeb,
    required DriverLocationMode locationMode,
    required bool isNavigationMapOpen,
    required bool hasRestoredNavigationSession,
  }) {
    if (isNavigationMapOpen) return false;
    if (hasRestoredNavigationSession &&
        usesRouteSimulation(isWeb: isWeb, locationMode: locationMode)) {
      return false;
    }
    return true;
  }

  /// Khi map mô phỏng đã đóng, shell tiếp tục phát tiến trình của chặng hiện tại.
  static bool shouldRunDemoPublisher({
    required bool isWeb,
    required DriverLocationMode locationMode,
    required bool isNavigationMapOpen,
    required bool hasRestoredNavigationSession,
    required bool canSimulateMovement,
  }) {
    return usesRouteSimulation(isWeb: isWeb, locationMode: locationMode) &&
        !isNavigationMapOpen &&
        hasRestoredNavigationSession &&
        canSimulateMovement;
  }
}
