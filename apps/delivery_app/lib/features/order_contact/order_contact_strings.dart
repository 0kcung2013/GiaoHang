abstract final class OrderContactStrings {
  static const incomingDriverMessage = 'Tin nhắn từ tài xế';
  static const viewMessage = 'Xem';
  static const driverName = 'Tài xế';
  static const customerName = 'Khách hàng';
  static const recipientName = 'Người nhận hàng';
  static const viewNewMessages = 'Xem tin nhắn mới';
  static const dropToDismiss = 'Thả để ẩn';
  static const dismissMessageAlert = 'Thả vào đây để ẩn thông báo';

  static String orderLabel(String trackingCode) => 'Đơn $trackingCode';

  static String customerUnreadMessages(int count) =>
      'Mở $count tin nhắn mới từ tài xế';

  static String driverUnreadMessages(int count) =>
      'Mở $count tin nhắn mới từ khách hàng';
}
