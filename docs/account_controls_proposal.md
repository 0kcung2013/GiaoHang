# CSKH quyết định sự cố và vô hiệu hóa tài khoản — đề xuất triển khai

Người dùng đã duyệt riêng hai bản SQL ngày 2026-10-21 theo AGENTS.md:114.
Đã áp dụng lên DATN: `20261021153600_account_controls.sql` và
`20261021153619_incident_controls_simplification.sql`.

## Nghiệp vụ

- Bỏ mức độ rủi ro khỏi giao diện và khỏi điều kiện quyết định. CSKH nhận hồ sơ,
  xác minh, xử lý, ghi kết luận. Giữ điều kiện người phụ trách, bằng chứng và
  bàn giao/hoàn hàng. Admin bỏ mục Quyết định rủi ro và CSKH chuyển cấp.
- CSKH có thể vô hiệu hóa tài khoản Customer/Driver với lý do từ 10–1000 ký tự:
  30 phút, 1 giờ, 1 ngày, 3 ngày, 7 ngày, 30 ngày hoặc vĩnh viễn.
- Admin xem lịch sử, vô hiệu hóa, điều chỉnh thời hạn hoặc gỡ; thao tác điều
  chỉnh/gỡ cần lý do riêng. CSKH không ghi đè quyết định đang hiệu lực.
- Không áp dụng luồng này lên tài khoản Support/Admin. Không thay số dư, đơn,
  người giữ hàng, pipeline GPS/R2 hoặc khóa nhận đơn `acceptance_locked_until`.
- Mỗi lệnh có request ID chống gửi lặp và event ID kỳ vọng để chặn ghi đè một
  quyết định vừa được nhân viên khác thay đổi. Giờ server xác định hiệu lực.

## Vì sao cần một bảng nghiệp vụ mới

`users`/`drivers` không lưu lý do và chuỗi quyết định khóa/gỡ. `auth.users.banned_until`
chỉ giữ mốc hiệu lực hiện tại. `risk_report_events` thuộc vòng đời một sự cố;
một quyết định tài khoản có thể không thuộc đơn hoặc báo cáo nào và có nhiều
lần Admin điều chỉnh sau khi sự cố đã đóng. Ép những dữ liệu này vào ghi chú
hoặc metadata hiện tại sẽ mất ràng buộc, phân quyền và khả năng đối soát.

Chỉ đề xuất **một bảng `account_control_events` append-only**, liên kết users,
người xử lý và hồ sơ có liên quan nếu có. Mỗi lần sửa/gỡ thêm sự kiện mới, không
sửa lịch sử cũ. Không tạo bảng trạng thái hoặc storage/database bổ sung.

## SQL đã áp dụng

1. [account_controls.sql](proposals/account_controls.sql): bảng nhật ký, các RPC
   đọc/thao tác chỉ dành cho staff; Support chỉ tra cứu Customer/Driver, Admin
   đọc được danh bạ hiện có. RLS bảo vệ bảng mới và thêm điều kiện tài khoản
   còn hiệu lực vào 22 bảng nghiệp vụ, UPDATE users và storage.objects.
2. Đồng bộ `auth.users.banned_until` trong cùng transaction với nhật ký, thu hồi
   `auth.sessions` khi khóa/điều chỉnh, xóa neo phiên đang đăng nhập ở users để
   ứng dụng nhận tín hiệu đăng xuất hiện có. Tài khoản vĩnh viễn dùng cờ không
   có ngày hết hạn ở nhật ký; Auth dùng mốc 9999 để tương thích timestamp.
3. Đăng ký `public.require_enabled_account` làm PostgREST pre-request: chặn RPC
   SECURITY DEFINER và JWT trước khóa, kể cả sau khi hết hạn/gỡ nếu phiên đó đã
   bị thu hồi. Tài khoản cần đăng nhập mới sau khi được phép dùng lại. Trước
   thay đổi, project không cấu hình một pre-request hook khác.
4. [incident_controls_simplification.sql](proposals/incident_controls_simplification.sql):
   sửa bảy function hiện có, bỏ điều kiện critical/Admin và điều kiện low/medium
   trong luồng giao lại, giữ các điều kiện custody khác. Chuyển yêu cầu chờ Admin
   cũ sang tiếp tục xử lý CSKH; ngừng gửi thông báo chuyển cấp. Cột/enum lịch sử
   không bị xóa; bản ghi mới dùng giá trị trung tính để giữ hợp đồng cũ.

