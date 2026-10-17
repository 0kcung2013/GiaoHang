# Kiểm tra lỗi luồng nhận, giao và hoàn hàng — 2026-10-13

## Nguyên nhân đã tái hiện

### Xác nhận đến điểm lấy kéo tọa độ về đầu tuyến demo

Log Supabase ghi nhận `PICKUP_OUTSIDE_GEOFENCE` trong
`confirm_driver_pickup_arrival` khi gạt xác nhận. Vị trí mới nhất của đơn lỗi
cách điểm lấy khoảng 426 m và trùng với điểm đầu của tuyến `approach`.

Commit `8e1ce3f` bổ sung phần khởi tạo vị trí demo trong `_loadRoute` của
`driver_navigation_screen.dart`. Sau khi tài xế vào bán kính 100 m nhưng chưa
đi hết tuyến, `_confirmPickupArrival` chuyển `assigned` sang `picking_up`.
`_advanceOrderStatus` đặt lại `_simRouteIndex = 0`, dừng mô phỏng và tải lại
tuyến. Điều kiện khởi tạo demo lại thỏa mãn, nên `_driverPos` bị đặt về
`profile.points.first` trước khi truyền tọa độ vào RPC xác nhận đến nơi.

Test widget có tuyến ETA demo và kiểm tra tọa độ tại RPC đã tái hiện đúng
thông báo lỗi trước khi sửa. Bản sửa đánh dấu phần khởi tạo vị trí đã chạy,
giữ nguyên tọa độ khi chuyển bước và khi thử lại.

### Phiên hoàn mô phỏng bị tọa độ profile cũ ghi đè lúc xác nhận

Luồng khôi phục hành trình trong `8e1ce3f` giữ được vị trí cuối khi mở lại
màn hoàn, với nguồn `restoredSession`. Tuy nhiên,
`ReturnConfirmationPositionPolicy` vẫn chọn đọc lại profile server cho nguồn
này. Khi profile chậm đồng bộ, xác nhận hoàn dùng điểm đầu cũ và bị chặn dù
bản đồ đã ở điểm trả.

Test mới chạy đến điểm trả, khởi động lại container/provider, mở lại màn
hoàn và xác nhận với profile cũ đã tái hiện lỗi. Bản sửa giữ vị trí phiên
mô phỏng đã được khôi phục đúng đơn, chặng và chế độ GPS. GPS thiết bị tiếp
tục lấy mẫu mới khi xác nhận; nguồn profile hoặc vị trí dự phòng vẫn được
kiểm tra bằng nguồn server/GPS tương ứng.

### Hai sai lệch trong kiểm tra đã đến

- `Distance()` mặc định làm tròn: điểm cách 100,2 m được xem như 100 m ở
  client, nhưng nằm ngoài geofence của server. Kiểm tra nhận/giao giờ dùng
  khoảng cách chưa làm tròn.
- Cờ `arrivedAtTarget` được giữ dù tọa độ của phiên lưu hoặc mẫu tiếp theo
  nằm ngoài bán kính. Cờ đến nơi và kết thúc tuyến được đối chiếu lại với
  tọa độ hiện tại khi khôi phục; mẫu vị trí mới cũng cập nhật lại cờ đến nơi.

Cả hai có test thất bại trước khi sửa. Không nới bán kính xác nhận.

## UI và test được cập nhật

- Vùng chụp ảnh nhận/giao/hoàn cho phép tiêu đề và hướng dẫn xuống dòng,
  tăng chiều cao theo nội dung khi chữ phóng lớn. Ảnh đã chụp vẫn có khung
  riêng hữu hạn; chuyển trạng thái ảnh không nội suy ràng buộc vô hạn.
- Bảng thao tác hoàn có thể cuộn khi màn hình ngắn hoặc thông báo lỗi dài.
- Mock broadcast bổ sung `speedKmh`; mock nhận lời mời dùng provider nhận
  đơn hiện tại để tiếp tục kiểm tra lỗi/race khi Realtime gỡ lời mời.
- Test GPS demo cập nhật tọa độ đang được cấu hình; test chuyển nhận hàng
  cập nhật theo luồng chuyển sang giao ngay và cho phép thử lại nếu gián đoạn.
- Test lọc số dư phân công dùng `private.road_driver_candidates` hiện tại.
- Test SQL hủy đơn mô phỏng bước commit road quote sau khi xếp hàng phân công,
  thay cho giả định cũ rằng hủy sẽ tạo lời mời đồng bộ bằng khoảng cách thẳng.

## Phạm vi kiểm chứng

Kết quả lượt kiểm tra cuối: **298 test đạt trong 62 file test liên quan**;
`flutter analyze --no-pub` trên **15 file Dart đã sửa** không có issue.
`git diff --check` trên các file sửa không có lỗi whitespace.

Để tránh lặp lại lỗi, test phải kiểm tra tọa độ thực truyền vào RPC khi
chuyển bước, thay vì mock luôn thành công. Test khôi phục hành trình hoàn
phải đi tiếp tới xác nhận trả hàng, bao gồm trường hợp profile chưa đồng bộ.

Widget/service tests bao phủ nhận lời mời, hết hạn, Realtime gỡ lời mời,
đến điểm lấy, chụp bằng chứng, chuyển giao, thử lại khi lỗi mạng, đi đến
điểm giao, hoàn tất và xóa phiên; đơn thường, demo mới, phiên khôi phục và
phiên có cờ đến nơi sai. Kiểm tra viewport 320×568, 390×844 và 900×700;
luồng hoàn cũng kiểm tra chữ phóng lớn, khởi động lại, profile chậm đồng bộ,
hủy hoàn và xác nhận trả hàng.

Năm bộ SQL đã chạy thành công trên backend hiện tại với fixture thử và
`ROLLBACK`:

- `driver_cancellation_regression.sql`
- `driver_delivery_arrival_wait_regression.sql`
- `driver_return_redelivery.sql`
- `paid_goods_driver_deposit_regression.sql`
- `customer_wallet_prepaid_delivery_regression.sql`

Các bộ SQL kiểm tra quyền tài xế, geofence, thời gian chờ, bằng chứng,
giao/hoàn/hủy hoàn, tiền COD/ký quỹ và tính không lặp của quyết toán ví.
Không có thay đổi schema, RLS, migrations, Edge Functions hay pipeline lưu
GPS/R2 trong bản sửa này.

Chưa chạy GPS/camera trên Android/iOS thật, chuyến giao thật, build phát hành
hoặc toàn bộ test suite của monorepo. Với app đang mở, hot restart rồi mở
lại đơn; nếu phiên cũ lưu vị trí đầu tuyến, chạy lại chặng đến điểm lấy.
