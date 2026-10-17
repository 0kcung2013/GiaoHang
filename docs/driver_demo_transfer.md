# Demo chuyển đơn tại TP.HCM

Tuyến demo hiện tại lấy hàng tại **Cửa hàng Thiên Anh · 19A Linh Đông**
`(10.8456193, 106.7459414)`, giao tại **Co.op Food · 103 Linh Đông**.
Hai lựa chọn Cao điểm và Ngoài cao điểm dùng cùng tọa độ lấy/giao.

## Vị trí tài xế

Tọa độ được khai báo tập trung trong
`apps/delivery_app/lib/core/utils/geo_utils.dart`.
OSRM xác nhận ngày 2026-10-12:

| Tài khoản | GPS demo TP.HCM | Quãng đường đến điểm lấy |
| --- | --- | --- |
| `taixe@gmail.com` | `(10.849230, 106.747293)` | 425,8 m |
| `taixe2@gmail.com` | `(10.850616, 106.747684)` | 584,6 m |
| `taixe3@gmail.com` | `(10.852000, 106.748100)` | 744,2 m |

Cả ba nằm trên đường Linh Đông, có quãng đường tăng dần và đều trong giới hạn
**2 km đường bộ** của phân công tự động. Tọa độ cũ của `taixe2` và `taixe3`
cách điểm lấy lần lượt 9,45 km và 17,62 km đường bộ, nên không được mời sau khi
`taixe` chuyển đơn. Fixture OSRM nằm tại
`apps/delivery_app/test/fixtures/traffic_demo_transfer_dispatch.json`.

## Cách thử

1. Chạy lại/hot restart Delivery App trên các phiên tài xế để nạp tọa độ mới.
2. Dùng ba phiên đăng nhập riêng cho ba tài khoản. Trong **Kiểm tra vị trí**,
   chọn **Dùng vị trí demo TP.HCM** trên từng phiên và chờ thông báo đồng bộ
   thành công. Thao tác này gửi vị trí mới qua pipeline hiện có và kiểm tra
   vị trí đã lưu trên server.
3. Bật **Online** cho cả ba, giữ ứng dụng hoạt động và cấp quyền GPS. Tài xế
   phải đã được duyệt, không có đơn đang giao/trả, không có lời mời khác và
   không đang khóa nhận đơn. Ví phải đủ phần ứng hàng/giữ COD của đơn thử;
   có thể chọn đơn thử không yêu cầu phần giữ này để kiểm tra vị trí trước.
4. Khách tạo **đơn mới** với một trong hai tuyến demo Linh Đông. Chờ lời mời
   tới `taixe@gmail.com`, bấm **Chuyển đơn** trong thời hạn lời mời. Đây là
   chuyển lời mời trước khi nhận đơn.
5. Chờ bộ phân công gửi lời mời tới `taixe2@gmail.com`. Tiếp tục chuyển từ
   `taixe2` để nhận lời mời tại `taixe3`, rồi nhận đơn tại `taixe3`.

GPS dùng để phân công phải mới trong **3 phút**. Các phiên online gửi heartbeat
qua luồng hiện có; đóng app hoặc không lấy được GPS có thể làm tài xế bị loại.
Tài xế đã chuyển bị loại khỏi lời mời tiếp theo của cùng đơn. Bộ phân công đường
bộ chạy bất đồng bộ, vì vậy cần chờ lời mời mới sau khi bấm chuyển.

Chuyển/bỏ qua **4 đơn khác nhau trong 30 phút** vẫn khóa nhận đơn mới 30 phút
theo quy tắc hiện có. Demo nhiều lượt phải tính đến giới hạn này.

## Kiểm thử tập trung

Chạy từ `apps/delivery_app`:

```powershell
flutter test --no-pub test/geo_utils_test.dart test/driver_location_mode_test.dart test/traffic_demo_driver_availability_test.dart
node --test test/traffic_demo_transfer_dispatch_test.mjs
```

Flutter kiểm tra GPS thực sự được resolve cho các tài khoản và đối chiếu với
fixture đường bộ. Node dùng hàm xếp hạng của dispatcher để replay thứ tự mời
sau mỗi lần loại tài xế đã chuyển. Các test này không gọi RPC chuyển đơn trên
database đang chạy.
