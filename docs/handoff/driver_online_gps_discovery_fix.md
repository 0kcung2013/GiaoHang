# Lời mời không tới tài xế online — sửa ngày 2026-10-30

Gia cố vòng đời, xác nhận đồng bộ và tự phục hồi ngày 2026-11-03:
[driver_online_presence_recovery.md](driver_online_presence_recovery.md).

## Nguyên nhân đã xác minh

Đơn GH-10478 chưa từng có `offered_driver_id`; vì vậy đây là lỗi trước bước
hiển thị lời mời/Realtime. Hai tài xế online có `location_updated_at` từ nhiều
ngày trước và bị bộ điều phối loại theo cửa sổ GPS mới trong 3 phút.

Đọc trực tiếp Geolocation của tab tài xế đang chạy: quyền đã cấp, chế độ mặc
định `deviceGps`, mẫu GPS khoảng 34 giây tuổi với sai số 126 m. Bộ lọc 50 m
thêm trong thay đổi Giữ đơn đã chặn cả nhịp báo vị trí online. Đây là regression
phía client; không sửa database, cron, cấu hình phí hoặc quyền nhận lời mời.

## Thay đổi

- `driverLocationStreamProvider`: báo vị trí khi tài xế online chờ đơn, ngưỡng
  sai số tối đa 200 m. Giữ nguyên tọa độ đo được và kiểm tra timestamp 90 giây
  quá khứ / 15 giây tương lai; không biến mẫu cũ thành mẫu mới.
- `driverActiveLocationStreamProvider`: dùng cho nhiệm vụ đang thực hiện,
  giữ ngưỡng 50 m. Mẫu online 126 m không trở thành bằng chứng đã đến nơi.
- `LocationIngestService.ingestOnlinePresence`: kiểm tra riêng cho discovery,
  gọi pipeline latest hiện có mà không gắn `order_id`; không ghi lịch sử đơn.
- Không thay đổi pipeline R2, Edge Function hoặc Supabase schema/RLS.

200 m là giới hạn độ chính xác cho báo vị trí tìm tài xế, không phải bán kính
đến điểm lấy/giao. Giới hạn này ở `PhysicalGpsPolicy.onlineAccuracyMeters`;
ngưỡng giao hàng ở `deliveryAccuracyMeters`. Không có dependency, environment
variable hoặc secret mới. Cần hot restart/chạy lại app để nhận mã Dart đã sửa.

## Kiểm chứng

- Regression test ở đúng đường provider → kiểm tra GPS → ingest, dùng mẫu
  trình duyệt 126 m. Trước sửa không có request gửi vị trí; sau sửa có request
  đúng tọa độ và không gắn `order_id`.
- Kiểm tra mẫu 126 m vẫn bị từ chối ở chính sách giao hàng; mẫu online >200 m,
  mẫu cũ >90 giây và tương lai >15 giây vẫn bị từ chối.
- 27 test tập trung trong 6 file đạt; analyze 5 file thay đổi không có vấn đề.
- `supabase/tests/driver_online_presence_discovery.sql` chạy qua MCP: cùng tài
  xế bị loại khi GPS cũ và xuất hiện khi timestamp mới. Toàn bộ thay đổi fixture
  rollback, không làm mới GPS thật bằng SQL.
- App tài xế đã biên dịch/chạy bằng dev web-server tại `http://localhost:57874`.
  Các cửa sổ Chrome/Edge debug ban đầu đã đóng trong lúc sửa nên chưa xác nhận
  lời mời trên màn hình của phiên đăng nhập đó sau sửa. Chưa test điện thoại thật.

GH-10478 đã hết 15 phút tìm tài xế lúc 13:34:51 ngày 2026-10-30 (giờ Việt Nam).
Không tự gia hạn hoặc sửa đơn này bằng SQL. Sau khi chạy lại tài xế, dùng thao
tác tìm tài xế lại trong ứng dụng khách hàng hoặc thử với đơn mới theo nhu cầu.

## Vận hành và khôi phục

Khi không có lời mời, kiểm tra `offered_driver_id` trước. Nếu null, đối chiếu
online, phê duyệt, khóa nhận đơn, đơn đang giữ/đang thực hiện, hạn tìm và tuổi GPS.
Nếu đã có lời mời còn hạn thì mới kiểm tra subscription và bộ lọc hiển thị.
Không bỏ điều kiện GPS mới trên server hoặc thay timestamp của vị trí cũ để
ép tài xế vào matching. Nếu cần rollback client, không quay về chính sách dùng
một ngưỡng 50 m chung cho cả discovery và giao hàng.
