# ETA giao thông lịch sử TP.HCM

Pipeline này huấn luyện LightGBM từ bộ **Traffic Flow data in Ho Chi Minh
City, Viet Nam (UTraffic)**. Model dự đoán hệ số ùn tắc theo vị trí, khung giờ
và thứ trong tuần; model không thay thế OSRM và không tự nhận là dữ liệu
realtime.

## Chạy lại pipeline

```powershell
python -m venv experiments\hcm_traffic_eta\.venv
experiments\hcm_traffic_eta\.venv\Scripts\pip.exe install -r experiments\hcm_traffic_eta\requirements.txt

experiments\hcm_traffic_eta\.venv\Scripts\python.exe experiments\hcm_traffic_eta\download_data.py
experiments\hcm_traffic_eta\.venv\Scripts\python.exe experiments\hcm_traffic_eta\train_model.py

experiments\hcm_traffic_eta\.venv\Scripts\python.exe `
  experiments\hcm_traffic_eta\export_model_to_dart.py `
  --model output\hcm_traffic_eta\model_lightgbm.joblib `
  --output apps\delivery_app\lib\core\ml\delivery_eta_ai_model_data.dart
```

## Cách app sử dụng model

1. OSRM cung cấp tuyến đường và khoảng cách đường bộ. Thời gian nền của
   mỗi chặng là `km / 25 × 60`; duration OSRM chỉ giữ để đối chiếu.
2. Khi có polyline OSRM, app chia tuyến thành các đoạn khoảng 250 m.
   LightGBM dự đoán hệ số giao thông lịch sử theo vị trí từng đoạn, đặc trưng
   đường, giờ và thứ. ETA dùng trung bình hệ số có trọng số theo chiều dài
   đoạn; màu trên bản đồ dùng cùng dự báo. Các nơi chưa truyền polyline vẫn
   dùng trung điểm tuyến.
3. Với toàn tuyến có dữ liệu, áp dụng hệ số trung bình có trọng số đã giới
   hạn vào ETA nền. Không giảm thêm 55% sau khi đã tổng hợp các đoạn thoáng
   và ùn tắc. Khi chỉ có dự báo ở trung điểm, giữ cách trộn 55% hiện có.
4. Chỉ dùng AI trong vùng dữ liệu TP.HCM; nếu có polyline nhưng một đoạn
   không có dữ liệu, ETA quay về quy tắc dự phòng. Khi toàn tuyến có dự báo
   theo giờ, không cộng thêm hệ số giờ cao điểm chung lần nữa.
5. Bình Dương và khu vực ngoài miền dữ liệu dùng khoảng cách OSRM ở 25 km/h
   với hệ số 1. Không áp dụng thêm quy tắc giờ cao điểm ngoài model.

ETA toàn hành trình chỉ hiển thị sau khi có tài xế và do `refresh-order-eta`
tính một lần rồi lưu cho cả hai vai trò. GPS xác nhận xuất phát trong 5 phút
đầu chỉ trừ đúng 5 phút chuẩn bị một lần; đến lấy/giao sớm không tính lại ETA.
Chi tiết công thức và quy tắc giữ dự báo nằm trong
[staged_delivery_eta.md](../../docs/staged_delivery_eta.md).
`DeliveryEtaEstimate` vẫn phục vụ ước tính di chuyển từng chặng và kiểm thử
model; không hiển thị giá trị này như ETA toàn đơn trên màn đặt đơn.

Xuất lại đúng model hiện có sang Edge Function, không huấn luyện lại:

```powershell
python experiments/hcm_traffic_eta/export_edge_model.py
```

Xem kết quả benchmark tại [BENCHMARK.md](BENCHMARK.md).

## Hai mẫu so sánh trên màn tạo đơn

Hai mẫu dùng cùng mốc dự báo thứ Sáu lúc 17:30. OSRM trả về
2.800,2 m cho mẫu ùn tắc và 2.803,1 m cho mẫu thông thoáng, nên cả hai
hiển thị **2,8 km** và cùng phí theo chính sách giá hiện có. Khoảng cách
không bị ghi đè để làm demo. Hai điểm lấy đều nằm trong bán kính nhận
đơn 2 km của tài xế demo chính.

Với polyline đã ghi nhận trong
`apps/delivery_app/test/fixtures/traffic_demo_osrm_routes.json`, thời gian
di chuyển được hiệu chỉnh từ cùng tốc độ nền 25 km/h. Màn tạo đơn không
hiển thị ETA hoàn tất trước khi có tài xế; cần thêm chặng đến lấy và các
mốc xử lý thực tế để tính dự báo toàn hành trình.
Hệ số toàn tuyến lần lượt khoảng **1,895** và **1,071**. Tuyến thoáng có
**100%** chiều dài xanh và không có đoạn cam/đỏ; mẫu ùn tắc có **81%**
chiều dài cam/đỏ. Ngưỡng màu theo các mức LOS mà pipeline dùng làm nhãn:
A/B xanh, C vàng, D cam, E/F đỏ.

UI ghi rõ đây là demo dự báo lịch sử. Các mẫu không phản ánh giao thông
trực tiếp; OSRM có thể thay đổi tuyến khi dữ liệu đường được cập nhật.
Đây là điều chỉnh cách áp dụng dự báo, chưa phải kết quả xác thực độ chính
xác ETA với thời gian giao hàng thực tế.

Trong luồng giao, UI hiển thị giờ giao dự kiến và số phút còn lại từ server,
kèm chi tiết thời gian chuẩn bị, đến lấy, nhận hàng, đến giao và bàn giao.
5 phút là ngân sách chuẩn bị ban đầu; nhận hàng 5 phút và bàn giao 5 phút
là hai thành phần riêng, giữ nguyên sau lần tính đầu. Đồng hồ tổng giảm
theo thời gian trôi qua đến mốc đã lưu. Không dùng khoảng tin cậy tùy ý
chưa được đo lường.
