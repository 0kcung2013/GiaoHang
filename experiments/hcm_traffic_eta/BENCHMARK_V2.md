# Kết quả benchmark UTraffic TP.HCM — v2

- Model: `hcm_utraffic_lgbm_v2_road_profile` — LightGBM 72 cây, độ sâu tối đa 4.
- Dữ liệu: đầy đủ năm CSV của UTraffic TP.HCM; 33.441 quan sát LOS từ 03/07/2020 đến 22/04/2021.
- Chia theo thời gian: 26.688 dòng train, 6.753 dòng test; không random split.
- Feature: vị trí, giờ/ngày, giờ cao điểm, độ dài/cấp đường/tốc độ giới hạn và tỷ lệ tốc độ lịch sử của đoạn đường gần nhất.
- `segment_status.csv` chỉ đóng góp profile lịch sử trước mốc test; không dùng vận tốc cùng thời điểm dự đoán và không phải realtime.
- Model multiplier MAE: **0,4532**.
- Baseline quy tắc giờ cao điểm multiplier MAE: **0,5597**.
- Model v1 (chỉ vị trí và thời gian) MAE: **0,5088**.
- Cải thiện v2 so với v1: **10,9%**; so với baseline: **19,0%**.
- Log-multiplier RMSE: **0,3794**.

Đây là benchmark mức ùn tắc lịch sử, chưa phải benchmark thời gian giao đơn đầu-cuối. Muốn đo ETA giao hàng thực tế, hệ thống cần lưu ETA dự báo và thời gian hoàn thành thực tế của các chuyến giao.
