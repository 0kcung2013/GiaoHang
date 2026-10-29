# Administrator — quản trị hệ thống

Cập nhật ngày 2026-10-21. Phạm vi: `apps/operations_web`.

## Phân vai

CSKH quyết định xử lý sự cố, xác minh và kết luận, không dùng mức độ rủi ro hoặc
chuyển cấp Admin theo mức độ. CSKH có thể vô hiệu hóa Customer/Driver khi có căn cứ.
Admin tập trung phê duyệt tài xế và giám sát quyết định tài khoản; được điều chỉnh
thời hạn hoặc gỡ vô hiệu hóa, có lý do và lịch sử riêng.

- Ba mục chính: Tổng quan, Phê duyệt tài xế, Người dùng. Tài khoản quản trị ở chân sidebar.
- Bỏ Quyết định rủi ro, CSKH chuyển cấp và chuông yêu cầu chuyển cấp khỏi Admin.
- Nhóm Tra cứu vận hành thu gọn: đơn hàng, sự cố giám sát, hành trình, giao dịch.
- Dashboard đặt KYC, thay đổi hồ sơ, tài khoản vô hiệu hóa trước số liệu hệ thống.
  Chỉ số tài khoản mở đúng danh sách đã lọc. Công cụ tra cứu không trở thành bước
  bắt buộc chờ Admin.

## Giao diện và điều hướng

Dùng skill `giaohang-flutter-ui`, DESIGN.md và token Plus Jakarta Sans/navy/cam
trong package chung. Sidebar trên desktop, drawer trên màn hình hẹp. Tìm chức năng
và mã đơn qua Ctrl/Cmd+K. Module khởi tạo khi truy cập, giữ bộ lọc/draft trong phiên.
Không sao chép logic CSKH hay model sang app khác.

- `/admin-home?section=overview|drivers|accounts|orders|monitoring|journeys|transactions|settings`
- `/admin-home?section=accounts&view=disabled`
- `/admin-home?section=accounts&q=<user-id>`
- `/admin-home?section=drivers&view=changes`
- `/admin-ticket/:id`, `/admin-case/:id`: giữ link hồ sơ cũ, hiển thị trong khung Admin.
- `section=risks|tickets` cũ quay về Tổng quan, không dựng lại tab đã bỏ.
- `/support-accounts`: khu vực tài khoản CSKH; Admin được chuyển về đúng danh bạ Admin.

Danh bạ và nhật ký dùng chung feature `account_controls`. CSKH chỉ đọc Customer/Driver;
Admin đọc danh bạ cả staff nhưng không thể vô hiệu hóa staff qua API này. Tìm kiếm,
lọc và phân trang trên server. Từ hồ sơ có liên kết tài khoản, giữ mã hồ sơ để audit.
Lệnh dùng request ID chống lặp, expected event ID chống ghi đè. Khi lỗi mạng chưa rõ
kết quả, giữ nguyên payload để thử lại. Các quyền đều được backend kiểm tra.

## Dữ liệu

- Số tài xế/khách/KYC dùng RPC Admin hiện có; các số đơn/thay đổi dùng HEAD/count.
  Số tài khoản vô hiệu hóa dùng `disabled_account_count`. Nguồn lỗi hiện `—`.
- Màn tổng quan không tải danh sách đơn. Danh sách đơn chỉ lấy projection nhẹ,
  chi tiết mới đọc liên hệ và ảnh. KYC giữ quy trình duyệt/từ chối hiện có.
- Các bản SQL Admin, tra cứu giao dịch và đọc ảnh đã được duyệt/applied riêng.
- Hai migration tài khoản và đơn giản hóa sự cố đã được duyệt/applied ngày 2026-10-21:
  `20261021153600_account_controls`, `20261021153619_incident_controls_simplification`.
  Chi tiết và kết quả xác minh: [account_controls_proposal.md](account_controls_proposal.md).
- Chưa có API kiểm chứng cho đổi role, sửa giá/phân công, cộng trừ ví hoặc duyệt
  chi tiền thủ công; không dựng nút giả cho những nghiệp vụ này.
- API danh sách tài xế chưa trả rating_count; không suy điểm mặc định thành đánh giá thật.

## Kiểm chứng

Đã chạy kiểm thử tập trung cho account repository/controller/dialog, workspace và
repository Admin, policy/danh sách/chi tiết/bằng chứng sự cố, workspace CSKH và form
chuyển yêu cầu thành sự cố. SQL cô lập: 42 kiểm tra tài khoản + 15 kiểm tra sự cố đạt.
Kiểm tra live chỉ đọc xác nhận phân quyền và cấu hình; không khóa tài khoản thật.

Analyze tập trung các feature/file vừa sửa không có lỗi. Render bằng font thật ở
1440×900 và 320×568/chữ 160% dùng fixture, đã xem các ảnh:
`output/account-controls-overview-desktop.png`, `output/account-controls-accounts-desktop.png`,
`output/account-controls-overview-narrow.png`, `output/account-controls-accounts-narrow.png`.
Đã xem thêm `output/account-controls-history-desktop.png`: lịch sử có người quyết
định, vai trò, lý do, thời hạn và hai thao tác điều chỉnh/gỡ của Admin.
Không chạy toàn bộ monorepo, build phát hành hoặc thao tác khóa thật trên trình duyệt.
