# Gộp bảng CSKH và bằng chứng — 2026-10-09

Phạm vi được người dùng duyệt: gộp dữ liệu hội thoại và bằng chứng, xóa GPS cũ
đã quá thời hạn 14 ngày. Không thay đổi các bảng nghiệp vụ khác.

| Trước | Sau |
| --- | --- |
| `support_ticket_messages`, `risk_report_messages`, `risk_report_notes` | `case_messages` |
| `risk_report_attachments`, `risk_report_message_evidence` | `risk_report_evidence` |
| `driver_locations` | Xóa GPS cũ và bảng; lịch sử GPS mới vẫn trên R2 |

Tái sử dụng bảng có sẵn bằng đổi tên, mở rộng cột và chuyển dữ liệu trong một
transaction. Giữ ID, nội dung, người gửi, thời gian, quan hệ với hồ sơ và nhật ký.
Ghi chú từng được ghi đồng thời vào hai bảng được nhận diện theo ID để tránh trùng.
Migration kiểm tra dữ liệu chuyển sang trước khi xóa bảng cũ bằng `RESTRICT`.

## Hội thoại: `case_messages`

Mỗi tin nhắn có đúng một `ticket_id` hoặc `risk_report_id`. `sender_id`,
`sender_role_snapshot`, `body`, `created_at` và `visibility` giữ ý nghĩa hiện có.
`public` dành cho hội thoại với người yêu cầu; `internal` dành cho CSKH/Admin.
Ghi chú nội bộ trở thành tin nhắn `internal`, không còn ghi hai bản dữ liệu.
Khách hàng/tài xế chỉ đọc được hội thoại công khai của hồ sơ do mình gửi.
Ghi dữ liệu qua RPC hiện có, có kiểm tra người xử lý; client không ghi trực tiếp.
Realtime dùng chung bảng và lọc theo khóa hồ sơ.

## Bằng chứng: `risk_report_evidence`

- `photo`: `storage_path` trỏ đến ảnh nghiệp vụ; dữ liệu ảnh vẫn nằm trên R2
  hoặc Supabase Storage cũ. Không lưu URL ký tạm thời.
- `location`: `latitude`, `longitude`, `captured_at`; đây là vị trí tại thời
  điểm báo cáo, không phải lịch sử GPS liên tục của tài xế.
- `message`: `source_message_id`, `sender_id`, `message_type`, `body_snapshot`,
  `sent_at_snapshot`, `added_by`, `created_at`; giữ bản chụp tin nhắn đơn hàng
  được chọn làm bằng chứng. Nếu tin gốc bị xóa, khóa tham chiếu thành NULL và
  bản chụp vẫn được giữ. Không sao chép toàn bộ hội thoại đơn hàng.

Mọi bằng chứng thuộc `risk_report_id`; `order_id` giữ quan hệ với đơn khi có.
Ràng buộc kiểm tra dữ liệu theo loại và ngăn gắn trùng cùng tin nhắn vào một hồ sơ.
Quyền đọc ảnh/vị trí và bằng chứng tin nhắn giữ phạm vi nghiệp vụ hiện có.
Hai app lọc `evidence_type` để mỗi màn hình chỉ nhận đúng loại dữ liệu.
Worker R2 tra cứu bảng mới khi cấp quyền tải ảnh báo cáo.

## Bảng giữ lại và số lượng

`order_items` vẫn cần để biểu diễn nhiều hàng hóa/số lượng trong một đơn.
Các bảng ví, nhật ký, hoàn hàng, can thiệp và hồ sơ tài xế vẫn có vòng đời riêng.
Không gộp `support_tickets` với `risk_reports` trong đợt này.

Số bảng nghiệp vụ giảm từ 28 xuống 24. Table Editor có thể hiển thị thêm
`spatial_ref_sys` và hai view `geography_columns`, `geometry_columns` của PostGIS.

## Kiểm tra

Fixture SQL chạy trong transaction rollback, không giữ dữ liệu giả:

- `supabase/tests/case_evidence_consolidation_preflight.sql`: dữ liệu ghi chú
  cũ đã được nhân bản và chưa được nhân bản, dùng trước migration khi chạy thử.
- `supabase/tests/case_evidence_consolidation_regression.sql`: quyền đọc/ghi,
  nội dung nội bộ, RPC, bản chụp tin nhắn và Realtime sau migration.
- `supabase/tests/support_workflow_regression.sql`: luồng CSKH hiện có.

Test Flutter tập trung kiểm tra caller của cả hai app; test Node kiểm tra quyền
tải ảnh và việc giữ nguyên luồng GPS của Worker. Khi chuyển backend sang bảng
mới, cần chạy lại/hot restart cả hai app bằng code đã cập nhật. Bản app cũ gọi
tên bảng đã xóa sẽ không còn đọc được hội thoại hoặc bằng chứng đó.
