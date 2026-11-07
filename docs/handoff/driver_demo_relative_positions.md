# Nhóm vị trí demo quanh GPS hiện tại và TP.HCM

Triển khai frontend ngày 2026-11-03, theo yêu cầu: `taixe` giữ điểm gốc,
`taixe2` và `taixe3` lệch quanh điểm đó. Người dùng chọn chế độ riêng trên
từng phiên tài xế; không tự chuyển tài xế theo thao tác ở app khách.

## Hai chế độ

| Chế độ | taixe | taixe2 | taixe3 |
|---|---|---|---|
| Demo hiện tại, mặc định build demo | GPS hiện tại | GPS + độ lệch khoảng 160 m | GPS + độ lệch khoảng 320 m |
| Demo TP.HCM, chọn riêng từng phiên | 10.849230, 106.747293 | 10.850616, 106.747684 | 10.852000, 106.748100 |

`GeoUtils.applyCurrentPositionDriverOffset` dịch cả bố cục nhóm TP.HCM về GPS
thiết bị: độ lệch của mỗi tài khoản là chênh lệch lat/lng với `taixe` trong
`testDriverDemoPositions`. Vì vậy tài xế 1 giữ chính xác GPS đầu vào, khoảng
cách giữa các tài xế tương tự nhóm TP.HCM, và điểm gốc thay đổi thì cả nhóm
di chuyển theo. Tên tài khoản được trim và so sánh không phân biệt hoa thường.
Tài khoản ngoài ba email demo không nhận độ lệch.

Đây là cự ly địa lý xấp xỉ tại Việt Nam, không bảo đảm điểm dịch nằm đúng tim
đường. Phân đơn vẫn xét khoảng cách đường bộ OSRM, bán kính, GPS mới, ví, khóa
nhận đơn và nhiệm vụ hiện có. Không sửa thứ tự xếp hạng ở backend. Nhóm TP.HCM
giữ nguyên tọa độ và fixture thứ tự `taixe → taixe2 → taixe3` của tuyến Linh Đông.

## Đồng bộ vị trí

`LocationIngestCoordinateSpace.currentDemoGps` phân biệt GPS cần dịch quanh vị
trí hiện tại với GPS cần đưa về nhóm TP.HCM và tọa độ map/server đã xử lý.
Phép dịch áp dụng đúng một lần tại ranh giới GPS:

- Bật nhận đơn bằng PIN: vị trí publish và tham số RPC online dùng cùng điểm.
- Heartbeat chờ đơn: vị trí server, marker chung và fix dùng cùng điểm đã dịch.
- Màn kiểm tra: map so sánh GPS thiết bị với điểm demo của chế độ đang chọn;
  đối chiếu server theo điểm đã dịch, không so với GPS thô của tài xế 2/3.
- Mô phỏng đã di chuyển, vị trí server và session dùng `mapCoordinates`, không
  cộng lại độ lệch mỗi tick hoặc mỗi lần mở map.

Nguồn GPS vẫn giữ timestamp/accuracy và kiểm tra độ mới như trước. Fix của chế
độ demo được đánh dấu simulated. Không thay quy tắc bằng chứng GPS thực tế.
Khi đổi chế độ có chủ đích và server xác nhận, marker chung chuyển tới điểm
đã chọn; fix cũ bị xóa để không khôi phục chứng cứ của chế độ trước.

## Setup và mặc định

- Không thêm dependency, biến môi trường hoặc secret. Tiếp tục dùng flag
  `ENABLE_TEST_DRIVER_OFFSETS`, mặc định true trong build phục vụ demo.
- Khi chưa có lựa chọn được lưu, build demo bắt đầu ở `demoCurrentPosition`.
  Với `--dart-define=ENABLE_TEST_DRIVER_OFFSETS=false`, mặc định là `deviceGps`
  và cả hai phép dịch tọa độ đều bị tắt.
- Giữ lựa chọn đã lưu trong `driver.location_mode.v1`. Phiên từng lưu GPS thật
  vẫn dùng GPS thật; chọn **Mô phỏng từ vị trí hiện tại** một lần nếu muốn demo.
  Phiên đã chọn TP.HCM vẫn giữ TP.HCM sau restart.
- Ba phiên đăng nhập nên chạy trên cùng máy để cùng dùng một GPS nền. Nếu chạy
  trên các thiết bị khác nhau thì mỗi thiết bị có GPS nền riêng; chọn nhóm
  TP.HCM để có các điểm cố định chung khi trình diễn.
- Cần hot restart app tài xế hoặc phát hành client mới. Không cần migration,
  deploy Edge Function hoặc chỉnh tay dữ liệu tài xế trên server.

## Kiểm tra và khôi phục

Test `driver_demo_relative_positions_test.dart` kiểm tra mốc hiện tại, khoảng
cách và việc dịch cả nhóm; `driver_demo_position_pipeline_test.dart` đi qua
auth fixture, service bật online, provider heartbeat và HTTP ingest cho cả ba
tài khoản ở ba chế độ. Kiểm tra marker, tham số online và điểm server khớp nhau,
và tọa độ map không bị cộng độ lệch lần nữa.

Các test GeoUtils, lưu chế độ, dashboard, navigation source, nhận lời mời,
publisher, chất lượng GPS và widget chọn chế độ chạy kèm. Replay Node dùng
dispatcher thật với fixture OSRM để kiểm tra thứ tự mời ở nhóm TP.HCM.
Kết quả cuối: 55 test Flutter tập trung trong 14 file và 1 test riêng với flag
demo tắt đều đạt; 1 replay Node đạt; analyze 19 file không có vấn đề.

Kiểm tra riêng build tắt demo:

```powershell
flutter test --no-pub --dart-define=ENABLE_TEST_DRIVER_OFFSETS=false test/driver_demo_production_flag_test.dart
```

Widget được render ở 320×568 và 390×844, chữ 160%; ảnh kiểm tra:
`artifacts/driver_demo_relative_controls.png`. Chưa chạy E2E ba tài khoản thật
hoặc full suite/build phát hành trong lần sửa này.

Nếu hai tài xế vẫn trùng vị trí, kiểm tra chế độ đã lưu, flag build, đúng email
tài khoản và tuổi GPS. Nếu marker khác tọa độ server, chờ heartbeat xác nhận
hoặc chọn lại chế độ; không cập nhật tay timestamp/lat/lng để ép phân công.
Rollback bằng bản Flutter trước; lựa chọn lưu không thay key/schema và không
có dữ liệu server cần migrate ngược.
