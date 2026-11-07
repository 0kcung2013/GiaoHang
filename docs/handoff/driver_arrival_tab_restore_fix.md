# Nút Đã giao hàng mờ sau khi đổi tab — 2026-10-30

> Luồng hiện tại được cập nhật trong [GPS chung và chuyển tuyến giao lại](driver_shared_gps_routing.md).
> Không còn dùng capture lưu riêng của đơn để seed vị trí khi mở màn; chờ capture
> chung mới để xác định vùng đến nơi. Phần bên dưới ghi lại bản sửa trước đó.

## Nguyên nhân

Nhánh khôi phục điều hướng của đơn từng được giữ chủ động bỏ tọa độ riêng của
đơn để tránh kéo GPS về đơn cũ, nhưng cũng xóa `arrivedAtTarget` và
`routeCompleted`. Khi mở lại màn hình, vị trí dùng chung được nạp bằng nguồn
`restoredSession`, vốn không được tự xác nhận đã đến nơi. Vì thế nút bị khóa
dù tài xế vẫn đang ở điểm giao. Cờ sai còn được lưu lại khi rời màn hình.

Đối chiếu qua MCP cho GH-10478: GPS server lúc kiểm tra cách điểm giao khoảng
0,76 m, có mẫu giám sát mới. Không cần sửa tọa độ hoặc trạng thái đơn trên DB.

## Cách sửa

- Giữ một `DriverArrivalFix` theo tài xế trong phiên app: tọa độ, thời điểm lấy
  mẫu, độ chính xác, mode và mã kịch bản demo nếu có. Chỉ GPS hợp lệ hoặc nguồn
  mô phỏng đang chạy mới tạo mẫu này; tọa độ khôi phục riêng của đơn không tạo
  bằng chứng mới. Cache tự giải phóng khi Driver Shell đóng/đăng xuất.
- Mở lại màn hình thì đánh giá bán kính 100 m bằng mẫu hợp lệ gần nhất và vị
  trí vật lý dùng chung. Không giữ cờ đến nơi nếu vị trí mới đã đi xa, mode hoặc
  kịch bản demo khác. Có thể sửa lại cờ đã bị phiên bản cũ xóa nhầm.
- Khi chạy lại app và cache trống, đọc các trường đã có trong
  `orders.driver_monitoring`: `last_lat`, `last_lng`, `last_accuracy`,
  `last_captured_at`. Chỉ dùng đúng tài xế được phân công, chưa bị thu hồi, đúng
  mode, mẫu còn mới và sai số <=50 m. Không dùng giờ nhận mẫu/cập nhật hồ sơ để
  biến một tọa độ cũ thành GPS mới. Domain model được bổ sung parse/serialize
  các trường hiện có này; không thêm database fields.
- Heartbeat mô phỏng đứng yên có thể ghi nhận mẫu mô phỏng mới khi vị trí và
  mode không đổi. Nhánh đó không làm mới timestamp của GPS thiết bị thật hoặc
  khôi phục vị trí của đơn khác.
- Giữ kiểm tra mẫu cũ quá 90 giây/tương lai quá 15 giây, sai số tối đa 50 m và
  vùng đến nơi 100 m. GPS online sai số đến 200 m không trở thành bằng chứng
  giao hàng. Quyền xác nhận và bằng chứng bàn giao trên backend giữ nguyên.

## Setup và triển khai

Không có dependency, biến môi trường, secret, migration, RPC hoặc thay đổi
pipeline R2 mới. Thay đổi nằm trong `giaohang_mobile` và parser của
`giaohang_domain`. Hot restart/chạy lại app tài xế để nạp mã mới; không cần
gia hạn, hủy hoặc tạo lại đơn. Không tự đánh dấu đã giao.

## Kiểm chứng

- Test tái hiện màn điều hướng thực tế cho kết quả `[false, false, false]`
  trước sửa dù đã đến điểm giao. Sau sửa mở/đóng màn ba lần vẫn giữ đúng trạng
  thái và kiểm tra trực tiếp khả năng gạt của `DriverSwipeAction` sau khi có
  snapshot đến nơi từ server.
- Các trường hợp: GPS thật và mô phỏng ở đích, cờ cũ đã bị xóa, chạy lại app
  bằng mẫu giám sát server, mẫu cũ, mode thay đổi, và tài xế chuyển sang điểm
  giao khác. Trường hợp không hợp lệ vẫn khóa nút.
- Kiểm tra riêng mô phỏng đứng yên không làm mới GPS thật; tuổi GPS được tính
  theo `last_captured_at` chứ không phải `last_received_at`.
- 41 test mobile trong 6 file và 7 test domain đạt; analyze 8 file thay đổi
  không có vấn đề. Log cục bộ: `artifacts/driver_arrival_restore_checks.log`.
- Chưa kiểm thử điện thoại thật hoặc thao tác xác nhận giao trên đơn thật;
  không chạy full suite/build phát hành. Test không thu tiền hoặc hoàn tất đơn.

Khi nút tiếp tục bị khóa, kiểm tra nguồn mẫu, tuổi mẫu và khoảng cách thật
trước. Không bật cố định cờ đã đến nơi, không tăng bán kính và không lấy tọa
độ điểm giao làm vị trí tài xế để mở nút.
