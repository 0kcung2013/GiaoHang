import '../../../core/constants/customer_wallet_pin_messages.dart';

class CustomerWalletPinStrings {
  static const title = 'Mã PIN thanh toán';
  static const setup = 'Tạo mã PIN';
  static const change = 'Đổi mã PIN';
  static const recover = 'Khôi phục mã PIN';
  static const current = 'Mã PIN hiện tại';
  static const newPin = 'Mã PIN mới';
  static const confirmPin = 'Nhập lại mã PIN mới';
  static const pin = 'Nhập mã PIN 6 số';
  static const format = CustomerWalletPinMessages.format;
  static const mismatch = 'Hai mã PIN chưa khớp.';
  static const forgot = 'Quên mã?';
  static const cancel = 'Hủy';
  static const save = 'Lưu mã PIN';
  static const saved = 'Đã lưu mã PIN thanh toán.';
  static const confirmPayment = 'Xác nhận thanh toán';
  static const amount = 'Thanh toán từ Ví';
  static const remaining = 'Số dư sau thanh toán';
  static const retry =
      'Chưa thực hiện được. Vui lòng kiểm tra kết nối và thử lại.';
  static const configured = 'Đã thiết lập · Yêu cầu khi trả phí bằng Ví';
  static const unconfigured = 'Chưa thiết lập · Tạo mã trước khi thanh toán';
  static const loadError = 'Chưa tải được thông tin mã PIN.';
  static const reload = 'Tải lại';
  static const sendCode = 'Gửi mã qua email';
  static const resend = 'Gửi lại mã';
  static const emailCode = 'Mã xác minh trong email';
  static const emailUnavailable =
      'Tài khoản cần email đã xác thực để khôi phục mã PIN. Vui lòng liên hệ CSKH.';
  static const recoveryHint = 'Nhận mã qua email đã xác thực để đặt PIN mới.';
  static const codeSent = 'Đã gửi mã. Kiểm tra hộp thư và thư rác.';
  static const invalidCode = 'Mã email không đúng hoặc đã hết hạn.';
  static const emailSendError =
      'Chưa gửi được email. Vui lòng thử lại hoặc liên hệ CSKH.';
  static const recoveryExpired =
      'Xác minh đã hết hạn. Vui lòng gửi mã email mới.';
  static const support = 'Liên hệ CSKH';
  static const sixDigits = '6 chữ số';
  static String lockMinutes(int minutes) =>
      'Ví tạm khóa · Thử lại sau khoảng $minutes phút';
  static String resendSeconds(int seconds) => 'Gửi lại sau ${seconds}s';
}
