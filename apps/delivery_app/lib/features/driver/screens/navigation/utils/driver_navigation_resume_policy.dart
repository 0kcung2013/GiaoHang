import '../../../../../core/utils/geo_utils.dart';

/// Quyết định nguồn tọa độ sau khi khôi phục một hành trình đang dở.
class DriverNavigationResumePolicy {
  const DriverNavigationResumePolicy._();

  /// GPS demo là điểm cố định, không phản ánh quãng đường đã mô phỏng.
  /// Vì vậy khi mở lại app phải ưu tiên session để không quay về đầu tuyến.
  /// GPS thật ở production luôn được phép cập nhật bình thường.
  static bool shouldKeepRestoredPosition({
    required bool hasRestoredPosition,
    required String? driverEmail,
  }) {
    return hasRestoredPosition && GeoUtils.hasTestDriverOffset(driverEmail);
  }
}
