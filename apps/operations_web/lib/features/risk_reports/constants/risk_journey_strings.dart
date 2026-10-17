abstract final class RiskJourneyStrings {
  static const title = 'Giám sát hành trình';
  static const open = 'Xem hành trình GPS';
  static const reload = 'Tải lại hành trình';
  static const close = 'Đóng';
  static const retry = 'Thử lại';
  static const loadError =
      'Chưa tải được hành trình. Kiểm tra kết nối và quyền truy cập.';
  static const unreadable =
      'Chưa đọc được các phần GPS đã lưu. Vui lòng thử lại.';
  static const empty =
      'Chưa có GPS được lưu trong 14 ngày gần nhất.\nDữ liệu đang ghi có thể cần chờ đồng bộ.';
  static const legend =
      'Đường xanh: GPS đã lưu. Ngắt đoạn khi thiếu mẫu trên 60 giây, đổi tài xế hoặc tọa độ nhảy bất thường.';
  static const pickup = 'Điểm lấy hàng';
  static const delivery = 'Điểm giao hàng';
  static const selected = 'Vị trí GPS được chọn';
  static const previousPhoto = 'Ảnh trước';
  static const nextPhoto = 'Ảnh tiếp theo';
  static const zoomHint = 'Cuộn hoặc chụm để phóng to';
  static const photoError =
      'Không tải được ảnh. Đóng và tải lại hồ sơ để thử lại.';
  static String photoTitle(int index, int count) =>
      'Ảnh bằng chứng · $index/$count';
  static String photoLabel(int index) => 'Ảnh bằng chứng $index';
  static String summary(int points, int segments) =>
      'GPS thực tế · $points mẫu · $segments đoạn';
  static String partial(int chunks) => 'Có $chunks phần dữ liệu chưa đọc được.';
  static String reportTime(DateTime time) =>
      'Báo cáo: ${formatTime(time)} · Lịch sử lưu tối đa 14 ngày';
  static String timeline(DateTime selected, DateTime last) =>
      'Mốc đang xem: ${formatTime(selected)}\nGPS cuối: ${formatTime(last)}';
  static String formatTime(DateTime value) {
    final time = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(time.day)}/${two(time.month)}/${time.year} ${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }
}
