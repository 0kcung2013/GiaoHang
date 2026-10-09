# Hủy đơn cho tài xế trước khi nhận hàng

Yêu cầu ngày 2026-10-08: CSKH xác nhận hủy nhiệm vụ của tài xế chưa nhận hàng;
tài xế về trang chính và thấy thông báo «Đơn đã được CSKH hủy». Hàng đã nhận
dùng chức năng hoàn hàng. Đơn của khách vẫn được giữ để CSKH xử lý/phân công lại.

## Phần Flutter đã hoàn tất

- Đọc cột `orders.actual_picked_up_at` hiện có trong dữ liệu CSKH.
- `assigned`, hoặc `picking_up` chưa có mốc nhận hàng: xác nhận hủy gọi
  `hold_risk_order_before_pickup`, không tạo quyết định bàn giao.
- Đã có mốc nhận hàng hoặc đang giao: ẩn nút hủy tài xế; giữ luồng hoàn hàng.
- Tài xế chỉ thoát khi Realtime xác nhận đã giải phóng đúng tài xế, đúng đơn.
  Dừng điều hướng, xóa phiên đã lưu, về `/driver-home`, rồi hiện thông báo.
- Yêu cầu bàn giao cũ trước khi nhận hàng không hiện form xác nhận bàn giao;
  chờ CSKH xác nhận lại hủy theo đúng luồng.

## Thay đổi Supabase đã được chấp thuận và áp dụng

Kiểm tra trực tiếp ngày 2026-10-08: RPC `hold_risk_order_before_pickup(uuid,text)`
đang chỉ cho phép `assigned`, chưa hỗ trợ `picking_up` dù chưa nhận hàng.
Người dùng đã chấp thuận riêng: «Cho phép cập nhật Supabase theo đề xuất».
Migration `20261008051644_support_pre_pickup_driver_release.sql` đã được áp dụng
lên project `erlpzwfbpjogvaulcxni`. RPC hiện hỗ trợ cả hai trạng thái khi chưa nhận hàng.

Cập nhật chính RPC hiện có, không thêm bảng, cột hay dịch vụ:

1. Khóa hàng đơn và hồ sơ can thiệp; kiểm tra nhân viên Support/Admin phụ trách.
2. Chấp nhận `assigned` hoặc `picking_up` **chỉ khi** `actual_picked_up_at IS NULL`.
   Kiểm tra lại sau khi lấy khóa để không hủy khi tài xế vừa xác nhận nhận hàng.
3. Cho phép trạng thái can thiệp `awaiting_triage`; hỗ trợ xác nhận lại hồ sơ
   `handoff_required` cũ nếu đúng tài xế, đúng đơn và vẫn chưa nhận hàng.
   Không giải phóng hồ sơ hoàn hàng hoặc đơn đã nhận hàng.
4. Giữ kết quả nghiệp vụ hiện có: `risk_hold`, bỏ tài xế khỏi đơn,
   `held_before_pickup`, đặt `driver_released_at`, ghi lịch sử và audit hiện có.
   Không áp dụng khóa nhận đơn 30 phút của luồng tài xế tự hủy.
5. Giữ quyền đọc Realtime hiện có; không đổi RLS hoặc hợp đồng RPC.
6. Tạo migration bằng Supabase CLI sau khi được duyệt; kiểm tra hồi quy trong
   transaction rollback: chưa nhận hàng, đã nhận hàng, sai nhân viên,
   gọi lặp, xung đột xác nhận nhận hàng và hồ sơ bàn giao cũ.

Kiểm tra hồi quy `supabase/tests/support_pre_pickup_driver_release_regression.sql`
đã chạy thành công trước và sau khi áp dụng migration. Toàn bộ fixture, thông báo
và lịch sử kiểm thử nằm trong transaction rollback. Quyền thực thi RPC và RLS giữ nguyên.
