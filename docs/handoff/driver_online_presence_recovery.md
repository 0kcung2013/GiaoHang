# Tài xế online: phát hiện GPS đứng và tự phục hồi

Ngày sửa: 2026-11-03. Bổ sung cho
[bản sửa ngưỡng GPS ngày 30/10](driver_online_gps_discovery_fix.md).
Xử lý tiếp timeout GPS Web và màn kiểm tra chờ lâu:
[driver_web_gps_timeout.md](driver_web_gps_timeout.md).
Theo yêu cầu tiếp theo cùng ngày, đã bỏ thẻ cảnh báo GPS khỏi giao diện;
xem [GPS nền không chèn cảnh báo](driver_presence_background.md).

## Dữ liệu và lỗi tái hiện

Kiểm tra chỉ đọc GH-10533 lúc 12:17 ngày 03/11: đơn đã thanh toán,
`offered_driver_id` trống; hai tài xế online có GPS từ 30/10 và 26/10.
Tọa độ lưu khi đó cách điểm lấy khoảng 17,8 km. Backend yêu cầu GPS mới trong
3 phút và bán kính tự động 2 km; không có ứng viên hợp lệ.

Không có trace GPS của chính tab trong ảnh để khẳng định thiết bị đã gặp lỗi
nào. Các test đã tái hiện được những khe hở trong client cũ:

- Edge trả HTTP 200 nhưng `pg_updated=false` vẫn được coi là gửi thành công.
- Sau một lỗi Edge, cờ `_edgeUnavailable` tắt thử lại Edge suốt phiên.
- GPS chờ đơn chỉ được giữ bởi widget dashboard, sau các nhánh loading/error.
- Các producer dùng chung `LocationService` có thể dừng subscription của nhau.
- Mẫu GPS lấy trước khi mở PIN có thể cũ lúc xác nhận; GPS sai chất lượng hoặc
  không gửi được không có phản hồi rõ trên màn hình chờ đơn.

## Hành vi đã triển khai

`DriverOnlinePresenceHost` đặt bên trong Driver Shell, độc lập với nội dung
dashboard và tiếp tục trên các tab. Khi tài xế bật nhận đơn và không có nhiệm vụ
đang giữ quyền phát vị trí, host giữ `driverPresenceSessionProvider`.
Lỗi tải danh sách đơn không dừng GPS. Khi nhiệm vụ xuất hiện, GPS chờ đơn dừng;
luồng nhiệm vụ hiện có tiếp quản. Sau hoàn thành/thu hồi, GPS chờ đơn tự bắt đầu lại.

`DriverPresenceSession` dùng một `LocationService` riêng cho discovery. Dừng nó
không dừng subscriber của đơn đang giao. Stream yêu cầu độ chính xác cao; lỗi
hoặc kết thúc stream giải phóng cờ tracking để khởi động lại. Callback của thế
hệ stream cũ không ghi đè cờ của stream mới.

| Cấu hình client | Mặc định |
|---|---|
| Heartbeat kể cả đứng yên | 30 giây |
| Thử lại lỗi acquisition/sync | Nhịp 10 giây; không chồng acquisition đang chạy |
| Timeout acquisition của `LocationService` / publish của session | 8 giây / 20 giây |
| Timeout Edge / fallback latest của heartbeat | Mỗi bước 8 giây |
| Hết hiệu lực báo GPS sẵn sàng | 90 giây từ xác nhận cuối |
| GPS discovery | Sai số ≤200 m, capture không cũ quá 90 giây hoặc tương lai quá 15 giây |
| GPS giao nhận / giám sát | Giữ ngưỡng 50 m hiện có |

Heartbeat dùng endpoint `ingest-driver-location` hiện có và `force_pg_sync` để
xác nhận `pg_updated=true`. Edge không xác nhận thì dùng đường cập nhật latest
hiện có; fallback phải trả về đúng một dòng thay vì coi UPDATE 0 dòng là thành
công. Heartbeat sau tiếp tục thử Edge, kể cả khi lần trước lỗi. Không gắn
`order_id`, không ghi lịch sử GPS chờ đơn vào PostgreSQL hay R2.

Host không chèn thẻ trạng thái GPS hoặc nút **Thử lại GPS** lên các tab. Phiên
GPS được giữ trực tiếp qua provider, tiếp tục tự thử lại khi timeout hoặc lỗi.
Quay lại app sẽ kiểm tra tuổi xác nhận ngay và lấy mẫu mới. Phản hồi thành công
cũ không che lỗi GPS mới hơn. Không đổi `is_available` khi mất GPS: đây vẫn là
ý định nhận đơn, còn backend tiếp tục quyết định điều kiện phân công.

