# Giới hạn từ chối lời mời nhận đơn

Quy tắc hiện tại, mở rộng theo yêu cầu ngày 2026-10-11: **chuyển đơn thành công
hoặc bỏ qua đến hết thời gian nhận** đều tính một lượt từ chối. Từ chối **4 đơn
khác nhau trong 30 phút gần nhất** thì tạm khóa nhận đơn mới **30 phút**. Nhận đơn
xen giữa không xóa lượt. Lỗi thao tác và xử lý lại cùng lời mời không cộng thêm lượt.

## Backend đã áp dụng

Người dùng đã chấp thuận riêng migration/RPC ngày 2026-10-09. Migration đã áp dụng trên Supabase:
[20261009153139_driver_offer_transfer_acceptance_lock.sql](../supabase/migrations/20261009153139_driver_offer_transfer_acceptance_lock.sql).

[SQL đã dùng để duyệt](driver_transfer_limit_backend_proposal.sql) được giữ làm tài liệu; migration là nguồn triển khai.

Người dùng đã chấp thuận riêng SQL bổ sung ngày 2026-10-11. Hai migration đã áp dụng:

- [expired_offer_refusal_acceptance_lock.sql](../supabase/migrations/20261011012338_expired_offer_refusal_acceptance_lock.sql): dùng chung helper ghi nhận từ chối cho chuyển đơn và hết hạn.
- [expired_offer_refusal_trigger_columns.sql](../supabase/migrations/20261011012510_expired_offer_refusal_trigger_columns.sql): mở rộng trigger hiện có để theo dõi cả cột lời mời.

[SQL bổ sung đã duyệt](expired_offer_refusal_proposal.sql) giữ làm tài liệu đối chiếu.

- Tái sử dụng `drivers.acceptance_locked_until`, `order_status_logs`,
  `notifications`, RPC `reject_order` và `get_driver_acceptance_state`.
- Không thêm bảng/cột hoặc đổi hợp đồng trả về `uuid` của `reject_order`.
- RPC giữ quyền tài xế được mời và thời hạn lời mời; dùng khóa transaction theo
  tài xế và giờ server. Đơn đã tính vào một đợt khóa không được tính lại.
- Bổ sung hai index trên nhật ký, helper private và mở rộng guard nhật ký có sẵn
  để client không thể giả mạo, sửa hoặc xóa các bản ghi tính hạn mức.
- Snapshot acceptance có số đơn đã từ chối, thời điểm một lượt ra khỏi cửa sổ
  và nguyên nhân khóa. UI chỉ hiển thị hạn mức khi backend có snapshot này.
- Khóa nhận đơn áp dụng cho cả lời mời tự động và FreePick bằng guard hiện có;
  tài khoản đăng nhập, đơn đang giao và lựa chọn online giữ hành vi hiện tại.
- Tái sử dụng Realtime/polling acceptance để làm mới bộ đếm và countdown.

## Lời mời hết hạn

- Tác vụ backend đang chạy mỗi 5 giây, thu hồi lời mời đã hết hạn và chuyển đơn
  theo luồng hiện có. Trigger dùng tài xế và thời hạn trên bản ghi cũ trước khi
  xóa/thay lời mời. Việc tính lượt hoạt động ngay cả khi app đóng.
- Thời điểm phát sinh lượt là `offer_expires_at` do backend cấp. Một lời mời cũ
  được xử lý trễ quá 30 phút vẫn có nhật ký, nhưng đã nằm ngoài cửa sổ tính khóa.
- Chuyển đơn thủ công dùng giờ server tại thời điểm xử lý. Hai trường hợp có cùng
  nhật ký `Tài xế từ chối lời mời`, cùng bộ đếm và cùng khóa theo tài xế.
- Xử lý lại, thao tác chuyển đúng lúc hết giờ hoặc gửi lại yêu cầu không cộng
  trùng. Lời mời cuối cùng trùng hạn tìm tài xế 15 phút vẫn được tính; tìm tài xế
  hết hạn khi chưa gửi lời mời nào không quy lỗi cho tài xế.
- Thay lời mời hết hạn khi nhận qua FreePick vẫn ghi lượt cho tài xế được mời cũ.
  Nhận đơn hoặc hủy trước khi lời mời hết hạn không cộng lượt hết hạn.
- Nếu đã có khóa nhận đơn đang hiệu lực, lượt hết hạn vẫn được ghi nhận nhưng
  không kéo dài/rút ngắn khóa đó. Bộ đếm này độc lập với giao muộn và điểm vi phạm.
- UI cảnh báo hết giờ cũng tính lượt từ chối. Countdown chỉ hiển thị; lượt do
  server ghi nhận. Khóa được làm mới qua Realtime; số lượt có polling dự phòng 30 giây.

## Kiểm thử cập nhật ngày 2026-10-11

Hai SQL regression chạy thành công với rollback toàn bộ dữ liệu kiểm thử:

- [driver_offer_transfer_limit_regression.sql](../supabase/tests/driver_offer_transfer_limit_regression.sql): chuyển đơn thủ công, nhận xen giữa, cửa sổ 30 phút, đơn trùng, khóa/hết khóa, quyền nhận đơn và bảo vệ audit.
- [expired_offer_refusal_regression.sql](../supabase/tests/expired_offer_refusal_regression.sql): hết hạn không cần client, hết hạn/chuyển dùng chung hạn mức, xử lý trễ, FreePick thay lời mời, hạn tìm tài xế, chống đếm trùng và giữ khóa đã có.

18 kiểm thử Flutter tập trung (giới hạn từ chối + countdown) đã qua; analyze 5
file liên quan không có lỗi. Đã render lời mời/hộp xác nhận ở 320×568 và 390×844,
chữ 100%/160%; 4 lượt kiểm tra render không có lỗi layout. Security advisors giữ
nguyên số lượng và nội dung cảnh báo. Chưa chạy full suite, build phát hành hoặc
kiểm thử trên điện thoại thật.

Kịch bản thử tay: bật nhận đơn rồi bỏ qua một lời mời đến hết 45 giây; backend sẽ
cộng một lượt khi thu hồi lời mời. Kết hợp bỏ qua và bấm Chuyển đơn trên đủ 4 mã đơn
khác nhau trong 30 phút để kiểm tra khóa 30 phút. Mở lại app để kiểm tra trạng thái
được phục hồi từ server; gửi lại yêu cầu không làm tăng lượt hay kéo dài khóa.

## Kiểm tra của phiên bản ngày 2026-10-09

SQL regression đã qua trước và sau khi áp dụng trong transaction rollback: đơn thứ 1–3, đơn thứ 4, cửa sổ
30 phút, đơn trùng, timeout, sai quyền, khóa đã tồn tại, hết khóa và không dùng lại
đơn cũ; kiểm tra normal accept/FreePick bị chặn và audit không thể bị giả mạo.

37 kiểm thử Flutter tập trung đã qua; analyze không có lỗi. Đã render và kiểm tra
giao diện ở 320×568 và 390×844, gồm cỡ chữ 160%. Security advisors không phát sinh
cảnh báo mới. Chưa chạy toàn bộ test suite, build phát hành hoặc thử trên điện thoại thật.
