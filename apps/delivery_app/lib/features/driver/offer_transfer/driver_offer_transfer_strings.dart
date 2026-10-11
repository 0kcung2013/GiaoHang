abstract final class DriverOfferTransferStrings {
  static const confirmTitle = 'Chuyển đơn?';
  static const confirmDescription =
      'Chuyển đơn tính một lượt từ chối. '
      'Lời mời sẽ chuyển sang tài xế phù hợp tiếp theo.';
  static const lastTitle = 'Chuyển đơn và tạm khóa?';
  static const lastDescription =
      'Chuyển đơn này sẽ đủ 4 lượt từ chối trong 30 phút, gồm cả lời mời hết hạn. '
      'Bạn sẽ tạm khóa nhận đơn mới 30 phút.';
  static const confirm = 'Chuyển đơn';
  static const confirmLast = 'Chuyển và tạm khóa';
  static const goBack = 'Quay lại';
  static const lastHint = 'Từ chối thêm 1 đơn sẽ tạm khóa 30 phút';
  static const lockDescription =
      'Bạn đã từ chối 4 đơn trong 30 phút (chuyển đơn hoặc hết giờ). '
      'Hết thời gian khóa, bạn có thể nhận đơn mới.';
  static const lockedMessage = 'Đã chuyển đơn. Tạm khóa nhận đơn mới 30 phút.';
  static const checking = 'Đang kiểm tra lượt từ chối';

  static String remaining(int count) => 'Còn $count lượt từ chối trong 30 phút';
}
