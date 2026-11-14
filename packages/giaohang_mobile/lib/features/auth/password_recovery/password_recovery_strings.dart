class PasswordRecoveryStrings {
  static const back = 'Quay lại';
  static const title = 'Quên mật khẩu';
  static const emailHint = 'Nhận mã xác minh qua email đã đăng ký.';
  static const codeTitle = 'Kiểm tra email';
  static const codeHint = 'Nhập mã xác minh để đặt lại mật khẩu.';
  static const passwordTitle = 'Mật khẩu mới';
  static const passwordHint = 'Chọn mật khẩu mới để bảo vệ tài khoản.';
  static const successTitle = 'Đã đổi mật khẩu';
  static const successHint = 'Đăng nhập bằng mật khẩu mới của bạn.';
  static const email = 'Email đăng ký';
  static const emailPlaceholder = 'ban@example.com';
  static const code = 'Mã OTP';
  static const codePlaceholder = 'Nhập 6 chữ số';
  static const newPassword = 'Mật khẩu mới';
  static const confirmPassword = 'Nhập lại mật khẩu';
  static const minimumPassword = 'Tối thiểu 6 ký tự';
  static const send = 'Gửi mã xác minh';
  static const sending = 'Đang gửi mã…';
  static const verify = 'Xác minh mã';
  static const verifying = 'Đang xác minh…';
  static const save = 'Lưu mật khẩu mới';
  static const saving = 'Đang lưu mật khẩu…';
  static const login = 'Về đăng nhập';
  static const resend = 'Gửi lại mã';
  static const changeEmail = 'Đổi email';
  static const deliveryNotice =
      'Nếu email đã đăng ký, bạn sẽ nhận được mã xác minh. Kiểm tra cả mục thư rác.';
  static const securityNote = 'Không chia sẻ mã xác minh với bất kỳ ai.';
  static const verified = 'Email đã xác minh';
  static const missingEmail = 'Vui lòng nhập email đã đăng ký.';
  static const invalidEmail = 'Email không hợp lệ.';
  static const invalidCode = 'Vui lòng nhập đủ 6 chữ số.';
  static const invalidPassword = 'Mật khẩu phải có ít nhất 6 ký tự.';
  static const mismatch = 'Mật khẩu nhập lại chưa khớp.';
  static const codeExpired =
      'Mã không đúng hoặc đã hết hạn. Vui lòng thử lại hoặc gửi mã mới.';
  static const sessionExpired =
      'Phiên xác minh đã hết hạn. Vui lòng nhận mã mới.';
  static const sendFailed =
      'Chưa gửi được mã. Vui lòng kiểm tra kết nối và thử lại.';
  static const verifyFailed = 'Chưa xác minh được mã. Vui lòng thử lại.';
  static const saveFailed =
      'Chưa lưu được mật khẩu. Vui lòng kiểm tra kết nối và thử lại.';
  static const rateLimited =
      'Bạn thao tác quá nhanh. Vui lòng chờ trước khi thử lại.';
  static const samePassword = 'Mật khẩu mới cần khác mật khẩu hiện tại.';
  static const weakPassword =
      'Mật khẩu chưa đáp ứng yêu cầu bảo mật. Hãy dùng mật khẩu dài hơn, gồm chữ hoa, chữ thường, số và ký tự đặc biệt.';
  static const accountUnavailable =
      'Chưa thể khôi phục tài khoản này. Vui lòng liên hệ CSKH.';
  static const supportSubject = 'Hỗ trợ khôi phục mật khẩu GiaoHang';
  static const supportBody =
      'Chào CSKH, tôi cần hỗ trợ khôi phục mật khẩu.\nEmail đăng nhập của tôi: ';
  static const emailStep = 'Email';
  static const codeStep = 'Xác minh';
  static const passwordStep = 'Mật khẩu';
  static String resendIn(int seconds) => 'Gửi lại mã sau ${seconds}s';
  static String progress(int current) => 'Bước $current trên 3';
}
