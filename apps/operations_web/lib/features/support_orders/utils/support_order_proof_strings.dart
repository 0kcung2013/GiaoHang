abstract final class SupportOrderProofStrings {
  static const title = 'Ảnh lấy / giao hàng';
  static const pickup = 'Ảnh lấy hàng';
  static const delivery = 'Ảnh giao hàng';
  static const returned = 'Ảnh hoàn hàng';
  static const notVisible = 'Chưa có ảnh được hiển thị';
  static const loadError = 'Không thể tải danh sách ảnh.';
  static const imageError = 'Không thể tải ảnh';
  static const loading = 'Đang tải ảnh';
  static const retry = 'Thử lại';
  static const refresh = 'Tải lại ảnh';
  static const view = 'Xem ảnh lớn';
  static const zoom = 'Cuộn hoặc chụm để phóng to ảnh';
  static const close = 'Đóng ảnh';

  static String stageLabel(String stage) => switch (stage) {
    'pickup' => pickup,
    'delivery' => delivery,
    'return' => returned,
    _ => title,
  };
}
