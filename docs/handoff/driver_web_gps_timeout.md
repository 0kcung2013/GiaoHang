# GPS Web chờ lâu và thông báo sai nguyên nhân — 2026-11-03

Cập nhật giao diện tiếp theo cùng ngày: bỏ thẻ cảnh báo GPS tự xuất hiện trên
các tab tài xế; xem [GPS nền không chèn cảnh báo](driver_presence_background.md).
Thông tin chẩn đoán vẫn có trong màn Kiểm tra vị trí khi người dùng chủ động mở.
Luồng lấy vị trí để bật Online có request riêng 30 giây sau bản sửa tiếp theo;
xem [GPS trong xác thực Online](driver_online_pin_location.md). Deadline đọc
thông thường/màn kiểm tra bên dưới vẫn là 8 giây.

## Bằng chứng

Người dùng xác nhận quyền vị trí của trình duyệt và Dịch vụ vị trí Windows
đều đã bật. Không đọc được trực tiếp phiên Chrome vì Computer Use không kết
nối được native pipe; không khẳng định nguồn định vị trên máy đã hoạt động lại.

Đo kết nối cơ bản tới `/auth/v1/health` của Supabase không kèm key: HTTP 401,
TLS khoảng 0,15 giây, tổng 0,46 giây. Đây chỉ là phép đo đường kết nối, không
đại diện cho RPC, phiên đăng nhập hoặc dịch vụ định vị của trình duyệt.

Trong package thực tế cài từ lockfile (`geolocator_web 4.1.4`), file
`lib/src/html_geolocation_manager.dart` dùng `timeout.inMicroseconds` cho
`PositionOptions.timeout`, trong khi browser dùng millisecond. Ví dụ timeout
15 giây trở thành 15.000.000 ms (4 giờ 10 phút). Web `requestPermission()`
cũng gọi một lần lấy vị trí trước khi trả về; luồng cũ không chặn thời gian
của toàn bộ thao tác này.

Màn **Kiểm tra vị trí** trước đó đọc profile qua mạng rồi mới xin GPS, đặt
email khi mọi bước đã xong và gộp mọi lỗi thành nhắc bật GPS/cấp quyền. Vì vậy
skeleton không cho biết đang chờ server hay định vị. Test trước sửa đã tái
hiện acquisition không kết thúc sau 8 giây và hai caller tạo hai request.

## Thay đổi client

- `LocationService` giới hạn toàn bộ acquisition ở 8 giây bằng deadline Dart.
  Web dùng `getPositionStream` cho một lần đọc rồi hủy subscription khi có kết
  quả/lỗi/timeout; không dùng one-shot Web mang lỗi đơn vị hoặc thêm một lần
  gọi vị trí qua `requestPermission`. Watch của browser tự xử lý quyền hiện có.
- Caller đồng thời dùng chung Future. Nếu đang tracking, acquisition nghe
  capture của watch hiện có, không mở thêm một nguồn đo. Mẫu cache tối đa 5
  giây giữ nguyên timestamp và accuracy; không dùng GPS cũ hoặc tọa độ server
  để giả vị trí hiện tại.
- Watch nền vẫn được giữ để lấy fix đầu, kể cả khi màn kiểm tra báo timeout sau 8
  giây. Discovery khởi động lại watch sau ba timeout liên tiếp; không liên tục
  ngắt quá trình lấy fix đầu sau mỗi 8 giây. Watch lỗi/kết thúc vẫn phục hồi theo
  cơ chế phiên tài xế đã triển khai trước đó.
- `LocationFailure` phân biệt bị chặn quyền, dịch vụ vị trí tắt, timeout và
  nguồn định vị không cung cấp vị trí. PIN và màn kiểm tra đọc đúng nhóm lỗi.
  Lỗi đồng bộ server vẫn có nhóm riêng; không mặc định kết luận mạng chậm
  hoặc quyền chưa được cấp từ một kết quả null.
- Màn kiểm tra lấy GPS và profile song song. Profile vẫn là lần đọc mới để đối
  chiếu dữ liệu server; không dùng cached profile làm bằng chứng đã đồng bộ.
  Hai bước có deadline riêng 8 giây. GPS xong được hiển thị độc lập với profile;
  caption email có ngay. Chưa xác minh profile thì các nút áp dụng chế độ bị tắt.
- Đọc địa chỉ chỉ chạy sau tọa độ, không chặn kết quả GPS. Các bước ghi/đọc lại
  khi áp dụng chế độ cũng có timeout; chế độ chỉ đổi sau xác nhận server như cũ.

Không đổi ngưỡng discovery 200 m, giao nhận 50 m, bán kính phân công, schema,
RPC, RLS, Edge Functions, cấu trúc Redis hoặc pipeline R2.

## Setup và kiểm tra

Không có dependency, environment variable hoặc secret mới trong lần bổ sung
này. `fake_async 1.3.3` đã được khai báo ở lần sửa phiên GPS trước. Không sửa
package trong pub-cache và không cần upgrade geolocator hoặc apply migration.
Cần hot restart app hoặc phát hành client mới; provider đang sống có thể vẫn
giữ mã cũ sau hot reload đơn thuần.

Test trọng tâm: `location_acquisition_timeout_test.dart` và
`driver_gps_debug_loading_test.dart`. Kiểm chứng timeout khi plugin/permission
treo, hủy watch thật qua fake platform, chia sẻ acquisition/watch trên Web và
native, tái dùng capture mới, phục hồi watch đứng, phân loại lỗi, GPS không chờ
profile và dừng skeleton sau deadline. Chạy kèm các test phiên GPS, PIN,
publisher đơn đang giao, chất lượng GPS và thao tác chế độ.
Lượt cuối: 40 test tập trung trong 9 file đều đạt; analyze 15 file vừa sửa
không có lỗi. Không cộng gộp số này với các lượt test trước trong hội thoại.

Widget lỗi được render ở 320×568 và 390×844, chữ 160%; ảnh:
`artifacts/driver_gps_timeout_diagnostic.png`. Chưa chạy E2E trên Chrome của
người dùng, GPS ngoài thực địa hoặc full suite/build phát hành.

## Vận hành và giới hạn

Sau restart, mở **Kiểm tra vị trí**. Báo lỗi quyền thì kiểm tra quyền; timeout
hoặc nguồn định vị không trả kết quả thì kiểm tra hệ thống định vị/browser;
lỗi profile/sync thì kiểm tra kết nối server. Không thay GPS bằng demo hoặc
nới sai số để che lỗi thiết bị. Bật quyền không bảo đảm nguồn định vị luôn
trả tọa độ; máy tính có thể không có nguồn GPS chính xác.

Deadline là thời gian app đang chạy; tab nền hoặc hệ điều hành đình chỉ có
thể trì hoãn timer. Việc kết thúc chờ sau 8 giây không hứa có fix hợp lệ trong
8 giây. Không tự thay cài đặt Windows, trình duyệt, proxy/VPN hoặc mạng của
người dùng.

Rollback bằng bản Flutter trước, không có dữ liệu server cần phục hồi. Giữ
đúng timestamp capture và ngưỡng chất lượng khi điều chỉnh client.
