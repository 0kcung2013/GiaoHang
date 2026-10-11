# Demo ETA, vận tốc và màu tuyến

Đã áp dụng SQL và triển khai theo chấp thuận của người dùng ngày 2026-10-11.
Không thêm bảng. `orders.traffic_demo_key` giữ lựa chọn của khách;
`orders.delivery_eta` hiện có giữ hai tuyến OSRM và profile vận tốc đã tính.

## Hai lựa chọn trên cùng tuyến

| Lựa chọn | Giờ đầu vào AI | Vận tốc trung bình dữ liệu | Màu dự kiến |
| --- | --- | --- | --- |
| Cao điểm | 07:00 | 29,998 km/h | Cam |
| Ngoài cao điểm | 14:00 | 50,000 km/h | Xanh lá |

Hai lựa chọn dùng cùng điểm lấy `(10.784900, 106.668400)` và điểm giao
`(10.793838, 106.651842)`. Giờ AI dùng ngày thứ Tư 2024-04-03 trong dữ liệu nguồn;
thời điểm nhận đơn, ETA giao thực tế, hạn giao và giám sát vẫn dùng giờ server.
Lựa chọn được lưu cùng đơn, không phụ thuộc trạng thái màn hình tạo đơn của khách.

Lệnh đối chiếu giờ bằng dữ liệu đã chuẩn bị:

```powershell
python experiments/smarttraffic_eta/audit_demo_hours.py
```

Báo cáo nằm ở `output/smarttraffic_eta/full_model/traffic_demo_hours.json`.
Trung bình được tính có trọng số theo số bản ghi Motorbike hợp lệ, trên toàn bộ
nhãn tuyến/thời gian, không lấy trung bình đơn giản giữa các tuyến.

## Cách vận hành

1. Hot restart hoặc chạy lại Delivery App để nạp code mới.
2. Tài xế mở công cụ GPS, chọn **Dùng vị trí demo TP.HCM** trước khi nhận đơn.
   Với `taixe@gmail.com`, vị trí cấu hình là `(10.7790, 106.6765)`.
3. Khách tạo **đơn mới**, chọn Cao điểm hoặc Ngoài cao điểm; tài xế nhận đơn.
   Chờ ETA xuất hiện rồi ghi lại ETA ban đầu.
4. Tài xế mở **Xem bản đồ**, bấm **Start**. Marker tròn di chuyển theo vận tốc
   đã lưu của phần tuyến hiện tại; nhãn km/h và màu tuyến dùng cùng profile đó.
   Khách thấy vị trí và tốc độ qua realtime.
5. Bấm **Stop**: vị trí giữ nguyên, tốc độ về 0 km/h. Start tiếp tục từ vị trí
   đang dừng. Mẫu vị trí mới vẫn được gửi khi app hoạt động để giám sát không
   nhầm đứng yên thành mất GPS.
6. Đến hết chặng lấy hàng: tự dừng. Xác nhận nhận hàng và chuyển chặng bằng luồng
   hiện có, rồi Start chặng giao. Không tự xác nhận nhận/giao hàng.

Không tăng tốc thời gian: 30 km/h tương ứng khoảng 8,33 m/s, 50 km/h khoảng
13,89 m/s. Đóng bản đồ khi đang Start vẫn tiếp tục hành trình ở cấp Driver Shell;
đóng bản đồ khi Stop giữ trạng thái dừng. App đóng hoàn toàn thì không tạo GPS giả
ở nền; quy tắc mất GPS hiện có vẫn có hiệu lực.

## So sánh để bảo vệ đề tài

Hoàn tất hoặc hủy đúng luồng đơn thứ nhất. Trước đơn thứ hai, đặt lại **cùng tài
xế về cùng vị trí demo TP.HCM**, rồi chọn lựa chọn còn lại. Không đổi vị trí khi
đang có đơn. Cùng điểm lấy/giao nhưng khác vị trí tài xế sẽ khác quãng đường đến
điểm lấy, nên không còn là phép so sánh cùng điều kiện.

So sánh ETA **trước Start ở cả hai lượt**, hoặc sau khi cả hai cùng đã được bỏ
5 phút chuẩn bị; không so một lượt trước và một lượt sau điều chỉnh này.

Ví dụ kiểm thử cố định tổng quãng đường 6 km (1 km đến lấy + 5 km giao):

| Chỉ số | Cao điểm | Ngoài cao điểm |
| --- | --- | --- |
| Vận tốc AI trên chặng giao | 30,015 km/h | 49,994 km/h |
| Tổng thời gian chạy hai chặng | 11,994 phút | 7,201 phút |
| ETA ban đầu, gồm 15 phút thao tác | 26,994 phút | 22,201 phút |

