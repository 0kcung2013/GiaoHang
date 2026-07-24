/// Dữ liệu đã nhập từ màn Đăng ký chung → truyền sang wizard TX.
class DriverRegisterPrefill {
  const DriverRegisterPrefill({
    this.email = '',
    this.password = '',
    this.fullName = '',
    this.phone = '',
  });

  final String email;
  final String password;
  final String fullName;
  final String phone;

  bool get hasAccount =>
      email.trim().contains('@') && password.trim().length >= 6;
}
