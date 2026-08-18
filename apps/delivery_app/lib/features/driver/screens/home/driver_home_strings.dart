class DriverHomeStrings {
  DriverHomeStrings._();

  static const activityLabel = 'Trạng thái hoạt động';
  static const activityOnline = 'Trực tuyến';
  static const activityOffline = 'Ngoại tuyến';
  static const activityBusy = 'Đang giao hàng';
  static const activityToggleLabel = 'Bật hoặc tắt trạng thái hoạt động';
  static const activityUpdating = 'Đang cập nhật trạng thái hoạt động';

  static const bannerTitle = 'Chủ động từng chuyến';
  static const bannerOnlineSubtitle = 'Đang tìm đơn phù hợp gần bạn.';
  static const bannerOfflineSubtitle = 'Bật trực tuyến khi bạn sẵn sàng.';
  static const bannerSemanticLabel =
      'Minh họa tài xế kiểm tra lộ trình bên xe máy có thùng và kiện hàng.';

  static const offerCountdownLabel = 'Thời gian nhận đơn';
  static const offerAutoTransferHint = 'Hết giờ sẽ tự chuyển tài xế khác';
  static const offerExpiredLabel = 'Đang chuyển tài xế khác…';

  static String offerCountdownSemantic(int seconds) =>
      'Còn $seconds giây để nhận đơn. Hết giờ hệ thống tự chuyển tài xế khác.';
}
