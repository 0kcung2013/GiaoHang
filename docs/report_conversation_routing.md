# Trao đổi theo báo cáo

- Nút Chat với CSKH trong Chờ CSKH duyệt và phần điều kiện giao lại mở
  cuộc trao đổi của đúng báo cáo đang chờ, không mở ticket hỗ trợ chung.
- Tin dùng RPC hiện có `post_risk_report_message` và `risk_report_id`.
  CSKH đọc/trả lời trong tab Trao đổi của báo cáo. Tài xế chỉ thấy tin công khai.
- Chat hỗ trợ từ menu chuyến đi dùng `ticket_id` và hoạt động độc lập.
- Realtime có thể phát INSERT sau snapshot đã chứa cùng bản ghi. Danh sách
  chat gộp theo ID; hai tin có cùng nội dung nhưng khác ID vẫn được giữ.
- Một thao tác gửi bị chặn khi đang gửi. Khi Realtime đã xác nhận mà HTTP
  lỗi, không phục hồi bản nháp để gửi lại.
- Đối chiếu chỉ đọc GH-10196 ngày 2026-10-09: một tin hello trong ticket,
  dù UI hiển thị hai dòng. Không sửa, chuyển hoặc xóa dữ liệu cũ.
- Không thay đổi schema, RLS, RPC, migration hay lưu trữ ảnh.
