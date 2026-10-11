# Hủy hoàn hàng để giao lại — phạm vi backend đã duyệt

Trạng thái: người dùng đã đồng ý bổ sung backend và migration. Đã áp dụng
`20261009115541_driver_cancel_return_for_redelivery` lên Supabase ngày 2026-10-09.

## Hợp đồng đã triển khai

Lệnh `cancel_order_return(p_order_id, p_reason)` chạy một transaction:

1. Khóa đơn, nhiệm vụ hoàn và can thiệp CSKH liên quan.
2. Chỉ tài xế đang giữ đơn được gọi; chỉ cho phép nhiệm vụ đang `returning`.
3. Chỉ cho phép hoàn vì không liên hệ được người nhận. Lệnh hoàn do rủi ro
   hoặc an toàn vẫn phải được CSKH quyết định. Mã nguyên nhân phải được chuẩn
   hóa từ báo cáo hiện có; không suy quyền từ văn bản tự do `reason_code`.
4. Đổi `orders.status` về `delivering`, giữ tài xế và thông tin thanh toán đơn.
5. Giữ bản ghi `order_returns` với trạng thái `cancelled`, miễn phần phí hoàn
   chưa quyết toán; không ghi khoản thu nhập hoàn thành chuyến hoàn.
6. Giải phóng can thiệp `return_required` để giao tiếp được; ghi lý do khách
   yêu cầu nhận lại trong sự kiện/báo cáo đang có. Giữ nguyên lịch sử duyệt hoàn.
7. Ghi `order_status_logs` và `risk_report_events` gồm actor, thời gian server,
   trạng thái trước/sau, mã nhiệm vụ hoàn và lý do.
8. Trả về nhiệm vụ hoàn đã hủy sau khi cập nhật đơn. Client chỉ bật Giao thành công sau khi
   transaction thành công; lỗi/race giữ trạng thái hoàn hiện tại.

## Các thay đổi trong phạm vi được duyệt riêng theo AGENTS.md

- Một migration bổ sung trạng thái `cancelled` vào CHECK của `order_returns`.
- RPC mới và cập nhật guards chuyển trạng thái/custody hiện có để cho phép
  duy nhất trường hợp hủy hoàn đã kiểm tra quyền và nguyên nhân.
- Điều chỉnh lệnh duyệt hoàn để CSKH có thể duyệt một lần hoàn mới nếu giao lại
  vẫn thất bại. Tái sử dụng bản ghi hiện có và giữ mọi lần thử trong nhật ký;
  không tạo bảng metadata hoặc xóa lịch sử.
- Cập nhật model chung và các UI đọc trạng thái hoàn mới.
- Kiểm tra quyền, gọi lặp, hủy đồng thời với xác nhận trả hàng, và không chi
  tiền phí hoàn cho nhiệm vụ đã hủy.

Tái sử dụng bảng, nhật ký và pipeline GPS hiện có.

## Thay đổi Flutter

- Trang hoàn gồm Lấy/Giao và các thanh gạt.
- Bản đồ OSM mở riêng, có quay lại, chỉ dẫn, và Start.
- Chuyển trạng thái đơn không khởi động chuyển động GPS mô phỏng.
- Start tiếp tục trên polyline từ vị trí cuối; quay lại trang chính giữ tiến trình.
- GPS thật tiếp tục dùng nguồn thiết bị; không thay bằng dữ liệu mô phỏng.

## Kiểm tra backend

`supabase/tests/driver_return_redelivery.sql` tạo dữ liệu kiểm tra trong transaction
và rollback toàn bộ. Đã qua trước và sau khi áp dụng migration: kiểm tra quyền tài xế,
lý do bắt buộc, chặn đổi trạng thái trực tiếp, gọi lặp không nhân bản audit, không trả
phí hoàn, không hoàn thành nhiệm vụ đã hủy, duyệt lần hoàn mới và chặn tự hủy hoàn
do an toàn. Các lệnh hoàn khóa đơn trước khi khóa nhiệm vụ/can thiệp liên quan để
tuần tự hóa thao tác với cùng một đơn.
