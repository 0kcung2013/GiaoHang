class CustomerWalletPinMessages {
  static const required = 'Vui lòng thiết lập mã PIN thanh toán.';
  static const format = 'Mã PIN phải gồm đúng 6 chữ số.';
  static const verificationRequired =
      'Vui lòng lấy mã email mới để khôi phục PIN.';
  static const retry = 'Chưa xác nhận được mã PIN. Vui lòng thử lại.';
  static const invalidResponse = 'Phản hồi bảo mật không hợp lệ.';
  static const invalidIdentity = 'Không xác minh được email của tài khoản.';
  static String invalid(int remaining) =>
      'Mã PIN chưa đúng. Bạn còn $remaining lần thử.';
  static String locked(int minutes) =>
      'Thanh toán Ví tạm khóa. Thử lại sau khoảng $minutes phút hoặc khôi phục mã PIN.';
}
