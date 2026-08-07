# Kết quả benchmark UTraffic TP.HCM

- Model: `hcm_utraffic_lgbm_v1` — LightGBM 72 cây, độ sâu tối đa 4.
- Dữ liệu: 33.441 quan sát LOS, từ 03/07/2020 đến 22/04/2021.
- Chia theo thời gian: 26.688 dòng train, 6.753 dòng test; không random split.
- Model multiplier MAE: **0,5088**.
- Baseline quy tắc giờ cao điểm multiplier MAE: **0,5597**.
- Mức cải thiện tương đối so với baseline: **9,1%**.
- Log-multiplier RMSE: **0,4102**.

Đây là benchmark khả năng ước lượng mức ùn tắc lịch sử, chưa phải benchmark
ETA giao hàng đầu-cuối vì dataset không có thời gian nhận/giao đơn. Muốn đo độ
chính xác ETA thực tế cần lưu `ETA dự đoán` và `thời gian giao thực tế` từ các
chuyến test tại TP.HCM/Bình Dương.

Vùng model hiện được phép áp dụng (percentile 1–99 của tập train):

```text
latitude:  10.740268807 → 10.886587750
longitude: 106.589061150 → 106.794938849
```

Bên ngoài vùng trên, app hiển thị rõ ETA dự phòng và không gắn nhãn “đã áp
dụng AI”.
