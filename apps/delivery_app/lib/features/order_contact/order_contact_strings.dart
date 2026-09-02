abstract final class OrderContactStrings {
  static const incomingDriverMessage = 'Tin nhắn từ tài xế';
  static const viewMessage = 'Xem';
  static const driverName = 'Tài xế';
  static const customerName = 'Khách hàng';
  static const senderName = 'Người gửi';
  static const recipientRole = 'Người nhận';
  static const recipientName = 'Người nhận hàng';
  static const viewNewMessages = 'Xem tin nhắn mới';
  static const dropToDismiss = 'Thả để ẩn';
  static const dismissMessageAlert = 'Thả vào đây để ẩn thông báo';
  static const quickReplies = 'Câu trả lời nhanh';
  static const contactOrder = 'Liên hệ đơn hàng';
  static const call = 'Gọi';
  static const callTargetHint = 'Người gửi hoặc người nhận';
  static const chooseCallTarget = 'Bạn muốn gọi cho ai?';
  static const chooseCallTargetHint =
      'Chọn một liên hệ để bắt đầu cuộc gọi trình diễn.';
  static const demoMode = 'TRÌNH DIỄN';
  static const phoneUnavailable = 'Chưa có số điện thoại';

  static String orderLabel(String trackingCode) => 'Đơn $trackingCode';

  static String customerUnreadMessages(int count) =>
      'Mở $count tin nhắn mới từ tài xế';

  static String driverUnreadMessages(int count) =>
      'Mở $count tin nhắn mới từ khách hàng';

  static String callContactSemantic({
    required String roleLabel,
    required String name,
  }) => 'Gọi $roleLabel, $name';
}
