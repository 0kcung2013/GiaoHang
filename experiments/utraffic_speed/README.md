# UTraffic → LightGBM vận tốc từng đoạn

Kết quả ngày 2026-10-12: đã audit, train, benchmark, tích hợp Flutter và triển khai hai Edge Functions sau khi người dùng duyệt riêng. Model được chọn là `road_time`, 170 cây, nhãn `segment_status.velocity`. Nghiên cứu này không dùng nhãn SmartTraffic hoặc GPS của ứng dụng.

Source Flutter đã dùng runtime UTraffic cho preview; ETA, màu tuyến và tốc độ GPS mô phỏng đọc cùng profile. Backend đang chạy `accept-driver-order` v8 và `refresh-order-eta` v6, JWT vẫn bật. Snapshot đã có được giữ nguyên. [Báo cáo tích hợp/triển khai](RUNTIME.md) phân biệt rõ các kiểm tra đã làm và phần chưa kiểm tra.

## Dữ liệu chính

| Nội dung | Đường dẫn từ repository root |
| --- | --- |
| CSV gốc | `data/hcm_traffic_raw/` |
| Nhãn huấn luyện | `data/hcm_traffic_raw/segment_status.csv` (`velocity`, `updated_at`, `segment_id`) |
| Network gốc | `nodes.csv`, `segments.csv`, `streets.csv` trong thư mục CSV gốc |
| Model Python đã chọn | `output/utraffic_speed/model/road_time.joblib` |
| Model/network app đang dùng | `packages/giaohang_mobile/assets/ml/utraffic_model.json`, `utraffic_network.json` |
| Model/network backend đang dùng | `supabase/functions/_shared/delivery_eta_model_data.mjs`, `delivery_eta_road_network_data.mjs` |

`train.csv` giữ để đối soát bộ nguồn; nhãn của model hiện tại lấy từ
`segment_status.csv`. Model app/backend đã export nên khi có đơn hàng không
chạy lại code huấn luyện trong thư mục này. [Bản đồ thư mục chung](../README.md).

- [Audit dataset](AUDIT.md): nguồn, đơn vị, lọc, missing metadata, chia thời gian.
- [Benchmark](BENCHMARK.md): đối chứng, giới hạn, matching, parity và kiểm tra đã chạy.
- [Đánh giá lại vận tốc và màu tuyến](REASSESSMENT.md): phân tích sai số theo dải vận tốc, đường/giờ và giới hạn khi dự báo theo giờ hiện tại.
- [Phạm vi đã duyệt](../../docs/utraffic_speed_integration_proposal.md): 8 file dùng chung, 2 Edge Functions và wiring Flutter.
- [Kết quả runtime](RUNTIME.md): parity production, UI fixture, phiên bản triển khai và read-back.
- [Tuyến demo hiện tại](SHORT_DEMO.md): 585 m trên Linh Đông, ghim địa điểm thật ở 19A/103; 18h/12h, 100% đoạn có dự đoán AI; tài xế mẫu ở 68A cách điểm lấy 426 m đường bộ.
- [Lỗi lời mời GH-10225](DISPATCH_FIX.md): replay đường bộ, fix GPS demo, xác nhận trên server và regression.

## Tái lập

Chạy từ gốc repository trong PowerShell. Môi trường Python nằm tại
`experiments/utraffic_speed/.venv`, với các phiên bản trong
[requirements.txt](requirements.txt). Các lệnh bên dưới đọc dataset và ghi
artifact riêng; không sửa app hoặc Edge Functions. Khi dựng môi trường mới:

```powershell
python -m venv experiments/utraffic_speed/.venv
& experiments/utraffic_speed/.venv/Scripts/python.exe -m pip install -r experiments/utraffic_speed/requirements.txt
```

Dataset nằm trong `data/hcm_traffic_raw/`. SHA-256 trong [audit.json](../../output/utraffic_speed/audit/audit.json) giúp phát hiện dữ liệu khác bản đã benchmark. `data/` và `output/` đều được Git ignore; báo cáo và scripts được giữ trong repository.

