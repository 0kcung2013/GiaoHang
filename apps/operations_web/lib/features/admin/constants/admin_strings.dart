class AdminStrings {
  static const brand = 'GiaoHang';
  static const administrator = 'ADMINISTRATOR';
  static const workspace = 'Không gian quản trị';
  static const menu = 'Mở điều hướng';
  static const refresh = 'Làm mới';
  static const retry = 'Thử lại';
  static const search = 'Tìm đơn hoặc chức năng…';
  static const searchHint = 'Nhập mã đơn hoặc tên chức năng';
  static const searchOrders = 'Tra cứu mã đơn';
  static const noResults = 'Không có kết quả phù hợp';
  static const overview = 'Tổng quan quản trị';
  static const overviewHint = 'Phê duyệt tài xế và quản trị tài khoản.';
  static const systemOverview = 'Toàn cảnh hệ thống';
  static const operationsLookup = 'Tra cứu vận hành';
  static const allTime = 'Toàn hệ thống · tất cả thời gian';
  static const decisions = 'Phê duyệt & tài khoản';
  static const decisionsHint = 'KYC, thay đổi hồ sơ và quyết định vô hiệu hóa.';
  static const recent = 'Đơn hàng gần đây';
  static const seeAll = 'Xem tất cả';
  static const loadError =
      'Chưa tải được dữ liệu. Kiểm tra kết nối và thử lại.';
  static const partialError =
      'Một số nguồn dữ liệu chưa tải được. Dấu — là chưa xác định.';
  static const emptyOrders = 'Chưa có đơn hàng phù hợp';
  static const orderSearch = 'Tìm theo mã đơn';
  static const ordersTitle = 'Quản lý đơn hàng';
  static const ordersHint =
      'Tra cứu toàn bộ đơn, đối chiếu thanh toán và bằng chứng giao nhận.';
  static const usersTitle = 'Người dùng';
  static const driversTitle = 'Tài xế & KYC';
  static const driverSearch = 'Tên, email hoặc biển số';
  static const closeProfile = 'Đóng hồ sơ';
  static const userId = 'ID';
  static const all = 'Tất cả';
  static const details = 'Xem chi tiết';
  static const next = 'Trang tiếp';
  static const previous = 'Trang trước';
  static const orderCode = 'Mã đơn';
  static const route = 'Lấy → giao';
  static const status = 'Trạng thái';
  static const amount = 'Tổng tiền';
  static const created = 'Ngày tạo';
  static const driversHint =
      'Duyệt KYC, kiểm tra phương tiện và hồ sơ thay đổi.';
  static const usersSearch = 'Tên, email hoặc số điện thoại';
  static const usersEmpty = 'Không tìm thấy người dùng';
  static const usersReadOnly = 'Thông tin tài khoản và liên hệ';
  static const account = 'Tài khoản';
  static const roleLabelAdmin = 'Quản trị viên hệ thống';
  static const role = 'Vai trò';
  static const email = 'Email';
  static const phone = 'Số điện thoại';
  static const name = 'Họ và tên';
  static const missing = 'Chưa cung cấp';
  static const close = 'Đóng';
  static const signOut = 'Đăng xuất';
  static const signOutConfirm = 'Đăng xuất tài khoản quản trị?';
  static const signOutError = 'Không thể đăng xuất. Vui lòng thử lại.';
  static const cancel = 'Ở lại';
  static const permissions = 'Phạm vi quản trị';
  static const permissionsHint =
      'Phê duyệt tài xế; giám sát quyết định tài khoản.';
  static const financeScope =
      'Tra cứu giao dịch, trạng thái thanh toán và yêu cầu đối soát.';
  static const accountScope =
      'Xem lịch sử vô hiệu hóa, điều chỉnh thời hạn hoặc gỡ quyết định.';
  static String page(int value) => 'Trang $value';
  static String completedCount(int value) => '$value đơn';
  static String approvalLabel(String value) => switch (value) {
    'approved' => 'Đã duyệt',
    'rejected' => 'Từ chối',
    _ => 'Chờ duyệt',
  };
  static String updated(String value) => 'Cập nhật $value';
  static String count(int value) => '$value hồ sơ';
  static String roleLabel(String value) => switch (value) {
    'admin' => 'Quản trị viên',
    'support' => 'CSKH',
    'driver' => 'Tài xế',
    'customer' => 'Khách hàng',
    _ => value,
  };
}
