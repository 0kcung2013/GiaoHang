abstract final class DriverAuthStrings {
  static const brand = 'GIAO HÀNG';
  static const driver = 'Tài xế';
  static const loginTitle = 'Đăng nhập tài xế';
  static const registerTitle = 'Đăng ký tài xế';
  static const login = 'Đăng nhập';
  static const loggingIn = 'Đang đăng nhập…';
  static const noAccount = 'Chưa có tài khoản?';
  static const register = 'Đăng ký tài xế';
  static const backToLogin = 'Về đăng nhập';
  static const email = 'Email';
  static const emailHint = 'ban@example.com';
  static const password = 'Mật khẩu';
  static const passwordHint = 'Nhập mật khẩu';
  static const passwordHelp = 'Tối thiểu 6 ký tự';
  static const showPassword = 'Hiện mật khẩu';
  static const hidePassword = 'Ẩn mật khẩu';
  static const missingEmail = 'Vui lòng nhập email';
  static const missingPassword = 'Vui lòng nhập mật khẩu';
  static const invalidCredentials = 'Email hoặc mật khẩu không chính xác.';
  static const loginFailed = 'Đăng nhập thất bại';
  static const connectionError = 'Lỗi kết nối. Vui lòng thử lại.';
  static const next = 'Tiếp tục';
  static const back = 'Quay lại';
  static const submit = 'Gửi hồ sơ duyệt';
  static const submitting = 'Đang gửi hồ sơ…';
  static const stepTitles = [
    'Tài khoản',
    'Cá nhân',
    'Phương tiện',
    'Giấy tờ',
    'Xác nhận',
  ];
  static const stepHeadings = [
    'Tạo tài khoản',
    'Thông tin cá nhân',
    'Xe giao hàng',
    'Giấy tờ xác minh',
    'Kiểm tra hồ sơ',
  ];
  static const stepHints = [
    'Dùng email để đăng nhập sau khi đăng ký.',
    'Thông tin cá nhân và ảnh chân dung của bạn.',
    'Khách hàng sẽ thấy thông tin phương tiện này.',
    'Ảnh rõ nét, đủ góc và đọc được thông tin.',
    'Kiểm tra thông tin trước khi gửi duyệt.',
  ];
  static const prefilledAccount = 'Đã dùng tài khoản';
  static const fullName = 'Họ và tên';
  static const fullNameHint = 'Họ tên theo CCCD';
  static const phone = 'Số điện thoại';
  static const phoneHint = 'Nhập số điện thoại';
  static const avatar = 'Ảnh đại diện';
  static const avatarHint = 'Ảnh chân dung rõ mặt';
  static const vehicleType = 'Loại xe';
  static const vehicleModel = 'Hãng / model xe';
  static const vehicleModelHint = 'Ví dụ: Honda Wave';
  static const vehicleColor = 'Màu xe';
  static const vehicleColorHint = 'Ví dụ: Đen';
  static const licensePlate = 'Biển số xe';
  static const licensePlateHint = 'Nhập biển số xe';
  static const idNumber = 'Số CCCD';
  static const idNumberHint = 'Nhập số CCCD';
  static const idFront = 'CCCD mặt trước';
  static const idBack = 'CCCD mặt sau';
  static const licenseNumber = 'Số giấy phép lái xe';
  static const licenseNumberHint = 'Nhập số GPLX';
  static const licensePhoto = 'Giấy phép lái xe';
  static const vehiclePhoto = 'Ảnh xe và biển số';
  static const vehiclePhotoHint = 'Chụp rõ xe và biển số';
  static const pickPhoto = 'Chọn ảnh';
  static const changePhoto = 'Đổi ảnh';
  static const selectedPhoto = 'Đã chọn ảnh';
  static const previewError = 'Không xem được ảnh. Chọn lại ảnh.';
  static const pickerError = 'Không mở được thư viện ảnh. Vui lòng thử lại.';
  static const privateDocuments = 'Giấy tờ chỉ dùng để xác minh hồ sơ tài xế.';
  static const personalSection = 'Thông tin cá nhân';
  static const vehicleSection = 'Phương tiện';
  static const documentsSection = 'Giấy tờ';
  static const reviewNotice =
      'Hồ sơ sẽ được Admin xét duyệt. Bạn có thể nhận đơn sau khi được duyệt.';
  static const invalidEmail = 'Email không hợp lệ';
  static const shortPassword = 'Mật khẩu tối thiểu 6 ký tự';
  static const missingName = 'Vui lòng nhập họ tên';
  static const invalidPhone = 'Số điện thoại không hợp lệ';
  static const missingAvatar = 'Vui lòng chọn ảnh đại diện';
  static const missingModel = 'Vui lòng nhập hãng / model xe';
  static const missingColor = 'Vui lòng nhập màu xe';
  static const missingPlate = 'Vui lòng nhập biển số';
  static const invalidId = 'Số CCCD không hợp lệ';
  static const missingIdPhotos = 'Cần ảnh CCCD mặt trước và mặt sau';
  static const missingLicenseNumber = 'Vui lòng nhập số GPLX';
  static const missingLicensePhoto = 'Cần ảnh giấy phép lái xe';
  static const missingVehiclePhoto = 'Cần ảnh xe (thấy rõ biển số)';
  static const registerFailed = 'Đăng ký thất bại';
  static const emailExists =
      'Email đã được đăng ký. Hãy quay lại trang đăng nhập.';

  static String step(int current, int total) => 'Bước $current/$total';
}
