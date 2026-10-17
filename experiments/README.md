# Dữ liệu và mô hình AI

Pipeline demo mới là **ETA toàn tuyến với LightGBM và dữ liệu mô phỏng trên
đường Việt Nam**, nằm ở [eta_simulation/](eta_simulation/README.md).
Đã tích hợp Flutter và triển khai hai Edge Functions: accept v10, refresh v8;
profile v2 phân bổ thời gian chờ gần giao lộ/chỗ rẽ.
Xem [kết quả và phạm vi ETA](../docs/ETA_MO_PHONG_LIGHTGBM.md).

| Cần tìm gì? | Vị trí chính |
| --- | --- |
| Bản đồ Việt Nam gốc | `data/vietnam_osm/vietnam-latest.osm.pbf` |
| Dataset chính: 115.200 chuyến mô phỏng | `output/eta_simulation/simulated_trips.csv` |
| Model Python, benchmark, dự đoán test | `output/eta_simulation/` |
| Model app đang đọc | `packages/giaohang_mobile/assets/ml/eta_simulation_model.json` |
| Bối cảnh OSM app đang đọc | `packages/giaohang_mobile/assets/ml/eta_simulation_context.json` |
| Mã tạo dữ liệu, huấn luyện, export | `experiments/eta_simulation/` |
| Model/backend hiện tại | `supabase/functions/_shared/delivery_eta_sim_data.mjs` |
| Source đã triển khai và kết quả đối chiếu | `output/eta_simulation/edge/`, `deployment_verification.json` trong output |

App/server đọc model đã export; không đọc CSV hoặc chạy Python mỗi khi có đơn.
Dataset mô phỏng không chứng minh sai số giao hàng thực tế. Không dùng lịch sử
GPS ứng dụng để huấn luyện.

[utraffic_speed/](utraffic_speed/README.md) giữ pipeline lịch sử để đối chiếu:
CSV gốc `data/hcm_traffic_raw/`, artifact `output/utraffic_speed/`, các asset và
module UTraffic được test lịch sử tham chiếu. App mới không đóng gói hai asset
UTraffic trong pubspec. Các thử nghiệm HCM ETA và SmartTraffic cũ đã loại bỏ.

Dữ liệu gốc, artifact và venv nằm ngoài Git theo `.gitignore`. Tái sử dụng venv
`utraffic_speed`, không tạo thêm bản sao.
