# Kiểm tra Supabase sau khi kết nối lại — 2026-10-21

Dự án DATN `erlpzwfbpjogvaulcxni`, trạng thái ACTIVE_HEALTHY. Các kiểm tra quyền
dùng transaction READ ONLY, đặt JWT claims và SET LOCAL ROLE theo tài khoản
hiện có; không tạo phiên đăng nhập, sửa đơn, số dư hoặc hồ sơ thật.

## Đã triển khai theo phê duyệt trước

- Migration `20261021142936_support_transactions_read_api.sql` đã áp dụng qua MCP.
- Regression tra cứu giao dịch và quyền đọc ảnh lấy/giao/hoàn đều đạt trên dữ liệu
  thật, bao phủ Admin, Support, Customer, Driver và kiểm tra quyền anon.
- Ba nhóm có 17 lượt nạp, 15 lượt thanh toán, 24 lượt giải phóng/hoàn tiền tại
  thời điểm kiểm tra. Đây là số bản ghi theo nhóm, không phải tổng doanh thu.
- Hai policy đọc ảnh đã có từ migration `20261019101210`; không tạo lại.

## Vấn đề Admin xác nhận trên server

1. `users_select_own` chỉ trả hồ sơ đang đăng nhập, kể cả Admin. `drivers` cũng chỉ
   có policy đọc hồ sơ của tài xế. Vì vậy đếm trực tiếp từ client trả 0 khách/0
   tài xế, và danh bạ chỉ hiện một Admin, dù thực tế có 2 khách, 4 tài xế, 8 tài
   khoản. Mã Flutter đã chuyển ba số đếm bị ảnh hưởng sang `admin_dashboard_stats`
   hiện có. Danh bạ chuyển sang RPC chỉ đọc `list_admin_accounts` đã triển khai;
   nếu môi trường chưa có RPC thì hiện lỗi, không báo danh bạ đã đầy đủ.
2. `admin_dashboard_stats` được anon EXECUTE; điều kiện `v_role != 'admin'` không
   chặn NULL. Đã tái hiện bằng role anon/không có sub: nhận được thống kê hệ thống.
   Hai API danh sách Admin dùng cùng mẫu kiểm tra NULL; `admin_list_drivers` đã
   thu hồi anon nhưng vẫn cần chặn authenticated không có hồ sơ hợp lệ.
3. Các số đếm đơn, hồ sơ thay đổi, rủi ro và yêu cầu không sai khác do RLS trong
   snapshot kiểm tra; không kết luận thao tác ghi đã được kiểm thử.

SQL đã được duyệt riêng và áp dụng ngày 2026-10-21:
[20261021143625_admin_read_access.sql](../supabase/migrations/20261021143625_admin_read_access.sql).
Bản sửa giữ nguyên hợp đồng ba RPC Admin cũ, thay kiểm tra bằng `NOT EXISTS`
đối với hồ sơ Admin, thu hồi PUBLIC/anon; thêm danh bạ có phân trang/lọc/tìm
theo tên, email, điện thoại. Public wrapper SECURITY INVOKER, private function
STABLE/SECURITY DEFINER kiểm tra role thật trong users, search_path rỗng.
Không đổi bảng/cột/RLS, không cấp đọc trực tiếp users/drivers đại trà, không
thêm quyền quyết định hoặc ghi tài chính.

`tool/admin_read_access_test.mjs` đạt 46 kiểm tra trong PostgreSQL/PGlite cô lập:
anon, thiếu hồ sơ, ba role ngoài Admin, quyền đọc đúng, lọc, tìm literal, phân
trang với ngày trùng nhau, validation và giữ RLS của users.

`supabase/tests/admin_read_access_regression.sql` đã đạt trên dự án thật sau
khi áp dụng. Admin đọc đủ 8 tài khoản, số thống kê khớp bảng gốc, danh sách
tài xế/đơn giữ kết quả cũ; Customer/Driver/Support, thiếu sub hoặc không có hồ
sơ bị từ chối. Anon không có EXECUTE. RLS users vẫn chỉ trả hồ sơ bản thân.
12 kiểm thử Flutter repository/workspace Admin đạt, bao gồm trường hợp API
thống kê lỗi thì số đếm chưa xác định giữ NULL. Analyze hai file vừa sửa đạt.
Chưa kiểm tra end-to-end hoặc thao tác ghi bằng phiên trình duyệt.

Tham khảo cảnh báo quyền hàm của Supabase:
[anon SECURITY DEFINER](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable).
Không tự sửa các cảnh báo extension/PostGIS hoặc hàm khác ngoài phạm vi này.
Đã chạy lại security advisors sau hai migration; không có cảnh báo cho hai
API mới `list_admin_accounts` và `list_support_transactions`.

## Đánh giá

**Cập nhật 2026-10-24:** phần mô tả dưới đây là snapshot ngày 2026-10-21.
Người dùng đã duyệt và migration review_reliability đã được áp dụng; xem
[biên bản kiểm tra sau triển khai](review_reliability.md#kiểm-tra-sau-triển-khai-ngày-2026-10-24).

Hai RPC đánh giá đang deploy đúng bản cũ lấy trung bình đã làm tròn để cộng dồn.
Bản sửa [review_reliability.sql](proposals/review_reliability.sql) vẫn chờ duyệt
riêng; kết nối lại không thay thế phê duyệt. Chưa áp dụng đối soát điểm, chưa
định nghĩa ngưỡng sao thành điểm chờ xác minh.

`admin_list_drivers` hiện trả rating nhưng chưa trả rating_count, nên bảng mới
chưa đủ dữ liệu để phân biệt tài xế chưa có đánh giá với điểm mặc định. Không
suy diễn điểm mặc định thành đánh giá thật hoặc mở quyền đọc đánh giá riêng tư.
