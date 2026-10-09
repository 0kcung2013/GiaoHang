abstract final class DriverDeliveryArrivalStrings {
  static const simulationStopped = 'GPS mô phỏng đã dừng';
  static const swipeArrival = 'Gạt đã đến nơi giao hàng';
  static const deliverNow = 'Giao hàng ngay';
  static const reportRecipient = 'Không liên lạc được với khách';
  static const evidenceRequired =
      'Thêm ảnh lịch sử thể hiện ít nhất 3 lần gọi người nhận trong 10 phút chờ.';
  static const evidenceHint =
      'Ảnh phải rõ số người nhận và giờ của ít nhất 3 cuộc gọi trong 10 phút kể từ khi xác nhận đã đến. CSKH kiểm tra trước khi xử lý hoàn hàng.';
  static const loading = 'Đang tải thời gian chờ…';
  static const retry = 'Chưa tải được thời gian chờ. Thử lại';
  static const arrivalRequired =
      'Gạt xác nhận đã đến điểm giao trước khi báo cáo.';
  static const waitRequired =
      'Chờ đủ 10 phút từ khi xác nhận đã đến điểm giao.';
  static const arrivalFailed =
      'Chưa xác nhận được. Hãy kiểm tra GPS và thử lại.';
  static const locationStale = 'Vị trí chưa đồng bộ. Thử lại';
  static const outsideGeofence = 'Chưa ở gần điểm giao (100 m). Thử lại';
  static const locationTimeout = 'Chưa lấy được vị trí. Thử lại';
  static const locationPermission = 'Cho phép truy cập vị trí rồi thử lại';
  static const locationDisabled = 'Bật GPS rồi thử lại';
  static const invalidStatus = 'Đơn không còn ở trạng thái đang giao. Tải lại';
  static String remaining(Duration wait) {
    final seconds = (600 - wait.inSeconds).clamp(0, 600);
    return 'Chờ ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
