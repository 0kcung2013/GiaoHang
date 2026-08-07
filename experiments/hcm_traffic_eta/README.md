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

1. OSRM vẫn cung cấp tuyến đường, khoảng cách và ETA nền.
2. LightGBM dự đoán hệ số giao thông lịch sử từ trung điểm tuyến, giờ, thứ,
   cuối tuần và cờ giờ cao điểm.
3. Hệ số được giới hạn và trộn 55% vào ETA nền để tránh hiệu chỉnh quá mức.
4. Chỉ tuyến có trung điểm nằm trong vùng dữ liệu TP.HCM mới dùng AI.
5. Bình Dương và khu vực ngoài miền dữ liệu tự quay về OSRM + quy tắc giờ cao
   điểm hiện có.

Trong UI báo giá, bấm **ETA có AI hiệu chỉnh** để xem ETA nền, phần phút AI
cộng thêm, hệ số, thời gian bàn giao, nguồn dữ liệu và phiên bản model.

Xem kết quả benchmark tại [BENCHMARK.md](BENCHMARK.md).
