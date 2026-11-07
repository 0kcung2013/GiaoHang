import 'driver_location_producer_policy.dart';

/// Chọn nguồn vị trí khi tài xế đang có đơn active.
class DriverActiveDeliveryTrackingPolicy {
  const DriverActiveDeliveryTrackingPolicy._();

  /// Chỉ mô phỏng khi tài xế chọn demo hoặc đơn thuộc kịch bản traffic demo.
  static bool usesRouteSimulation({
    required bool isWeb,
    required DriverLocationMode locationMode,
    bool isTrafficDemo = false,
  }) {
    return isTrafficDemo || locationMode != DriverLocationMode.deviceGps;
  }

  /// Khi map đóng, GPS thật tiếp tục chạy ở device mode. Với session mô phỏng,
  /// giữ quyền publish cho demo để GPS thiết bị không kéo marker về điểm đầu.
  static bool shouldUseLiveGps({
    required bool isWeb,
    required DriverLocationMode locationMode,
    required bool isNavigationMapOpen,
    required bool hasRestoredNavigationSession,
    bool isTrafficDemo = false,
  }) {
    return !usesRouteSimulation(
      isWeb: isWeb,
      locationMode: locationMode,
      isTrafficDemo: isTrafficDemo,
    );
  }

  /// Khi map mô phỏng đã đóng, shell tiếp tục phát tiến trình của chặng hiện tại.
  static bool shouldRunDemoPublisher({
    required bool isWeb,
    required DriverLocationMode locationMode,
    required bool isNavigationMapOpen,
    required bool hasRestoredNavigationSession,
    required bool canSimulateMovement,
    bool isTrafficDemo = false,
  }) {
    return usesRouteSimulation(
          isWeb: isWeb,
          locationMode: locationMode,
          isTrafficDemo: isTrafficDemo,
        ) &&
        !isNavigationMapOpen &&
        hasRestoredNavigationSession &&
        canSimulateMovement;
  }
}
