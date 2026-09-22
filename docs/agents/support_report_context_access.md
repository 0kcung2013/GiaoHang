# Đề xuất quyền đọc ngữ cảnh báo cáo cho CSKH

Trạng thái: chờ chấp thuận; chưa thay đổi database, RLS hoặc migrations.

## Vấn đề đã xác minh

- `users_select_own` chỉ cho đọc hồ sơ của tài khoản hiện tại.
- CSKH được đọc đơn hàng qua `orders_select_support`.
- Các foreign key của đơn hàng trỏ tới `users`: `orders_customer_id_fkey`
  và `orders_driver_id_fkey`.
- Vì vậy các join hồ sơ người gửi, khách đặt đơn, tài xế và nhân viên phụ trách
  có thể trả về null trong phiên CSKH dù hồ sơ tồn tại.
- Chưa có RPC cho CSKH đọc các hồ sơ này theo một báo cáo cụ thể.

## Thay đổi đề xuất để chấp thuận

Thêm RPC `get_risk_report_context(p_report_id uuid)` trả về JSON cho một báo cáo.
RPC dùng kiểm tra role hiện có `private.require_risk_staff()`;
chỉ tài khoản đã đăng nhập có role `support` hoặc `admin` được gọi.

Thông tin trả về:

| Khối | Trường |
| --- | --- |
| Báo cáo | id, reported_by, assigned_to |
| Người gửi | full_name, role, avatar_url, phone, email |
| Nhân viên phụ trách | full_name |
| Khách đặt đơn | full_name, avatar_url, phone, email |
| Tài xế của đơn | full_name, avatar_url, phone, email |
| Phương tiện | vehicle_type, license_plate |

Người được đọc phải được xác định từ chính báo cáo và đơn hàng liên quan;
không nhận danh sách user ID tùy ý. Sự cố hệ thống không có đơn hàng trả về
null cho khách đặt đơn, tài xế và phương tiện. Đơn chưa có tài xế trả về null
cho tài xế và phương tiện.

Không mở quyền SELECT toàn bộ bảng `users` hoặc `drivers`. Function có
`search_path` rỗng, tham chiếu đầy đủ schema, chỉ cấp EXECUTE cho `authenticated`,
thu hồi quyền EXECUTE của PUBLIC/anon và kiểm tra role bên trong function.
Không trả về KYC, giấy tờ hoặc thông tin tài chính tài xế.

## Tích hợp và kiểm tra sau khi được chấp thuận

Operations Web tải ngữ cảnh khi mở chi tiết, gắn dữ liệu vào các thẻ đã tạo;
lỗi tải ngữ cảnh hiển thị lỗi cùng nút thử lại, không làm mất nội dung báo cáo.

Kiểm tra customer, driver và anon bị từ chối; support/admin được đọc đúng
báo cáo, các hồ sơ không liên quan không xuất hiện. Kiểm tra thêm đơn chưa có
tài xế và báo cáo hệ thống. Chạy kiểm tra UI tập trung và query bằng phiên CSKH.
