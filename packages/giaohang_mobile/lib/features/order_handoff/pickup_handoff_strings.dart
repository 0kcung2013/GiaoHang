class PickupHandoffStrings {
  static const title = 'Mã bàn giao hàng';
  static const reveal = 'Hiện mã bàn giao';
  static const hide = 'Ẩn mã';
  static const loading = 'Đang lấy mã…';
  static const confirming = 'Đang xác nhận…';
  static String validUntil(String time) => 'Có hiệu lực đến $time';
  static const notice =
      'Chỉ cung cấp mã khi đồng ý bàn giao hàng cho đúng tài xế. '
      'Khi xác nhận thành công, trách nhiệm giữ hàng chuyển sang tài xế.';
  static const confirmed = 'Đã xác nhận bàn giao';
  static const receipt =
      'Bạn đã hoàn tất bàn giao. Tài xế chịu trách nhiệm giữ và giao hàng.';
  static const expired = 'Mã đã hết hạn. Bấm hiện mã để lấy mã mới.';
  static const codeLabel = 'Mã bàn giao 4 số';
  static const driverNotice =
      'Nhập mã do người tạo đơn cung cấp sau khi kiểm tra và nhận hàng. '
      'Xác nhận thành công, bạn chịu trách nhiệm giữ và giao hàng.';
  static const confirm = 'Xác nhận nhận hàng';
  static const codeRequired =
      'Cần mã bàn giao 4 số từ người tạo đơn để nhận hàng.';
  static const codeInvalid =
      'Mã bàn giao chưa đúng. Hãy kiểm tra với người tạo đơn.';
  static const codeLocked = 'Đã nhập sai 5 lần. Tạm khóa nhập mã trong 5 phút.';
  static const codeExpired =
      'Mã chưa được mở hoặc đã hết hạn. Nhờ người tạo đơn mở mã bàn giao mới.';
  static const unavailable = 'Đơn đã thay đổi. Hãy tải lại thông tin đơn hàng.';
  static const loadFailure = 'Chưa lấy được mã bàn giao. Vui lòng thử lại.';
  static const confirmationFailure =
      'Chưa nhận được xác nhận từ server. Kiểm tra kết nối và thử lại.';
}
