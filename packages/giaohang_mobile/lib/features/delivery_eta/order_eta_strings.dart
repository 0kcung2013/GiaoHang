abstract final class OrderEtaStrings {
  static const waiting = 'Thời gian giao sẽ cập nhật khi tài xế nhận đơn.';
  static const ended = 'Đơn đã kết thúc';
  static const calculating = 'Đang tính thời gian giao';
  static const unavailable = 'Chưa tính được thời gian giao';
  static const retrying = 'Chờ cập nhật vị trí hoặc tuyến đường';
  static const stale = 'Chưa cập nhật được · dự báo gần nhất';
  static const delayed = 'Đã quá giờ giao dự kiến';
  static const pickup = 'Đang lấy hàng';
  static const handoff = 'Đang bàn giao';
  static const predicted = 'Dự kiến giao';
  static const details = 'Chi tiết thời gian';
  static const initialEstimate = 'Ước tính khi nhận đơn';
  static const preparationRemoved = 'Đã trừ 5 phút chuẩn bị';
  static const prepare = 'Chuẩn bị xuất phát';
  static const approach = 'Di chuyển đến điểm lấy';
  static const pickupHandling = 'Nhận hàng';
  static const delivery = 'Di chuyển đến điểm giao';
  static const deliveryHandling = 'Bàn giao';
  static const historical = 'Hiệu chỉnh giao thông lịch sử';
  static const simulated = 'AI dự đoán tốc độ · dữ liệu mô phỏng';
  static const distanceLabel = 'Tổng quãng đường';
  static const averageSpeedLabel = 'Tốc độ trung bình';
  static String distance(double meters) =>
      '${(meters / 1000).toStringAsFixed(2).replaceAll('.', ',')} km';
  static String averageSpeed(double speed) =>
      '${speed.toStringAsFixed(1).replaceAll('.', ',')} km/h';
  static const legacySimulated = 'ETA theo tốc độ giao thông mô phỏng';
  static const lightgbmComparison = 'LightGBM đối chiếu · di chuyển';
  static const baseline = 'Ước tính theo tuyến đường · 25 km/h';
  static String remaining(int minutes) => 'Còn khoảng $minutes phút';
  static String minutes(double value) => '${value.ceil()} phút';
}