Bước bật nhận đơn lấy và kiểm tra GPS ngay trong callback xác nhận PIN.
Không giữ mẫu lấy trước khi người dùng nhập PIN. Việc xác thực PIN và RPC bật
online giữ hợp đồng cũ.

## Setup và triển khai

- Chỉ thay Flutter client; không cần migration, deploy Edge Function, đổi RLS,
  cron, Redis, R2, biến môi trường hoặc secret.
- Endpoint đang triển khai đã được kiểm tra chỉ đọc: có `force_pg_sync` và
  `pg_updated`. Nếu môi trường khác dùng Edge cũ, fallback latest vẫn có xác nhận.
- Thêm khai báo dev dependency `fake_async: 1.3.3` để test timer tất định; phiên
  bản này đã có trong lockfile qua Flutter test. Không thêm runtime dependency.
- Chạy `flutter pub get` ở workspace, hot restart app tài xế hoặc phát hành bản
  Flutter mới. Hot reload đơn thuần không bảo đảm thay provider đang sống.
- Người vận hành cấp quyền vị trí và bật GPS chính xác cho thiết bị/trình duyệt.
  Code không thể tự khôi phục quyền bị người dùng từ chối.

## Kiểm chứng

Lượt cuối: 51 test trong 12 file liên quan đều đạt; `flutter analyze --no-pub`
trên 17 file vừa sửa không có vấn đề. Không dùng kết quả test giả lập để khẳng
định GPS thiết bị thật hoặc mạng luôn khả dụng.

Test tập trung nằm ở `driver_presence_sync_test.dart`,
`driver_presence_session_test.dart`, `driver_presence_host_test.dart`,
`driver_presence_pin_test.dart`, `location_service_recovery_test.dart` và
`driver_online_gps_quality_test.dart`. Các seam sử dụng provider/widget thật,
mock HTTP cho ingest, plugin GPS kiểm soát được và thời gian giả cho timer.

Bao phủ đứng yên 10 phút, mất/khôi phục quyền hoặc stream, GPS kém/cũ, mạng
lỗi rồi hồi phục, HTTP 200 chưa ghi PG, UPDATE 0 dòng, acquisition treo,
resume sau ngủ, logout trong lúc GPS về muộn, đổi idle → active → idle,
lỗi danh sách đơn và GPS tại thời điểm xác nhận PIN. Các test cadence,
publisher hai đơn, drawer, cold start và online RPC hiện có được chạy kèm.

Trước khi bỏ thẻ, widget cảnh báo từng được render ở 320×568, 390×844 và
1024×768 với chữ 160%. Ảnh lịch sử: `artifacts/driver_online_presence_warning.png`.
Kiểm chứng hiện hành của host không cảnh báo xem `driver_presence_background.md`.
Chưa kiểm chứng E2E hai tài khoản thật hoặc thiết bị ngoài thực địa; công cụ
điều khiển máy không truy cập được phiên trình duyệt trong lần sửa này.
Không chạy full suite hoặc build phát hành.

## Xử lý sự cố và khôi phục

Đọc `offered_driver_id` trước. Nếu trống, kiểm tra tuổi `location_updated_at`,
khoảng cách tới điểm lấy, khóa nhận đơn, ví, phê duyệt, nhiệm vụ hiện tại và hạn
tìm tài xế. Nếu có lời mời còn hạn mới kiểm tra subscription/UI lời mời.

Mất GPS/mạng được tự thử lại ở nền; quyền bị chặn cần người dùng cấp lại.
Trình duyệt nền bị throttle hoặc app bị hệ điều hành kill không bảo đảm chạy
timer. Khi mở lại, app kiểm tra vị trí mới; tài xế ở ngoài bán kính vẫn không
nhận được lời mời tự động. Đây là điều kiện phân công, không phải lỗi heartbeat.

Không đổi GPS cũ thành timestamp mới, không nới bán kính hoặc sửa đơn thật để
ép matching. Đơn hết hạn dùng luồng tìm tài xế lại có sẵn từ tài khoản khách.
Kiểm tra chỉ đọc lúc 12:40 ngày 03/11: GH-10533 đã được server đánh dấu hết hạn
lúc 12:29:12; không còn tự nhận lời mời trong lượt tìm cũ.
Rollback bằng bản Flutter trước; không cần khôi phục dữ liệu server. Không quay
lại một ngưỡng 50 m chung cho discovery và bằng chứng giao nhận.
