# CSKH: giữ đơn và đổi tài xế

Người dùng đã chọn: **gỡ tài xế, giữ đơn để phân công lại**. Không hủy đơn
của khách. Báo cáo cần được CSKH xác minh; hàng cồng kềnh, sai thông tin hàng,
xe không phù hợp, vấn đề an toàn hoặc lý do chính đáng khác đều có thể được
đánh giá theo bằng chứng, không tự động chấp nhận theo tên nhóm lý do.

## Đã triển khai trong Flutter

- Nội dung và bằng chứng trước; khối xử lý nằm bên cạnh trên màn hình rộng.
- Bỏ ghi chú nội bộ/Admin của CSKH. Hội thoại chỉ gửi cho người báo cáo.
- Thông tin đơn, liên hệ và lịch sử mở khi cần; bằng chứng tin nhắn có dữ liệu
  được mở sẵn. Giữ khả năng đối soát và truy cập lịch sử.
- Trang hồ sơ dùng toàn bộ vùng nội dung, bỏ khung dialog và hàng đợi phụ.
- Dùng các RPC hiện có: giữ đơn/gỡ tài xế, bàn giao hàng, xác nhận tiếp nhận
  và cho phép phân công lại. Không cập nhật trạng thái đơn trực tiếp từ client.

## Giới hạn backend đã kiểm tra ngày 2026-10-08

`hold_risk_order_before_pickup(uuid,text)` chỉ nhận `assigned`.
`decide_risk_delivery_operation(uuid,text,text)` xử lý `picking_up` giống
`delivering`, mặc dù `actual_picked_up_at` mới xác định hàng đã được nhận.
Do đó báo cáo về hàng hóa lúc tài xế **đang đến lấy nhưng chưa nhận hàng**
chưa có đường gỡ trực tiếp đúng nghiệp vụ.

`resume_risk_held_order(uuid)` đã đưa đơn về `confirmed`, giữ `driver_id=NULL`.
Trigger `private.capture_risk_hold_cause()` đã lưu liên kết hồ sơ cho bước
phân công lại. Không cần thêm bảng, cột hoặc dịch vụ.

## Thay đổi backend đề xuất — CHƯA thực hiện, cần duyệt riêng

1. Mở rộng RPC giữ đơn hiện có cho `assigned` và `picking_up` khi
   `actual_picked_up_at IS NULL`. Giữ kiểm tra hồ sơ, người phụ trách,
   trạng thái can thiệp và quyền CSKH/Admin; khóa đơn/tài xế khi quyết định.
   Nếu xác nhận lấy hàng xảy ra đồng thời, đọc lại trong cùng transaction và
   từ chối gỡ trực tiếp.
2. Ghi lý do từ báo cáo và kết luận xác minh vào dữ liệu/audit hiện có;
   không tạo form ghi chú Admin mới. Đối soát tiền COD đang giữ và giải phóng
   khoản giữ cho tài xế cũ theo cơ chế giao dịch ví hiện có, mỗi đơn một lần.
   Quyết định CSKH có lý do chính đáng không dùng khóa nhận đơn 30 phút của
   luồng tài xế tự hủy vì việc cá nhân.
3. Chỉ cho quyết định hoàn/bàn giao khi có xác nhận đã nhận hàng.
   Với hàng đã nhận: giữ tài xế chịu trách nhiệm đến khi hoàn/bàn giao được
   xác nhận. Bàn giao xong mới gỡ và cho phép phân công lại. Hoàn hàng vẫn dùng
   luồng hoàn hiện có; không biến một đơn đã hoàn thành hoàn trả thành đơn mới.
4. Flutter đọc cột `actual_picked_up_at` đang có vào summary để chọn đúng nút
   theo trạng thái thực tế. Chỉ bật nhánh gỡ ở `picking_up` sau khi RPC được cập
   nhật. Không mở thêm quyền Admin cho CSKH hoặc bỏ kiểm tra chủ hồ sơ.

## Kiểm tra bắt buộc sau khi duyệt

- `assigned` hoặc `picking_up` chưa lấy hàng: gỡ, giữ đơn, giải phóng COD đúng
  một lần, phân công lại, không khóa tài xế vì việc cá nhân.
- Đã lấy hàng: từ chối gỡ trực tiếp; bàn giao + xác nhận + phân công lại.
- Xác nhận lấy hàng và gỡ đồng thời: chỉ một chuyển trạng thái hợp lệ thành công.
- Nhân viên khác, người dùng không phải staff, hồ sơ đóng hoặc quyết định lặp:
  không được sửa đơn hoặc ví.
- Đối soát lịch sử đơn, lịch sử báo cáo, driver assignment và trạng thái ví.

Đây là đề xuất để duyệt, chưa phải migration và chưa chạy trên Supabase.
Quy định áp dụng: `AGENTS.md` — “không thay đổi Supabase schema, RLS policies,
migrations, Edge Functions, hoặc database fields nếu chưa được hỏi và chấp thuận riêng”.
