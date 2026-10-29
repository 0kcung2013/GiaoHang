class SettingsStrings {
  static const newerVersion =
      'Cấu hình vừa được Admin khác cập nhật. Bản nháp của bạn được giữ lại. Tải bản mới trước khi tiếp tục lưu.';
  static const syncError =
      'Chưa đồng bộ được cấu hình mới. Hệ thống sẽ tự thử lại khi có kết nối.';
  static const title = 'Cấu hình hệ thống';
  static const editTab = 'Thiết lập';
  static const sections = 'Nhóm cấu hình';
  static const reviewTitle = 'Kiểm tra & lưu';
  static const editSection = 'Chỉnh sửa';
  static const reviewHint =
      'Lưu toàn bộ thay đổi trong các mục sau khi kiểm tra.';
  static const noChanges = 'Chưa có thay đổi';
  static const noChangesHint = 'Chọn một mục để điều chỉnh cấu hình.';
  static const reviewValidation = 'Cần kiểm tra lại';
  static String parameters(int count) => '$count thông số';
  static String pendingChanges(int count) => '$count thay đổi chưa lưu';
  static String sectionChanges(int count) => '$count thay đổi';
  static const historyTab = 'Lịch sử';
  static const subtitle = 'Chính sách kinh doanh và vận hành';
  static const loadError = 'Không tải được cấu hình. Vui lòng thử lại.';
  static const saveError =
      'Chưa lưu được cấu hình. Kiểm tra kết nối và thử lại.';
  static const conflict =
      'Admin khác đã cập nhật cấu hình. Bản nháp vẫn được giữ; hãy tải bản mới để đối chiếu.';
  static const reason = 'Lý do thay đổi';
  static const reasonError = 'Nhập lý do từ 5 đến 500 ký tự.';
  static const save = 'Lưu cấu hình';
  static const saving = 'Đang lưu…';
  static const saved =
      'Đã lưu. Cấu hình mới có hiệu lực cho các giao dịch mới.';
  static const reload = 'Tải bản mới';
  static const discard = 'Bỏ thay đổi';
  static const history = 'Lịch sử thay đổi';
  static const more = 'Xem thêm';
  static const historyError = 'Không tải được lịch sử. Thử lại để xem đầy đủ.';
  static const restore = 'Dùng làm bản nháp';
  static const restoreHint =
      'Đã nạp phiên bản cũ vào bản nháp. Kiểm tra và nhập lý do trước khi lưu.';
  static const changes = 'Thay đổi trước khi lưu';
  static const preview = 'Ví dụ giá cước';
  static const simulator = 'Tính thử phí giao';
  static const distance = 'Quãng đường cần tính';
  static const distanceError = 'Nhập quãng đường từ 0 đến 2.000 km.';
  static const pricingInvalid = 'Nhập giá cước hợp lệ để tính thử và so sánh.';
  static const baseFee = 'Phí cơ bản';
  static const includedOnly =
      'Quãng đường nằm trong phần phí cơ bản đã bao gồm.';
  static const rounding = 'Phần làm tròn lên';
  static const total = 'Tổng phí giao';
  static const comparison = 'So sánh giá trước khi lưu';
  static const oldPrice = 'Giá trước thay đổi';
  static const newPrice = 'Giá sau thay đổi';
  static const difference = 'Chênh lệch';
  static const unchanged = 'Không đổi';
  static const effectiveHint =
      'Chỉ áp dụng cho đơn mới. Đơn và phiên thanh toán đã chốt giữ giá cũ.';
  static const singleRate = 'Phí cơ bản + một giá/km vượt gói';
  static const legacyRate = 'Giá theo bậc khoảng cách (chính sách cũ)';
  static const restoreLegacyHint =
      'Đã nạp các mức giá chung từ phiên bản cũ vào bản nháp. Công thức hiện tại vẫn dùng một giá/km; kiểm tra bảng so sánh trước khi lưu.';
  static const unsaved = 'Có thay đổi chưa lưu';
  static const leave = 'Rời trang';
  static const stay = 'Tiếp tục chỉnh sửa';
  static const reloadWarning = 'Tải bản mới sẽ thay thế bản nháp hiện tại.';
}
