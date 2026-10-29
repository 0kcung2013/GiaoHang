class AccountStrings {
  static const title = 'Người dùng';
  static const supportHint = 'Tra cứu và vô hiệu hóa tài khoản khi có vi phạm.';
  static const adminHint = 'Xem, điều chỉnh và gỡ quyết định vô hiệu hóa.';
  static const search = 'Tên, email, số điện thoại hoặc ID';
  static const all = 'Tất cả';
  static const disabledOnly = 'Đang vô hiệu hóa';
  static const enabled = 'Đang hoạt động';
  static const permanent = 'Vĩnh viễn';
  static const history = 'Lịch sử quyết định';
  static const manage = 'Quản lý tài khoản';
  static const viewIncident = 'Xem sự cố';
  static const viewTicket = 'Xem yêu cầu hỗ trợ';
  static const empty = 'Không tìm thấy người dùng';
  static const historyEmpty = 'Chưa có quyết định vô hiệu hóa';
  static const refresh = 'Làm mới';
  static const retry = 'Thử lại';
  static const retryCommand = 'Kiểm tra và gửi lại';
  static const close = 'Đóng';
  static const reason = 'Lý do quyết định';
  static const reasonHint = 'Ghi rõ vấn đề và căn cứ xử lý (10–1000 ký tự).';
  static const duration = 'Thời hạn';
  static const confirmation =
      'Tài khoản sẽ bị đăng xuất và không thể truy cập trong thời hạn đã chọn.';
  static const releaseHint = 'Tài khoản có thể đăng nhập lại sau khi gỡ.';
  static const completed = 'Đã lưu quyết định tài khoản';
  static const error = 'Chưa tải được dữ liệu. Vui lòng thử lại.';
  static const uncertain =
      'Chưa xác nhận được kết quả. Gửi lại cùng quyết định để kiểm tra, tránh ghi lặp.';
  static const changed =
      'Tài khoản đã được cập nhật. Đóng và làm mới trước khi quyết định.';
  static const denied = 'Bạn không có quyền thực hiện quyết định này.';
  static const invalid =
      'Quyết định không còn phù hợp. Đóng và tải lại tài khoản.';
  static const previous = 'Trang trước';
  static const next = 'Trang tiếp';
  static const more = 'Xem thêm';
  static const missing = 'Chưa cung cấp';
  static const staffReadOnly = 'Tài khoản nhân viên · chỉ xem';
  static const historyContext = 'Hồ sơ liên quan';
  static const durations = <int?, String>{
    30: '30 phút',
    60: '1 giờ',
    1440: '1 ngày',
    4320: '3 ngày',
    10080: '7 ngày',
    43200: '30 ngày',
    null: permanent,
  };
  static String role(String value) => switch (value) {
    'customer' => 'Khách hàng',
    'driver' => 'Tài xế',
    'support' => 'CSKH',
    'admin' => 'Quản trị viên',
    _ => value,
  };
  static String action(String value) => switch (value) {
    'disable' => 'Vô hiệu hóa',
    'adjust' => 'Điều chỉnh thời hạn',
    'release' => 'Gỡ vô hiệu hóa',
    _ => value,
  };
  static String activeOrders(int count) => '$count đơn đang xử lý';
  static String page(int value) => 'Trang $value';
}
