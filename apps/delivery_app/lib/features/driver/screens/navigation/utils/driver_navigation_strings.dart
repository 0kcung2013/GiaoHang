class DriverNavigationStrings {
  const DriverNavigationStrings._();

  static const swipeConfirmPickupArrival = 'Đã đến điểm lấy hàng';
  static const swipeConfirmPickup = 'Đã lấy hàng';
  static const swipeStartDelivery = swipeConfirmPickup;
  static const swipeConfirmDelivery = 'Đã giao hàng';
  static const arriveToConfirm = 'Đến trong 100 m để xác nhận';
  static const swipeProofHint = 'Đến trong phạm vi 100 m để mở xác nhận ảnh.';
  static const deliveryDeadlineMissing = 'Chưa có hạn giao';
  static String deliveryMinutesRemaining(int minutes) => 'Còn $minutes phút';
  static String deliveryMinutesOverdue(int minutes) => 'Quá hạn $minutes phút';

  static const senderRole = 'Người gửi';
  static const recipientRole = 'Người nhận';
  static const contactOrder = 'Liên hệ đơn hàng';
  static const contactAction = 'Liên hệ';
  static const callContact = 'Gọi';
  static const contactSender = 'Liên hệ người gửi';
  static const contactRecipient = 'Liên hệ người nhận';
  static const callSender = 'Gọi người gửi';
  static const callRecipient = 'Gọi người nhận';
  static const messageSender = 'Nhắn người gửi';
}
