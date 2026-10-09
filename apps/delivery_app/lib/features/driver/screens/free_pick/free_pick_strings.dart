import 'utils/free_pick_radius.dart';

abstract final class FreePickStrings {
  static const increaseRadius = 'Tăng giới hạn đường đi thêm 500 m';
  static const decreaseRadius = 'Giảm giới hạn đường đi 500 m';
  static const currentLocation = 'Về vị trí hiện tại';
  static const expandToFindOrders = 'Nhấn + để tìm đơn trên 2 km đường đi';

  static String radiusValue(double radiusMeters) =>
      formatFreePickRadius(radiusMeters);

  static String radiusBadge(double radiusMeters) {
    if (radiusMeters <= freePickDefaultRadiusMeters) {
      return 'Tự động ≤ 2 km đường đi';
    }
    return 'FreePick ≤ ${radiusValue(radiusMeters)} đường đi';
  }

  static String radiusSemantics(double radiusMeters) =>
      'Quãng đường đến điểm lấy tối đa ${radiusValue(radiusMeters)}, '
      'FreePick chỉ nhận đơn trên 2 km và tối đa 3 km đường đi';

  static String loadingWithinRadius(double radiusMeters) =>
      'Đang tìm đơn ≤ ${radiusValue(radiusMeters)} đường đi';

  static String manualOrderCount(int count, double radiusMeters) => count == 0
      ? 'Chưa có đơn trên 2–${radiusValue(radiusMeters)} đường đi'
      : '$count đơn • ≤ ${radiusValue(radiusMeters)} đường đi';
}
