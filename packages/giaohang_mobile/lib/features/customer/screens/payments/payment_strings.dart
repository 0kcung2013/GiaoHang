abstract final class PaymentStrings {
  static const title = 'Thống kê giao dịch';
  static const all = 'Tất cả';
  static const wallet = 'Ví khách hàng';
  static const vnpay = 'VNPay';
  static const successful = 'Thanh toán thành công';
  static const reserved = 'Đang giữ trong ví';
  static const pending = 'Chờ thanh toán';
  static const refundPending = 'Chờ hoàn tiền';
  static const refunded = 'Đã hoàn tiền';
  static const failed = 'Không thành công';
  static const expired = 'Đã hết hạn';
  static const reversed = 'Đã đảo giao dịch';
  static const unknown = 'Cần đối soát';
  static const trend = 'Thanh toán theo thời gian';
  static const byMethod = 'Theo phương thức';
  static const transactions = 'Giao dịch trong kỳ';
  static const createdDate = 'Theo ngày tạo giao dịch';
  static const explanation = 'Cách tính thống kê';
  static const calculation =
      'Tổng thành công gồm VNPay đã thanh toán và phí ví đã quyết toán. '
      'Tiền đang giữ, chờ thanh toán, chờ hoàn và đã hoàn được hiển thị riêng. '
      'Kỳ thống kê theo ngày tạo giao dịch (giờ Việt Nam), dùng trạng thái hiện tại. '
      'Khoản hoàn thuộc kỳ của giao dịch gốc; đây không phải số tiền hoàn phát sinh trong kỳ. '
      'Mỗi lần thanh toán là một giao dịch; một đơn có thể có nhiều lần thanh toán. '
      'Tiền COD nhận về ví và phí trả bằng tiền mặt không nằm trong thống kê này.';
  static const empty = 'Chưa có giao dịch';
  static const emptyHint = 'Chọn kỳ hoặc phương thức khác để xem thanh toán.';
  static const loadError = 'Chưa tải được thống kê';
  static const loadHint = 'Kiểm tra kết nối và thử lại nhé.';
  static const loading = 'Đang tải thống kê';
  static const retry = 'Thử lại';
  static const close = 'Đóng';
  static const reference = 'Mã giao dịch';
  static const order = 'Mã đơn hàng';
  static const createdAt = 'Thời gian tạo';
  static const status = 'Trạng thái';
  static const method = 'Phương thức';
  static const pickDate = 'Chọn ngày thống kê';
  static const choose = 'Chọn';
  static const cancel = 'Hủy';
  static const previous = 'Kỳ trước';
  static const next = 'Kỳ sau';
  static const day = 'Ngày';
  static const week = 'Tuần';
  static const month = 'Tháng';
  static const noSuccessful = 'Chưa có thanh toán thành công trong kỳ.';
  static String count(int value) => '$value giao dịch';
  static String successfulCount(int value) => '$value giao dịch thành công';
  static String showAll(int value) => 'Xem thêm giao dịch · $value trong kỳ';
}
