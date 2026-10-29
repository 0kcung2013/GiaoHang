# Bổ sung kiểm tra tài khoản trong phân công — đã triển khai

Phát hiện khi kiểm tra tích hợp sau hai migration tài khoản ngày 2026-10-21.
Người dùng đã duyệt riêng việc sửa ngày 2026-10-24. Đã áp dụng lên DATN qua
[20261024023954_account_dispatch_guard.sql](../supabase/migrations/20261024023954_account_dispatch_guard.sql).

## Vấn đề đã xác nhận trước khi sửa

- `private.road_driver_candidates` chỉ xét sẵn sàng, KYC, GPS, số dư, khoảng cách
  và khóa nhận đơn; chưa xét `auth.users.banned_until`. GPS được coi là mới 3 phút.
  Vì vậy tài khoản vừa vô hiệu hóa vẫn có thể nhận lời mời từ bộ phân công server.
- `private.record_driver_offer_refusal` đếm lời mời hết hạn mà chưa loại khoảng
  thời gian tài khoản bị vô hiệu hóa. Có thể cộng lượt từ chối vào khóa nhận đơn.
- Edge accept đã xác minh Auth nhưng có một khoảng giữa kiểm tra Auth và ghi nhận
  đơn. Native ban tại thời điểm đó cần được kiểm tra lại trong transaction nhận đơn.

## Bản SQL cụ thể

[account_dispatch_guard.sql](proposals/account_dispatch_guard.sql) tái sử dụng Auth
và nhật ký vừa được duyệt, sửa thêm bốn function hiện có:

1. Lọc tài khoản bị vô hiệu hóa khỏi danh sách ứng viên.
2. Kiểm tra lại lúc ghi lời mời để kết quả OSRM đã cũ không gửi cho tài khoản bị khóa.
3. Kiểm tra lại lúc nhận đơn qua API server; chặn nhận nếu quyết định khóa đã có hiệu lực.
4. Không tính lời mời hết hạn trong khoảng tài khoản bị vô hiệu hóa thành lượt từ chối.
   Tra lịch sử theo **thời điểm hết hạn**, nên cron chạy sau khi gỡ/hết khóa vẫn đúng.

Thêm hai helper trong schema private, chỉ service role được gọi trực tiếp. Khóa
đồng thời theo thứ tự: order → driver advisory → public.users → auth.users. Chia sẻ
khóa đọc với quy trình vô hiệu hóa để không có khoảng lọt giữa kiểm tra và ghi.
Không tạo bảng, cột, RLS hoặc sửa Edge Functions. Không sửa số dư, đơn đang giao,
người giữ hàng, `is_available` hoặc giá trị `acceptance_locked_until`. Giới hạn
4 lần/30 phút và khóa 30 phút hiện có giữ nguyên cho những lượt từ chối hợp lệ.

## Kiểm chứng

- `tool/account_dispatch_guard_test.mjs`: **28 kiểm tra PostgreSQL/PGlite đạt**,
  gồm ứng viên bị khóa, báo giá cũ, nhận đơn sau khóa, đường nhận đơn bình thường,
  khóa có hạn/vĩnh viễn/đã gỡ, cron chạy muộn và không ghi thêm khóa nhận đơn.
- Các phần còn lại của bốn function được đối chiếu nguyên văn với định nghĩa live;
  chỉ thêm các guard đã nêu. Hàm nhận đơn hiện chỉ service role được EXECUTE.
- PostGIS/OSRM và nghiệp vụ tài chính dùng fixture trong kiểm tra này; không đo lại
  chất lượng route hoặc thực thi giao dịch thật. Chưa thử cạnh tranh bằng hai phiên
  PostgreSQL thật; thứ tự khóa đã được rà soát, PGlite kiểm tra các nhánh tuần tự.
- Không khóa người dùng thật, không ghi lời mời hoặc đơn thật để thử.

## Kiểm tra sau triển khai ngày 2026-10-24

- Chạy lại 28 kiểm tra cô lập với chính file migration: đạt.
- Đối chiếu định nghĩa live: lọc Auth ban ở danh sách ứng viên, kiểm tra lại
  khi ghi lời mời/nhận đơn, loại thời điểm bị vô hiệu hóa khỏi lượt hết hạn.
- [account_dispatch_review_regression.sql](../supabase/tests/account_dispatch_review_regression.sql)
  đã đạt trên Supabase trong transaction rollback: quyền server/client,
  kiểm tra tài khoản hiện có, tài khoản không tồn tại và danh sách ứng viên.
- Helper chỉ cho service_role gọi; quyền của API phân công vẫn chỉ server.
  Không tạo bảng, cột hoặc thay RLS/Edge Functions.
