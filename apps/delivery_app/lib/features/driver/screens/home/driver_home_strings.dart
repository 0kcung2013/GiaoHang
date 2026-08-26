class DriverHomeStrings {
  DriverHomeStrings._();

  static const activityLabel = 'Trạng thái hoạt động';
  static const activityOnline = 'Trực tuyến';
  static const activityOffline = 'Ngoại tuyến';
  static const activityBusy = 'Đang giao hàng';
  static const activityToggleLabel = 'Bật hoặc tắt trạng thái hoạt động';
  static const activityUpdating = 'Đang cập nhật trạng thái hoạt động';
  static const coldStartLoading = 'Đang chuẩn bị phiên làm việc';
  static const coldStartLoadingSemantic =
      'Đang tải trạng thái hoạt động gần nhất của tài xế';
  static const coldStartErrorTitle = 'Chưa tải được trạng thái hoạt động';
  static const coldStartErrorMessage =
      'Kiểm tra kết nối rồi thử lại. Trạng thái hiện tại không bị thay đổi.';
  static const retryAction = 'Thử lại';
  static const onlineWalletTitle = 'Đã bật nhận đơn';
  static const walletBalanceLabel = 'Số dư khả dụng';
  static const walletOfferHint =
      'Bạn chỉ nhận được đơn có khoản ứng phù hợp với số dư.';
  static const walletEmptyWarning =
      'Ví chưa có số dư. Hãy nạp thêm để nhận đơn COD.';
  static const walletUnavailable =
      'Đã bật nhận đơn nhưng chưa tải được số dư ví.';
  static const walletOnlineBadge = 'ĐANG TRỰC TUYẾN';
  static const walletContinueAction = 'Bắt đầu nhận đơn';
  static const walletTopUpAction = 'Nạp thêm';
  static const walletTopUpNowAction = 'Nạp ví ngay';
  static const walletLaterAction = 'Để sau';
  static const walletCloseAction = 'Đóng thông báo số dư';

  static const bannerTitle = 'Chủ động từng chuyến';
  static const bannerOnlineSubtitle = 'Đang tìm đơn phù hợp gần bạn.';
  static const bannerOfflineSubtitle = 'Bật trực tuyến khi bạn sẵn sàng.';
  static const bannerSemanticLabel =
      'Minh họa tài xế kiểm tra lộ trình bên xe máy có thùng và kiện hàng.';

  static const offerCountdownLabel = 'Thời gian nhận đơn';
  static const offerAutoTransferHint = 'Hết giờ sẽ tự chuyển tài xế khác';
  static const offerExpiredLabel = 'Đang chuyển tài xế khác…';

  static const incomingOfferBadge = 'ĐƠN ƯU TIÊN';
  static const incomingOfferTitle = 'Đơn mới dành cho bạn';
  static const incomingOfferSubtitle =
      'Kiểm tra lộ trình và phản hồi trước khi hết giờ.';
  static const incomingOfferAccept = 'Nhận đơn';
  static const incomingOfferTransfer = 'Chuyển đơn';
  static const incomingOfferAcceptSuccess = 'Đã nhận đơn hàng.';
  static const incomingOfferTransferSuccess = 'Đã chuyển đơn cho tài xế khác.';
  static const incomingOfferActionError =
      'Không thể xử lý đơn lúc này. Vui lòng thử lại.';

  static String incomingOfferSemantic(String orderCode) =>
      'Có đơn hàng mới $orderCode cần phản hồi';

  static String offerCountdownSemantic(int seconds) =>
      'Còn $seconds giây để nhận đơn. Hết giờ hệ thống tự chuyển tài xế khác.';
}
