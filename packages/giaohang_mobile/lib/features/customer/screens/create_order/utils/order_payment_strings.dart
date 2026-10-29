abstract final class OrderPaymentText {
  static const paymentRefunded =
      'Khoản thanh toán đã hoàn vào ví. Bạn có thể tạo lại đơn.';
  static const paymentRefundPending = 'Giao dịch đang chờ đối soát hoàn tiền.';
  static const goods = 'Tiền hàng';
  static const collect = 'Thanh toán khi nhận hàng';
  static const noCollection = 'Tiền hàng đã thanh toán';
  static const hint = 'Tài xế không thu tiền khi giao.';
  static const amount = 'Tiền hàng';
  static const goodsValue = 'Giá trị hàng';
  static const depositHint = 'Dùng để giữ tiền làm tin của tài xế.';
  static const goodsValueRequired = 'Nhập giá trị hàng để giữ tiền làm tin.';
  static const goodsDeposit = 'Tiền làm tin của tài xế';
  static const required = 'Nhập số tiền thu hộ.';
  static const limit = 'Tối đa 2.000.000đ.';
  static const fee = 'Phí giao';
  static const payer = 'Người nhận trả khi giao';
  static const prepaidPayer = 'Trả phí giao bằng ví của bạn';
  static const total = 'Thu từ người nhận';
  static const walletBalance = 'Số dư ví';
  static const walletCharge = 'Trừ từ ví của bạn';
  static const walletRemaining = 'Số dư sau khi đặt';
  static const walletInsufficient = 'Ví không đủ tiền trả phí giao.';
  static const walletLoading = 'Đang kiểm tra số dư ví...';
  static const walletLoadError = 'Chưa tải được số dư ví.';
  static const walletReload = 'Tải lại';
  static const walletSubmit = 'Trả bằng ví và đặt đơn';
  static const walletRetry =
      'Chưa xác nhận được kết quả. Thử lại để kiểm tra cùng đơn.';
  static const walletTiming = 'Trừ phí giao khi bạn xác nhận đặt đơn.';
  static const vnpayAlternative = 'Chọn thanh toán qua VNPAY';
  static const vnpaySelected = 'Trả phí giao qua VNPAY';
  static const confirmOrder = 'Xác nhận đặt đơn';
  static const payAndCreate = 'Thanh toán phí giao và đặt đơn';
  static const reopenPayment = 'Mở thanh toán';
  static const awaitingPayment = 'Chờ xác nhận thanh toán';
  static const checkPayment = 'Kiểm tra thanh toán';
  static const checkingPayment = 'Đang kiểm tra...';
  static const paymentFailed = 'Thanh toán chưa thành công. Vui lòng thử lại.';
  static const paymentExpired =
      'Phiên thanh toán đã hết hạn. Vui lòng thử lại.';
  static const paymentUnavailable =
      'Không mở được thanh toán. Vui lòng thử lại.';
}