Đây là số của fixture kiểm thử; quãng đường OSRM của đơn trên app có thể khác.
AI góp phần trực tiếp vào thời gian di chuyển bằng `km / vận tốc dự đoán × 60`.
Không gán thủ công một số phút khác nhau cho hai lựa chọn, không nhân hệ số K cũ.
25 km/h dùng dự phòng khi AI hoặc phạm vi tuyến không hỗ trợ.

ETA được giữ theo lần phân công. GPS xuất phát sớm hợp lệ chỉ bỏ 5 phút chuẩn bị
đúng một lần. Stop, đến sớm hoặc chuyển chặng không tính lại ETA đã lưu.
Hạn giao giữ **ETA ban đầu + 25 phút**, không thay đổi theo Start/Stop.
Đơn đã có ETA cũ không được tính lại; cần đơn mới để thấy profile mới.

## Thử nghiệm nhiều vận tốc trên cùng tuyến

Đã đọc một tuyến OSRM khác từ `(10.784900, 106.668400)` đến
`(10.850500, 106.742100)`, dài **15.306,1 m**, qua Cách Mạng Tháng Tám,
Phạm Văn Đồng, Cầu Bình Lợi và khu Linh Đông. Dùng cùng geometry cho cả ba lần:

| Thời điểm bắt đầu chặng | Profile AI | Thời gian chạy chặng |
| --- | --- | --- |
| 07:00 | Khoảng 30 km/h suốt tuyến | 30,60 phút |
| 08:55 | Khoảng 30 km/h ở 1,75 km đầu; khoảng 50 km/h phần còn lại | 19,77 phút |
| 14:00 | Khoảng 50 km/h suốt tuyến | 18,37 phút |

Đây là phép đọc OSRM/model độc lập, chưa đổi hai lựa chọn demo trên app.
08:55 là thời điểm bắt đầu **chặng**, không phải thời điểm nhận đơn: công thức
ETA còn dịch thời gian AI theo chuẩn bị, đến điểm lấy và nhận hàng. Điểm chuyển
vận tốc do model suy ra từ nhãn thời gian lấy mẫu, không phải một quy tắc gán
màu tại đúng 09:00. Các con số trên chưa cộng thời gian thao tác hoặc chặng lấy.

Hiện tại đổi tên đường trong cùng giờ không tạo nhiều mức vận tốc rõ rệt,
vì model runtime chỉ học thời gian. Tuyến dài đi qua khoảng chuyển giờ có thể
có hai màu rõ. Muốn nhiều mức do đặc điểm riêng từng đường trong cùng giờ,
cần nhãn có khác biệt giữa các tuyến và một model học thêm đặc trưng tuyến.

Nhãn km/h đã được đặt bên phải icon tài xế với khoảng cách 8 px; kiểm thử vị trí
trên MarkerLayer thực ở 320/390 px và góc xoay bản đồ 0/90 độ đạt.

## Giới hạn và kiểm chứng

Model `smarttraffic_hcm_speed_v1` dùng giờ, thứ và cờ cuối tuần. Dữ liệu nguồn
SmartTraffic là dữ liệu tổng hợp một tuần; chưa ghép street với từng đoạn OSRM
và không phải dữ liệu giao thông hiện tại. Màu trên bản đồ biểu diễn vận tốc
dự đoán lưu trong ETA. Không dùng GPS của ứng dụng để huấn luyện lại.

- Backend: `accept-driver-order` v7 và `refresh-order-eta` v5, ACTIVE, bật JWT.
- Đọc lại mã remote: khớp tất cả file đã triển khai, giữ nguyên các file backend
  khác; OPTIONS 200 và POST không xác thực 401 ở cả hai endpoint.
- SQL kiểm thử tạo đơn với peak/off_peak/không chọn/sai khóa đã chạy trong
  transaction rollback. Không để lại đơn kiểm thử.
- 46 kiểm thử Node ETA/deadline và 72 kiểm thử Flutter tập trung đạt; thêm
  10 kiểm thử giám sát/GPS/thông báo đạt.
- Analyze các file sửa sạch; đã xem ảnh marker, nhãn tốc độ và Start/Stop ở
  chiều rộng 320/390 px, cỡ chữ 1,6 lần.
- Chưa kiểm thử toàn luồng bằng tài khoản khách/tài xế/CSKH có JWT trên thiết bị
  thật, chưa build phát hành. Tile mạng không được kiểm chứng bằng widget test.

Backup Edge Function trước triển khai:
`output/smarttraffic_eta/rollback/traffic_demo_edge_before.json`.
