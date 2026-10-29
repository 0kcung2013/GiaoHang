import 'utils/free_pick_radius.dart';

abstract final class FreePickStrings {
  static const increaseRadius = 'Tăng giới hạn đường đi thêm 500 m';
  static const decreaseRadius = 'Giảm giới hạn đường đi 500 m';
  static const currentLocation = 'Về vị trí hiện tại';
  static const expandToFindOrders = 'Nhấn + để mở rộng phạm vi tìm đơn';

  static String radiusValue(double radiusMeters) =>
      formatFreePickRadius(radiusMeters);

  static String radiusBadge(double radiusMeters) {
    if (radiusMeters <= freePickDefaultRadiusMeters) {
      return 'Phạm vi tìm đơn ≤ ${radiusValue(radiusMeters)}';
    }
    return 'FreePick ≤ ${radiusValue(radiusMeters)} đường đi';
  }

  static String radiusSemantics(double radiusMeters) =>
      'Quãng đường đến điểm lấy tối đa ${radiusValue(radiusMeters)}, '
      'Mỗi đơn áp dụng phạm vi tự chọn đã chốt khi tạo đơn';

  static String loadingWithinRadius(double radiusMeters) =>
      'Đang tìm đơn ≤ ${radiusValue(radiusMeters)} đường đi';

  static String manualOrderCount(int count, double radiusMeters) => count == 0
      ? 'Chưa có đơn tự chọn ≤ ${radiusValue(radiusMeters)} đường đi'
      : '$count đơn • ≤ ${radiusValue(radiusMeters)} đường đi';
}