```powershell
$etaPython = '.\experiments\utraffic_speed\.venv\Scripts\python.exe'
& $etaPython experiments/utraffic_speed/provenance.py
& $etaPython experiments/utraffic_speed/audit.py
& $etaPython experiments/utraffic_speed/train.py
& $etaPython experiments/utraffic_speed/analyze_benchmark.py
& $etaPython experiments/utraffic_speed/export.py
& $etaPython experiments/utraffic_speed/analyze_runtime_scope.py
& $etaPython experiments/utraffic_speed/probe_routes.py --fetch
& $etaPython experiments/utraffic_speed/prepare_verification.py
node experiments/utraffic_speed/runtime/verify.mjs
dart run experiments/utraffic_speed/runtime/verify.dart
& $etaPython experiments/utraffic_speed/pack_edge_network.py
```

`provenance.py` gọi API metadata công khai của Kaggle. `probe_routes.py --fetch` chỉ gọi OSRM cho cache chưa tồn tại; lần chạy sau dùng geometry đã lưu. Giữ cache để so sánh trên cùng tuyến vì mạng OSM/routing có thể thay đổi. `pack_edge_network.py` ghi module đã nén vào `output/utraffic_speed/runtime/`, không ghi đè source backend. Các verifier trong `runtime/` import code production của app/backend, không duy trì một bản runtime sao chép.

## Kiểm tra tập trung

```powershell
& $etaPython -m pytest experiments/utraffic_speed/test_pipeline.py -q
node --test experiments/utraffic_speed/test_integration.mjs experiments/utraffic_speed/test_demo.mjs
dart analyze experiments/utraffic_speed/runtime
& $etaPython experiments/utraffic_speed/reassess.py
```

Trong `packages/giaohang_mobile/`:

```powershell
flutter test --no-pub test/delivery_eta_route_profile_test.dart test/driver_ai_speed_controls_test.dart
flutter analyze --no-pub lib/core/models/delivery_eta_route_profile.dart test/delivery_eta_route_profile_test.dart
```

Các script apply/deploy một lần cho rollout cũ và tìm các tuyến demo đã bỏ
được dọn khỏi thư mục này. Artifact, manifest và backup của rollout vẫn nằm
trong `output/utraffic_speed/` để đối soát. Kiểm tra trong thư mục này không
thay thế kiểm tra bằng phiên người dùng hợp lệ; kết quả production ở [RUNTIME.md](RUNTIME.md).

## Trách nhiệm các file

| File | Trách nhiệm |
| --- | --- |
| `data.py`, `audit.py` | Join network, kiểm tra khóa/nhãn, missing metadata, SHA-256 và chronological split |
| `features.py` | Hợp đồng numeric features và bounds vận tốc |
| `metrics.py`, `train.py` | Đối chứng train-only, lựa chọn validation, đánh giá test cố định |
| `analyze_benchmark.py`, `analyze_runtime_scope.py` | Uncertainty theo ngày và kiểm tra phạm vi export, không chọn lại model |
| `reassess.py` | Đánh giá lại model cố định, dải vận tốc/màu và sai số theo nhóm; không train hoặc thay model |
| `export.py`, `runtime_model.py` | Export cây numeric và reference inference |
| `route_profile.py`, `probe_routes.py` | Directed matching, thời điểm vào đoạn, OSRM distance và demo từ đầu ra model |
| `runtime/` | Hai verifier JS/Dart chạy code production và đối chiếu fixture Python |
| `prepare_verification.py` | Fixture đối chiếu LightGBM và forecast qua giờ/ngày |
| `test_pipeline.py`, `test_integration.mjs` | Kiểm tra dữ liệu, matching, partial fallback và nghiệp vụ ETA |
| `pack_edge_network.py` | Nén gzip/base64 network cho Edge, đối chiếu byte sau giải nén |
| `confirm_real_places_demo.mjs`, `probe_demo_dispatch.mjs` | Đối chiếu tuyến demo hiện tại và điều kiện lời mời theo OSRM |
| `test_demo.mjs` | Hồi quy demo địa điểm thật, độ phủ dự đoán và ETA |

`export.py` sở hữu hàm `flatten_tree` và giữ nguyên định dạng numeric tree
`ETA1`, không còn phụ thuộc experiment cũ. Bản sao dữ liệu gốc và model app/backend
được giữ nguyên khi dọn thư mục.
