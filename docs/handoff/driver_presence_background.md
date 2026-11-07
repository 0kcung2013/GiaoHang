# GPS nền không chèn cảnh báo — 2026-11-03

Lỗi GPS xuất hiện trong cửa sổ PIN Online sau đó được sửa riêng tại
[driver_online_pin_location.md](driver_online_pin_location.md).

## Thay đổi theo yêu cầu

Đã xóa widget `DriverPresenceNotice`, thẻ viền vàng **Chưa sẵn sàng nhận đơn**,
trạng thái **Đang cập nhật vị trí** và nút **Thử lại GPS** tự chèn lên các tab
tài xế. Không thay bằng banner, snackbar hoặc popup tự hiện khác.

Thẻ cũ xuất hiện khi phiên discovery chưa ở trạng thái `ready`, gồm lúc bắt
đầu, GPS timeout sau 8 giây, mất quyền, độ chính xác kém hoặc lỗi đồng bộ. Đây
là lý do nó tiếp tục xuất hiện khi browser chưa trả được mẫu GPS; ảnh người
dùng không đủ để xác định lỗi nguồn định vị cụ thể của máy.

`DriverOnlinePresenceHost` hiện chỉ quản lý vòng đời: giữ trực tiếp
`driverPresenceSessionProvider` khi tài xế bật nhận đơn và chưa có nhiệm vụ
chiếm quyền GPS, rồi trả nguyên widget nội dung. Không dựng layout hoặc
subscribe các thay đổi trạng thái chỉ để render cảnh báo. GPS vẫn lấy vị trí,
tự thử lại, khởi động lại watch đứng và refresh khi quay lại app như trước.
Nhận nhiệm vụ thì dừng GPS chờ đơn; hoàn thành nhiệm vụ thì khởi động lại.

Không sửa timeout, chất lượng GPS, phân loại lỗi, điều kiện matching hoặc xác
nhận vị trí server. Việc bỏ thẻ không tự làm GPS chưa hợp lệ thành sẵn sàng.
Thông tin vị trí vẫn xem được khi chủ động mở **Kiểm tra vị trí** ở bản debug;
validation GPS khi bật nhận đơn/giao nhận vẫn dùng luồng hiện có.

## Setup và khôi phục

Chỉ thay Flutter client; không thêm dependency, biến môi trường, secret,
migration hoặc deploy backend. Cần hot restart app tài xế hoặc phát hành
client mới. Không cần xóa dữ liệu đăng nhập, reset ví hoặc sửa trạng thái đơn.

Nếu cần khôi phục cách hiển thị cũ, khôi phục riêng widget cảnh báo và các
string đi kèm, giữ phần provider/vòng đời GPS đang hoạt động. Không gỡ host
khỏi Driver Shell vì GPS chờ đơn cần sống qua chuyển tab và lỗi tải nội dung.

## Kiểm chứng

`driver_presence_host_test.dart` tái hiện thẻ đúng trạng thái `gpsTimedOut`
trên Galaxy S20 trước sửa. Sau sửa, kiểm tra mọi giá trị `DriverPresenceStatus`
tại 320×568, Galaxy S20 360×800 và 1024×768, chữ 160%: không có thẻ, nút retry
hoặc khoảng trống đẩy nội dung xuống. Test provider/vòng đời hiện có vẫn xác
nhận GPS hoạt động khi nội dung lỗi, refresh khi resume, dừng/chạy lại theo
nhiệm vụ. Screenshot harness: `artifacts/driver_presence_without_banner.png`;
đây là nội dung thử của host, không phải ảnh dashboard đăng nhập thật.

Chạy tập trung `driver_presence_host_test.dart`, `driver_presence_session_test.dart`
và `location_acquisition_timeout_test.dart`: 22 test đạt. Analyze bốn file Dart
thay đổi không có lỗi. Các test timeout và session xác nhận tự thử lại/phục
hồi GPS còn hoạt động. Không chạy full suite, build phát hành, E2E Chrome của
người dùng hoặc kiểm chứng nguồn GPS ngoài thực địa.
