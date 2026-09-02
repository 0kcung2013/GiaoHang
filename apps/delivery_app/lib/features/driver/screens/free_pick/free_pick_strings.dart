import 'utils/free_pick_radius.dart';

abstract final class FreePickStrings {
  static const increaseRadius = 'Tăng bán kính FreePick thêm 500 m';
  static const decreaseRadius = 'Giảm bán kính FreePick 500 m';
  static const currentLocation = 'Về vị trí hiện tại';
  static const expandToFindOrders = 'Mở rộng bán kính để tìm đơn';

  static String radiusValue(double radiusMeters) =>
      formatFreePickRadius(radiusMeters);

  static String radiusBadge(double radiusMeters) {
    if (radiusMeters <= freePickDefaultRadiusMeters) {
      return 'Vùng tự động 2 km';
    }
    return 'FreePick ${radiusValue(radiusMeters)}';
  }

  static String radiusSemantics(double radiusMeters) =>
      'Bán kính FreePick ${radiusValue(radiusMeters)}, '
      'tự chọn đơn ngoài vùng tự động 2 km';

  static String loadingWithinRadius(double radiusMeters) =>
      'Đang tìm đơn trong ${radiusValue(radiusMeters)}';

  static String manualOrderCount(int count, double radiusMeters) =>
      '$count đơn tự chọn • ${radiusValue(radiusMeters)}';
}