Không cần thay Edge Functions hoặc Worker: các endpoint hiện có xác minh qua
Auth `/user`; phiên đã thu hồi bị chặn, và R2 tiếp tục kiểm tra quyền database
bằng JWT người dùng. Các URL ảnh đã cấp trước đó vẫn chỉ tồn tại đến hạn cũ.
Tham chiếu triển khai xác thực: [Supabase Auth source](https://github.com/supabase/auth/blob/master/internal/api/auth.go).

## Kiểm tra trước triển khai

- `tool/account_controls_test.mjs`: 42 kiểm tra PostgreSQL/PGlite cô lập: quyền
  theo role, khóa có hạn/vĩnh viễn, chống lặp, chống ghi đè, nhật ký bất biến,
  thu hồi phiên, RLS dữ liệu/media, Admin gỡ/sửa và đăng nhập mới sau gỡ.
- `tool/incident_controls_test.mjs`: 15 kiểm tra: CSKH kết thúc hồ sơ cũ mọi mức,
  vẫn chặn sai người phụ trách/thiếu kết luận/custody; không chuyển Admin từ
  tham số cũ; giao lại không còn phụ thuộc mức độ nhưng giữ điều kiện người/đơn.
- Kiểm tra live chỉ đọc: hiện không có hồ sơ waiting_admin hoặc hồ sơ đang mở
  gắn Admin; không có khóa Auth đang hiệu lực trước rollout.
- Kiểm tra live sau triển khai: đủ 24 restrictive policies, RLS của nhật ký bật,
  không có quyền đọc bảng trực tiếp hoặc quyền anon gọi RPC. Pre-request đã đăng ký.
  Gọi API bằng ngữ cảnh CSKH trong transaction rollback trả đúng Customer/Driver.
  Không có nhật ký hoặc khóa Auth mới phát sinh; không khóa/gỡ tài khoản thật để thử.
- HTTP PostgREST cho `list_staff_accounts` và `disabled_account_count` với anon key
  trả 401/code 42501: schema cache nhận API mới, truy cập ẩn danh bị từ chối.
- Advisor ghi INFO “RLS Enabled No Policy” cho nhật ký: đây là chủ đích vì bảng
  không cấp quyền trực tiếp, chỉ đọc/ghi qua RPC kiểm tra vai trò. Không thêm policy
  mở bảng chỉ để tắt cảnh báo. [Tham chiếu linter](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy).

## Giao diện

- CSKH: tab Người dùng, tìm tên/email/điện thoại/ID, lọc vai trò/trạng thái,
  phân trang, xem lịch sử và đặt vô hiệu hóa. Tài khoản đã bị vô hiệu hóa chỉ xem.
- Admin: Tổng quan, Phê duyệt tài xế, Người dùng; bỏ hai mục quyết định rủi ro và
  CSKH chuyển cấp. Chỉ số tài khoản vô hiệu hóa mở danh sách đã lọc; Admin chỉnh
  thời hạn hoặc gỡ với lý do mới. Tài khoản Support/Admin chỉ xem.
- Từ người báo cáo/các bên liên quan hoặc người yêu cầu hỗ trợ có đường dẫn sang
  tài khoản, giữ mã hồ sơ cho nhật ký. Lệnh gửi lại sau lỗi mạng dùng nguyên request
  ID và payload; dữ liệu thay đổi đồng thời yêu cầu tải lại, không ghi đè.
- Không có mức độ trên danh sách, chi tiết hay biểu mẫu sự cố. Cột/enum cũ chỉ giữ
  tương thích dữ liệu; CSKH kết thúc hồ sơ cũ mà không cần Admin theo mức độ.
- Thu hồi phiên có hiệu lực truy cập ngay; không tự thu hồi/gán lại đơn đang giao.
  Số đơn đang xử lý được hiển thị trước khi xác nhận để CSKH đối chiếu người giữ hàng.

## Bổ sung kiểm tra bộ phân công ngày 2026-10-24

Bộ phân công server trước đây chưa loại tài khoản vừa vô hiệu hóa khỏi ứng viên
và chưa bỏ lượt hết thời gian nhận xảy ra trong khoảng bị khóa. Người dùng đã
duyệt sửa riêng ngày 2026-10-24; migration account_dispatch_guard đã áp dụng.
28 kiểm tra cô lập và kiểm tra quyền/gate trên Supabase đã đạt, xem
[account_dispatch_guard_proposal.md](account_dispatch_guard_proposal.md).
