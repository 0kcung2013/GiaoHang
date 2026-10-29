# Tài khoản khách hàng và hồ sơ Admin/CSKH

Triển khai trên cấu trúc dữ liệu hiện có. Không tạo bảng, cột, RPC, policy,
migration, Edge Function hoặc Worker trong đợt thay đổi này.

## Khách hàng

- Tab Tài khoản hiển thị hồ sơ thật, trạng thái tải/lỗi và cho phép tải lại.
- Chỉnh sửa tên, số điện thoại liên hệ và avatar. Kiểm tra dữ liệu trước khi
  gửi, chặn gửi lặp, giữ bản nháp khi lỗi và hỏi trước khi bỏ thay đổi chưa lưu.
  Số điện thoại ở đây là liên hệ, không phải thay đổi định danh Auth.
- Avatar dùng luồng R2 private hiện có; lưu tham chiếu ổn định vào avatar_url.
  Không lưu presigned URL hoặc thêm kho ảnh mới.
- Sổ địa chỉ dùng saved_addresses và dịch vụ đặt địa chỉ mặc định hiện có.
  Giao diện thêm/sửa dùng chung bộ chọn bản đồ của màn đặt đơn.
- Lịch sử đơn mở luồng đơn hàng hiện có ở chế độ lịch sử.
- Yêu cầu hỗ trợ có nhóm đang xử lý/đã kết thúc, phân trang, thử lại và mở
  hội thoại hiện có. Nút Liên hệ CSKH mở thẳng chat cho khách đã đăng nhập.
- Chi tiết giao dịch ví có liên hệ CSKH kèm mã giao dịch bất biến trong yêu
  cầu đầu tiên; hội thoại tài khoản chung không mở nhầm yêu cầu giao dịch.
- Cài đặt hiển thị phương thức đăng nhập, quyền vị trí và hộp thư thông báo
  thật. Không thêm công tắc chỉ thay đổi giao diện mà không lưu được dữ liệu.
- Khi đăng nhập báo tài khoản bị vô hiệu hóa, hiển thị Liên hệ CSKH tới
  cskh@gmail.com theo thông tin người dùng cung cấp. Nút mở trình soạn email,
  có địa chỉ chọn được và sao chép khi thiết bị chưa cấu hình ứng dụng email.
  Chưa gửi email tự động và không cần phiên đăng nhập để dùng liên hệ này.

users chỉ được cập nhật full_name, phone và avatar_url của chính khách hàng.
Email, vai trò, số dư, trạng thái tài khoản và liên hệ của đơn đã đặt giữ theo
luồng nghiệp vụ hiện có. Tải lại provider hồ sơ chung sau khi lưu thành công.

## Admin/CSKH

Từ danh sách Người dùng, mở khách hàng để xem hồ sơ gồm Tổng quan, Đơn hàng,
Giao dịch và Hỗ trợ. Mỗi mục chỉ truy vấn khi mở lần đầu, giữ dữ liệu khi đổi
mục và hỗ trợ tải lại/phân trang.

- Tổng quan hiển thị liên hệ, trạng thái và số đơn đang xử lý.
- Đơn hàng và yêu cầu hỗ trợ truy vấn đúng customer_id/requester_id; mở tiếp
  chi tiết đơn hoặc workspace hỗ trợ theo vai trò hiện tại.
- Giao dịch dùng list_support_transactions hiện có. Kết quả tìm kiếm được
  lọc lại theo đúng user_id, đồng thời giữ cursor thô của server để phân trang.
  Phạm vi dữ liệu theo nguồn nạp/thanh toán/hoàn mà API này đang hỗ trợ.
- Quản lý và lịch sử quyết định mở luồng account controls hiện có. Không
  thêm quyền cho CSKH hoặc cập nhật trực tiếp trạng thái Auth từ Flutter.

## Phần chưa triển khai

- Email CSKH ngoài phiên đăng nhập không tự tạo hội thoại trong app. Tài khoản
  bị vô hiệu hóa không dùng chat nội bộ vì phiên đã thu hồi; không nới quyền
  truy cập hội thoại hoặc bỏ qua trạng thái tài khoản để mở chat.
- Đổi email/mật khẩu, đóng tài khoản và rút tiền thật cần luồng nghiệp vụ riêng.
  Tính năng rút tiền demo hiện có vẫn giữ nhãn demo.
- Cột tùy chọn thông báo/thanh toán hiện có chưa có quyền ghi self-service phù
  hợp, nên đợt này không thêm thao tác ghi hoặc đề xuất schema mới chỉ cho UI.

## Kiểm chứng

- 22 kiểm thử mobile đạt trong customer_account_repository_test,
  customer_account_ui_test, customer_support_inbox_ui_test và
  general_support_chat_test: giới hạn trường ghi/chủ sở hữu, validation, lỗi,
  chống gửi lặp, giữ bản nháp, điều hướng, phân trang và ngữ cảnh giao dịch.
- Các kiểm thử customer_wallet_ui, address_picker_ui,
  customer_home_navigation và help_center liên quan đã đạt.
- 6 kiểm thử customer_dossier_test và customer_dossier_repository_test đạt:
  tải từng mục, đúng chủ sở hữu giao dịch, quyền quyết định, phân trang và
  màn hẹp có chữ lớn. Các kiểm thử account_controls và
  account_control_repository hiện có cũng đã đạt.
- 11 kiểm thử account_support_contact_test, login_experiment_view_test và
  login_experiment_render_test đạt: mở đúng mailto/encoding, lỗi trình mở email,
  sao chép, chống nhấn lặp và đăng nhập bị vô hiệu hóa trên màn 320x568 có
  bàn phím/chữ 160%. Luồng đăng nhập thông thường vẫn qua các kiểm tra hiện có.
- Analyze tập trung trên các phần Dart thay đổi và test liên quan không có lỗi.
- Đã render và xem ảnh widget thực tế ở mobile 390x844, 320x568/chữ 160%,
  khung điện thoại trên viewport 1280x800 và hồ sơ Operations 1440x900,
  390x640/chữ 160%. Form được kiểm tra với bàn phím thu hẹp chiều cao.
- Chưa chạy bản phát hành, toàn bộ test suite hoặc thao tác ghi vào hồ sơ
  khách hàng thật. Render widget không thay thế kiểm tra tương tác trên trình
  duyệt/thiết bị thật, đặc biệt với bộ chọn ảnh và quyền hệ điều hành.
