# Thử nghiệm SmartTraffic cho ETA

Phạm vi được người dùng đồng ý ngày 2026-10-11: kiểm tra mẫu, sau đó xử lý toàn bộ
dữ liệu IoT hợp lệ để thử huấn luyện LightGBM dự đoán vận tốc cho demo. Không trộn
UTraffic, không sử dụng lịch sử GPS của ứng dụng. Người dùng đã duyệt riêng việc
tích hợp và triển khai model; kết quả tại [RUNTIME.md](RUNTIME.md).

## Nguồn và giới hạn

- Repository: https://github.com/Ren294/SmartTraffic_Lakehouse_for_HCMC
- Dataset: https://www.kaggle.com/datasets/ren294/iot-car-hcmcity
- Kaggle API: https://www.kaggle.com/api/v1/datasets/view/ren294/iot-car-hcmcity
- Phiên bản 1, cập nhật 2024-10-08, giấy phép MIT theo metadata Kaggle.
- Nhà cung cấp mô tả dữ liệu là **mô phỏng để trình diễn/phát triển**.
- 10 file JSON, tổng 20.173.114.206 byte chưa nén. Tải theo luồng ZIP, chỉ lưu
  CSV gzip gồm timestamp, đường/quận/thành phố, tọa độ, vận tốc và loại xe.
  Không lưu tên chủ xe, điện thoại, email hoặc ETA do nguồn tự tạo.
- Vận tốc là nhãn giám sát. Không có thời gian hoàn tất giao hàng thực đo.
- Timestamp không có UTC offset. Thử nghiệm giả định giờ Asia/Ho_Chi_Minh;
  đây là giả định, chưa được xác minh từ mã sinh dữ liệu của tác giả.
- Tọa độ/tên đường chưa được đối chiếu với hình học OSM. Không coi tọa độ đó là
  bằng chứng vận tốc thực tế của từng đoạn đường hoặc độ phủ toàn TP.HCM.

## Chạy lại

Từ root repository, dùng môi trường Python hiện có ở
`experiments/hcm_traffic_eta/.venv/Scripts/python.exe`. Dependencies dùng chung
`experiments/hcm_traffic_eta/requirements.txt`; bộ đọc mạng/ZIP dùng thư viện chuẩn.

```powershell
$py = 'experiments/hcm_traffic_eta/.venv/Scripts/python.exe'
& $py experiments/smarttraffic_eta/sample.py
& $py experiments/smarttraffic_eta/audit.py
& $py experiments/smarttraffic_eta/prepare_full.py
& $py experiments/smarttraffic_eta/aggregate.py
& $py experiments/smarttraffic_eta/train_full.py
& $py experiments/smarttraffic_eta/demo_eta.py
& $py -m pytest experiments/smarttraffic_eta/test_pipeline.py -q
```

Chạy từng lệnh sau khi lệnh trước thành công. Mọi dữ liệu và model được lưu dưới
`output/smarttraffic_eta/`, đã nằm trong quy tắc bỏ qua Git của dự án.
`prepare_full.py` kiểm tra SHA-256 khi tái sử dụng file đã hoàn tất, xác thực CRC
ZIP khi đọc trọn file và ghi receipt; file dở dang không được coi là hoàn tất.

## Thiết kế thí nghiệm

1. Đọc toàn bộ 10 file và thống kê mọi loại phương tiện.
2. Mô hình giao hàng dùng toàn bộ bản ghi `Motorbike` hợp lệ. Lọc thiếu thời gian,
   vị trí, đường/quận, tọa độ ngoài miền số hợp lệ, vận tốc ngoài 0–90 km/h.
   Xe đứng yên không tự động bị xóa. Không chia cho vận tốc bằng 0 khi tính ETA.
3. Gom theo tên đường/quận và thời điểm, lấy vận tốc trung bình và số quan sát làm
   trọng số. Với squared loss và cùng đầu vào trong nhóm, cách này giữ nguyên
   phần mục tiêu phụ thuộc dự đoán của toàn bộ các quan sát. Tọa độ không dùng làm
   feature trong thí nghiệm toàn bộ vì chưa xác minh được ánh xạ đường.
4. Giữ hai ngày cuối lần lượt làm validation và test; các ngày trước làm train.
   Không để bản ghi cùng timestamp nằm ở hai tập. Danh mục đường, vận tốc nền và
   bảng vận tốc theo đường/giờ chỉ được học từ train.
5. Huấn luyện hai LightGBM: đường + giờ/thứ/cuối tuần, và chỉ giờ/thứ/cuối tuần.
   Chọn số cây bằng validation; test không tham gia early stopping.
6. Đo MAE/RMSE (km/h), R² trên từng bản ghi xe máy của ngày test, không chỉ đo trên
   trung bình nhóm. So sánh với 25 km/h, trung bình train, và bảng trung bình
   đường/giờ. Không diễn giải sai số vận tốc thành sai số giao hàng thực đo.

Chưa loại trùng toàn cục theo ID quan sát vì nguồn không có ID quan sát ổn định;
mỗi dòng nguồn đóng góp một lần. Đây là giới hạn được ghi trong data audit.

## Demo ETA độc lập

`demo_eta.py` lấy một route OSRM có hai chặng tài xế → lấy → giao, dự đoán vận tốc
ở thời điểm dự kiến đi vào từng bước và cộng phút di chuyển. Tổng cộng thêm 5 phút
chuẩn bị, 5 phút lấy hàng và 5 phút bàn giao. Thời gian các bước được tính trong
một lần dự báo, không phải cập nhật ETA liên tục khi tài xế di chuyển.

Script mặc định dùng model chỉ thời gian để không phụ thuộc ánh xạ tọa độ chưa
xác minh. Có thể truyền `--model` để đối chiếu model đường + thời gian; phép ghép
tên đường trong demo chỉ là thử nghiệm, không chứng minh đã ghép đúng đoạn OSM.

Script nghiên cứu không sửa đơn hàng. Artifact huấn luyện giữ
`approved_for_runtime: false` để không tự động phát hành khi train lại.
Bản xuất `smarttraffic_hcm_speed_v1` đã được duyệt và triển khai riêng;
xem [RUNTIME.md](RUNTIME.md) để biết phạm vi và kiểm chứng.
