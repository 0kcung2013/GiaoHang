# Kết quả SmartTraffic — 2026-10-11

## Dữ liệu thực sự đã xử lý

Đã đọc toàn bộ 10 file IoT phiên bản 1 từ `ren294/iot-car-hcmcity`, xác thực CRC
của từng ZIP. Tổng **9.830.480 bản ghi**; giữ lại các trường giao thông trong CSV
nén ở `output/smarttraffic_eta/full/`. Manifest và SHA-256 từng file nằm cùng thư mục.

| Loại xe | Số bản ghi |
|---|---:|
| Motorbike | 6.882.117 |
| Car | 1.474.815 |
| Truck | 981.493 |
| Bus | 295.481 |
| Bicycle | 196.574 |

Toàn bộ 6.882.117 bản ghi Motorbike qua bộ kiểm tra kiểu dữ liệu, trường bắt buộc,
miền tọa độ số và vận tốc 0–90 km/h; điều này **không xác nhận tọa độ khớp tên đường**.
Có 65 cặp quận/tên đường, 130.900 nhóm đường/thời điểm. Thời gian dữ liệu chỉ trải
từ **2024-04-01 00:00 đến 2024-04-07 23:55**, không phải lịch sử nhiều tháng/năm.

## Huấn luyện và kiểm thử

- Train 01–05/04: **4.916.823** quan sát.
- Validation 06/04: **984.004** quan sát; dùng chọn số cây.
- Test 07/04: **981.290** quan sát; không dùng huấn luyện/early stopping.
- Mỗi nhóm đường/thời điểm có nhãn là vận tốc trung bình, trọng số là số quan sát.
- Các chỉ số bên dưới được tính trên **từng quan sát test**, không trên nhãn trung
  bình nhóm. Tập test là một ngày Chủ nhật; chưa chứng minh khái quát qua nhiều tuần.
- Timestamp nguồn không có offset: giả định giờ Việt Nam, ghi rõ trong metadata.

| Phương pháp | MAE (km/h) | RMSE (km/h) | R² |
|---|---:|---:|---:|
| Cố định 25 km/h | 16,3115 | 19,4994 | -1,8645 |
| Trung bình tập train (40,7612 km/h) | 9,9576 | 11,5212 | -0,000007 |
| Bảng trung bình đường/giờ từ train | 4,9976 | 5,7722 | 0,7490 |
| LightGBM đường + thời gian, 161 cây | 4,9971 | 5,7713 | 0,7491 |
| LightGBM chỉ thời gian, 187 cây | 4,9970 | 5,7712 | 0,7491 |

LightGBM giảm MAE vận tốc khoảng 49,8% so với trung bình toàn tập train. Tuy nhiên,
kết quả gần như bằng bảng đường/giờ; chưa chứng minh ưu thế đáng kể so với baseline
mạnh này. Chênh lệch giữa hai LightGBM cũng không có ý nghĩa thực tế ở mức đã đo.

Trong model đường + thời gian, gain của giờ khoảng 6,232 tỷ; đường khoảng 188 nghìn,
thứ khoảng 10 nghìn, cuối tuần bằng 0. Tín hiệu chủ yếu là giờ trong ngày. Train
chỉ có thứ Hai–thứ Sáu nên không được kết luận model đã học quy luật cuối tuần.

**Đề xuất cho demo:** dùng model chỉ thời gian, OSRM cung cấp tuyến và khoảng cách.
Giữ model đường + thời gian làm đối chứng. Không giới thiệu rằng dữ liệu này đã
giúp AI nhận diện ùn tắc riêng từng tuyến hoặc đo giao thông trực tiếp.

## Ví dụ đã chạy với OSRM thật

OSRM driving: tài xế `(106.665,10.775)` → lấy `(106.675,10.780)` → giao
`(106.690,10.790)`. Khoảng cách trả về: **3.136,2 m + 4.174,6 m = 7.310,8 m**.
Dùng cùng tuyến đã cache cho cả hai thời điểm, model chỉ thời gian; các con số
bên dưới là đầu ra mô phỏng, không phải thời gian chuyến giao đã đo ngoài thực tế.

| Thời điểm nhận đơn giả định | Tổng thời lượng gồm 15 phút thao tác | Giờ giao dự kiến |
|---|---:|---|
| 12/10/2026 08:00 | 29,61 phút | 08:29:37 |
| 12/10/2026 12:00 | 23,77 phút | 12:23:46 |
| Cố định 25 km/h, cùng tuyến | 32,55 phút | Phụ thuộc giờ nhận |

AI trả về vận tốc gần 30 km/h ở ví dụ buổi sáng và 50 km/h ở ví dụ buổi trưa.
Hệ thống cộng `khoảng cách / vận tốc dự đoán × 60` qua các bước, rồi thêm 5 phút
chuẩn bị, 5 phút nhận hàng và 5 phút bàn giao. Chênh lệch **5,84 phút** trên cùng
tuyến thể hiện đầu ra AI tham gia ETA.

Không dùng vận tốc 50 km/h này làm khuyến nghị tài xế chạy 50 km/h. Đây là nhãn
và kết quả của mô phỏng; chưa có hiệu chỉnh theo tốc độ di chuyển hợp pháp/thực tế
từng đoạn, chờ đèn đỏ, hay vận tốc hiệu dụng từ chuyến giao hoàn tất.

## Artifact và trạng thái

- `output/smarttraffic_eta/full_model/data_audit.json`: thống kê dữ liệu.
- `output/smarttraffic_eta/full_model/benchmark.json`: số liệu kiểm thử chính xác.
- `output/smarttraffic_eta/full_model/*lightgbm.joblib`: hai model Python.
- `output/smarttraffic_eta/full_model/*lightgbm.json`: cây LightGBM đã xuất.
- `output/smarttraffic_eta/demo_eta.json`, `demo_eta_noon.json`: hai ví dụ OSRM.
- `test_pipeline.py`: 8 kiểm thử tập trung cho stream Unicode/ZIP/CRC, dữ liệu bị
  cắt, loại bỏ trường ngoài phạm vi, lọc dữ liệu, feature không chứa nhãn, và ETA
  cộng đủ hai chặng cùng ba khoản 5 phút.

Đã hoàn tất nghiên cứu, huấn luyện và tích hợp bản xuất `smarttraffic_hcm_speed_v1`
sau khi được người dùng duyệt riêng. Xem [RUNTIME.md](RUNTIME.md) cho kết quả
triển khai và kiểm thử. Cờ `approved_for_runtime: false` trong artifact nghiên cứu
không tự động cấp quyền phát hành các lần huấn luyện mới.
