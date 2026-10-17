# LightGBM dự đoán tốc độ từng đoạn cho demo ETA

Runtime hiện dùng `hcm_synthetic_segment_speed_v2`: AI dự đoán tốc độ đoạn,
ETA cộng thời gian các đoạn; cùng tốc độ dùng cho xe mô phỏng và màu đường.
Tốc độ khi chạy 15–50 km/h, giảm trước ngã rẽ rồi tăng sau cua. Dữ liệu là mô phỏng trên đường OSM thật,
không dùng lịch sử GPS người dùng để train.

Giới hạn suy luận từ 2026-10-17: toàn bộ hình học tuyến phải nằm trong
10.65–10.95 vĩ Bắc, 106.50–106.90 kinh Đông, khớp vùng graph huấn luyện.
Vùng OSM trích thuộc tính rộng hơn không mở rộng vùng AI. Tuyến ngoài vùng
dùng thời gian OSRM và màu xanh dương; snapshot đã nhận trước rollout giữ nguyên.

Xem [kết quả và cách demo](../../docs/DEMO_TOC_DO_TUNG_DOAN.md).
Ghi chép mô hình ETA tổng trước đây ở
[ETA_MO_PHONG_LIGHTGBM.md](../../docs/ETA_MO_PHONG_LIGHTGBM.md) là lịch sử.

## Pipeline hiện tại

Dùng venv `experiments/utraffic_speed/.venv` đã có LightGBM, NumPy, Pandas.
PBF: `data/vietnam_osm/vietnam-latest.osm.pbf`; nguồn/SHA-256 trong
`output/eta_simulation/provenance.json`.

1. `extract_speed_roads.py`: trích loại đường, độ cong, giao lộ/đèn trên
   2.592.573 node OSM thuộc vùng bao demo.
2. `train_segment_speed.py`: 216.000 mẫu tốc độ trên 18.000 đoạn đường;
   tách road ID giữa train/validation/test. Dành riêng 80 tuyến và loại
   mọi cạnh của chúng khỏi train/validation trước khi chọn model.
3. `install_segment_model.py`: cài model đã vượt benchmark vào hai asset
   Flutter và module dùng chung Edge Functions. Nén danh sách node theo
   run để giữ trọn dữ liệu mà gói deploy dưới giới hạn 5 MB.
4. `runtime/verify_segment.mjs`, `verify_segment.dart`: kiểm tra cây
   Python/JS/Dart và profile từng đoạn. `package_segment_deploy.py` tạo
   gói ETA riêng từ payload đã triển khai 14/12; không đưa các sửa đổi
   cục bộ khác lên server.

Node thiếu trong OSRM/OSM dùng loại đường suy ra từ annotation hoặc khu vực.
Tốc độ vẫn do model dự đoán; không chạy công thức nhãn thay AI ở runtime.
Tám đặc trưng: `road_class, bend, junction, signal, peak, weekend, road_variation, turn_intensity`.
`road_variation` là bối cảnh tốc độ mô phỏng ổn định theo ô địa lý; `turn_intensity`
lấy từ góc rẽ của tuyến thực tế và khoảng cách trước/sau cua, gồm rẽ giữa hai OSM way.
`export_speed_route_features.mjs` dùng cùng bộ trích đặc trưng runtime để đánh giá 80 tuyến.
Không dùng road ID, tọa độ điểm đến, ETA tổng hoặc nhãn làm đặc trưng.

## Chạy lại từ repository root

```powershell
$etaPython = 'experiments/utraffic_speed/.venv/Scripts/python.exe'
# Chỉ cần tạo graph/tuyến khi chưa có graph.pkl và routes.json:
& $etaPython experiments/eta_simulation/osm_routes.py --routes 2400
& $etaPython experiments/eta_simulation/extract_speed_roads.py
& $etaPython experiments/eta_simulation/train_segment_speed.py
& $etaPython experiments/eta_simulation/install_segment_model.py
node experiments/eta_simulation/runtime/verify_segment.mjs
node experiments/eta_simulation/verify_road_index.mjs
node experiments/eta_simulation/verify_turn_demo.mjs
dart experiments/eta_simulation/runtime/verify_segment.dart
node --test experiments/eta_simulation/runtime/profile_test.mjs experiments/eta_simulation/server_integration_test.mjs supabase/functions/_shared/delivery_eta_test.mjs supabase/functions/_shared/delivery_eta_demo_test.mjs
& $etaPython experiments/eta_simulation/package_segment_deploy.py
```

Nếu thay PBF, cần làm mới graph/cache tương ứng; không dùng cache node/graph
từ nguồn cũ với nguồn mới. Training/export ETA toàn tuyến (`train.py`,
`export.py`, `prepare_parity.py`, `runtime/verify.mjs`, `verify.dart`,
`package_runtime.py`) được giữ cho lịch sử và không cài vào runtime hiện tại.

## Artifact

Thư mục `output/eta_simulation/segment_ai/` giữ:

| Nội dung | File |
| --- | --- |
| Nhãn train và model Python | `training_speeds.csv`, `model.joblib` |
| Model/OSM dùng trong app và Edge | `model.json`, `context.json` |
| Đánh giá tốc độ/ETA | `benchmark.json`, `held_out_routes.csv` |
| Đầu vào AI, tốc độ, thời gian từng đoạn | `prediction_trace.json` |
| Dự đoán test / importance | `test_predictions.csv`, `feature_importance.csv` |
| Parity Python/JS/Dart | `parity_vectors.json`, `parity_profiles.json`, `*_verification.json` |
| OSRM trực tiếp | `live_routes.json` |
| Tốc độ trung bình mẫu / AI / thời gian của 80 tuyến | `route_average_speeds.csv` |
| Gói triển khai, hash, trạng thái | `deploy_packages.json`, `deploy_manifest.json` |

CSV, PBF, Python model và artifact trong output không commit vào Git.
Flutter chỉ nạp hai asset tổng khoảng **3,74 MB**, không chạy Python khi demo.
Chỉ mục dùng `attribute_optional_delta_run_v4`, bỏ byte delta=1 có thể suy ra;
đã kiểm tra giữ nguyên toàn bộ 2.592.573 ID/thuộc tính, không bỏ đường hoặc hẻm.
Gói Edge nén thêm node payload bằng gzip và giải mã bằng `node:zlib` một lần;
gói deploy khoảng 2,72 MB. Asset Flutter giữ payload v4 thường, không thêm
dependency và không thay đổi kết quả dự đoán. Backend đang chạy bản 15/13.
Benchmark đo đúng trên dữ liệu mô phỏng, không đánh giá giao thông thực tế.

`summarize_route_demo.py` bổ sung tốc độ trung bình từ benchmark đã có, không
train lại model. Trường tốc độ trung bình tuyến chỉ là nhãn/summary để đối chiếu,
không đưa vào tám đầu vào LightGBM. UI tính cùng giá trị từ quãng đường/thời gian
di chuyển; thời gian chuẩn bị, nhận hàng và bàn giao hiển thị riêng.
