abstract final class DriverGpsDebugStrings {
  static const currentDemoTitle = 'Demo quanh GPS hiện tại';
  static const currentDemoAtAnchor = 'Giữ nguyên GPS thiết bị';
  static String currentDemoOffset(double meters) =>
      'Lệch GPS thiết bị khoảng ${meters.round()} m';
  static const loading = 'Đang lấy GPS hiện tại…';
  static const loadingHint = 'Tối đa 8 giây. Không cần chờ dữ liệu máy chủ.';
  static const profileLoading = 'Đang đọc vị trí trên máy chủ…';
  static const profileTimedOut =
      'Máy chủ phản hồi chậm. GPS thiết bị vẫn được kiểm tra riêng.';
  static const profileUnavailable =
      'Chưa tải được vị trí máy chủ. Kiểm tra mạng rồi thử lại.';
  static const profileMissing = 'Không tìm thấy hồ sơ tài xế.';
}
