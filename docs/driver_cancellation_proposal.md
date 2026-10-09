# Hủy đơn của tài xế — đã triển khai

Backend được người dùng chấp thuận riêng ngày 27/09/2026 và đã áp dụng trên Supabase `erlpzwfbpjogvaulcxni`. Flutter đã nối vào tab Đơn hàng, xác nhận đến nơi trong navigation, trang chính và các điểm nhận đơn.

## Hành vi

- Tài xế có thể hủy khi đơn ở `assigned` hoặc `picking_up`, trước khi nhận hàng. Sau khi đã xác nhận lấy hàng hoặc có bằng chứng lấy hàng, tiếp tục dùng luồng hỗ trợ/hoàn hàng hiện có.
- **Quán đóng cửa:** gạt xác nhận đã đến điểm lấy trong phạm vi 100 m. Bộ đếm 10 phút bắt đầu từ lần xác nhận đầu tiên; chỉ cho hủy khi hết thời gian. Hủy đơn của khách, đánh dấu cần hoàn tiền nếu khách đã thanh toán; không khóa nhận đơn.
- **Lý do cá nhân:** hiển thị cảnh báo khóa 30 phút trước khi xác nhận. Đưa đơn về `pending` để tìm tài xế khác, giữ thanh toán của khách, giải phóng khoản giữ ví cũ nếu có. Ghi khóa trong cùng transaction.
- Sau hủy thành công, dọn phiên navigation/GPS và quay về trang chính. Trang chính hiển thị vòng tròn đếm ngược; chặn lời mời, FreePick và phân công tự động trong thời hạn.
- Deadline do server quản lý. Mở lại app, đăng nhập lại hoặc dùng thiết bị khác không đặt lại thời gian. Flutter dùng giờ server và thời gian đã trôi qua để hiển thị bộ đếm; Realtime và polling đồng bộ trạng thái.
- Thao tác lặp không kéo dài deadline, không hoàn khoản giữ ví hoặc ghi audit hai lần.
- Nút **Hủy đơn** chỉ hiển thị dưới hành động tiếp tục giao trên thẻ của tab Đơn hàng; không hiển thị trên bản đồ hoặc thẻ ở Trang chủ.
- Sheet dùng nền sáng, thẻ chọn lý do và footer cố định. **Cửa hàng đóng cửa** làm mờ và không chọn được trước hạn; bộ đếm nằm ngay trong thẻ và tự bật lựa chọn khi đủ 10 phút. Khi chưa xác nhận đã đến, hiển thị hướng dẫn thay bộ đếm.

## Dữ liệu và quyền

Không thêm bảng mới. Tái sử dụng `orders`, `drivers`, `order_status_logs`, thông báo và ledger ví.

- `orders.pickup_arrived_at`: lần đầu xác nhận đã đến, reset khi đổi tài xế. Tách biệt với mốc đã nhận hàng.
- `drivers.acceptance_locked_until`: hạn khóa nhận đơn, độc lập với khóa PIN online và duyệt/KYC.
- RPC: `confirm_driver_pickup_arrival`, `get_driver_order_cancellation_state`, `cancel_driver_order`, `get_driver_acceptance_state`.
- RPC kiểm tra vai trò và quyền trên đơn, dùng giờ server và khóa bản ghi. Client không được sửa các cột deadline hoặc chèn đơn đã gán tài xế. Backend kiểm tra hạn khóa tại nhận đơn, FreePick, online, chọn ứng viên và gán tài xế.
- RPC mới là SECURITY DEFINER với search_path cố định, chỉ cấp EXECUTE cho authenticated và có kiểm tra người gọi; không cấp anon.

Các migration trong repo khớp phiên bản đã áp dụng:

1. `20260927140138_driver_cancellation_and_acceptance_lock.sql`
2. `20260927140424_protect_driver_cancellation_deadline_columns.sql`
3. `20260927141437_guard_locked_driver_assignment_inserts.sql`

## Kiểm chứng

- 58 test Flutter đạt trong 10 tệp tập trung: policy/countdown/sheet, repository, tích hợp trang chính và swipe đến nơi, navigation lifecycle, custody guard, lời mời, danh sách đơn và FreePick.
- Layout test gồm 375×568, 390×844, landscape 844×390 và text scale 1.6.
- Analyze tập trung các tệp thay đổi: không có lỗi hoặc cảnh báo.
- `supabase/tests/driver_cancellation_regression.sql` đạt trên Supabase: kiểm tra quyền, geofence, chờ đủ 10 phút, khóa 30 phút, tìm lại tài xế, giữ thanh toán, hoàn khoản giữ một lần, retry, custody, hết hạn khôi phục nhận đơn và chống chèn đơn vượt khóa. Dữ liệu giả được tạo trong transaction và rollback toàn bộ.
- Chưa chạy full suite, build phát hành, kiểm thử nhiều session đồng thời hoặc QA trên thiết bị thật. Chưa xác nhận hình ảnh với font thật vì môi trường widget render thiếu asset Plus Jakarta Sans/JetBrains Mono.

### Kiểm chứng sau chỉnh UI

- 34 test đạt trong 6 tệp tập trung: cancellation, vị trí/thao tác nút hủy, danh sách đơn, tích hợp trang chính/swipe, lifecycle và hồi quy arrival.
- Kiểm tra chọn lý do sau hết giờ, giữ sheet khi lỗi, chống submit lặp, ẩn nút sau lấy hàng, dọn phiên navigation và quay về trang chính.
- Analyze các tệp UI và test thay đổi không có lỗi/cảnh báo. Đã xem ảnh render bố cục bằng font Arial/Consolas thay thế cục bộ; chưa xác nhận với font dự án trên thiết bị thật.
