# Tích hợp và triển khai UTraffic — 2026-10-12

Người dùng đã duyệt riêng việc áp dụng 8 shared files và triển khai hai Edge Functions. Source Flutter đã dùng LightGBM `hcm_utraffic_segment_speed_v1` cho preview. Backend đang chạy model này cho phân công mới. Đây là dự báo từ dữ liệu UTraffic lịch sử, không phải traffic realtime; giới hạn benchmark và giả định đơn vị km/h vẫn được giữ trong [AUDIT.md](AUDIT.md) và [BENCHMARK.md](BENCHMARK.md).

## Luồng dữ liệu đã nối

OSRM cung cấp geometry, road distance và node annotation khi tương ứng geometry. Matcher xác định directed segment; LightGBM dự đoán vận tốc theo thời điểm dự kiến vào đoạn. Một profile lưu khoảng cách, vận tốc, thời gian và cờ AI/fallback theo section. ETA cộng `section_meters * 0.06 / speed_kmh`; polyline và GPS mô phỏng đọc cùng sections. Phần không match/inference lỗi dùng 25 km/h và màu unavailable; các phần AI còn lại vẫn được giữ.

Preview tải hai assets một lần, parse/index trong isolate trên Android/iOS, cache tối đa 8 dự báo theo geometry/distance/nodes/thời điểm/model version. Map và báo giá tái sử dụng profile; đổi đồng hồ demo trên cùng tuyến không gọi OSRM lại nếu đã có route. Khi đã phân công, khách/tài xế dùng server snapshot; app không dự đoán lại snapshot đó.

Lúc rollout, fixture dùng tuyến OSRM 15,306 km; standalone travel 77,654/35,389 phút, ETA toàn phân công 101,848/54,551 phút gồm approach và 15 phút thao tác. Fixture dài được giữ cho hồi quy backend. **Demo app hiện dùng địa điểm thật trên Linh Đông, tuyến 584,6 m phủ AI đầy đủ**, cùng geometry ở 18h/12h, travel 1,209/0,907 phút và approach 425,8 m. ETA toàn phân công 17,110/16,549 phút gồm 15 phút thao tác. [Chi tiết tuyến và kiểm tra](SHORT_DEMO.md). Đây là đầu ra model trên fixture, không phải số đo chất lượng ETA đơn thật. Giá theo khoảng cách giữ nguyên.

## Các quy tắc được giữ

- `assignment_once_v1`; refresh trả snapshot đã có, không tính lại theo GPS hay Start/Stop.
- Chuẩn bị 5 phút + đến lấy + nhận 5 phút + giao + bàn giao 5 phút.
- Xuất phát sớm hợp lệ chỉ trừ chuẩn bị một lần; giữ `initial_predicted_at` và profile.
- Hạn giao vẫn ETA ban đầu +25 phút do backend cấp.
- Start/Stop, cadence GPS và các luồng giám sát/thu hồi/COD/CSKH/vi phạm giữ nguyên.
- Không thêm bảng, cột, migration, RLS hoặc thay pipeline R2; không thu GPS để retrain.

Entrypoint, auth và dependencies ngoài 8 shared files của mỗi function được lấy đúng bản remote backup trước rollout. Snapshot cũ tiếp tục dùng tới khi kết thúc/phân công lại theo luồng hiện có.

## Triển khai và đối chiếu

Project: `erlpzwfbpjogvaulcxni`.

| Function | Trước → sau | Trạng thái | JWT | Read-back |
| --- | --- | --- | --- | --- |
| `accept-driver-order` | 7 → 8 | ACTIVE | true | 12/12 file khớp SHA-256 |
| `refresh-order-eta` | 5 → 6 | ACTIVE | true | 10/10 file khớp SHA-256 |

Static network JSON 9.374.536 bytes được nén gzip 2.140.045 bytes, nhúng base64 trong module 2.853.832 bytes để phù hợp giới hạn bundle qua API ([Supabase limits](https://supabase.com/docs/guides/functions/limits)). Worker giải nén một lần bằng `DecompressionStream`; byte và parity giữ nguyên. SHA-256 JSON gốc: `95c44d74a54529d1157b39179cea465356758aadd1ae7852577201da19f38afc`.

Sau deploy, cả hai functions trả OPTIONS 200 và POST không có user session 401; không gửi order ID và không ghi đơn. Thời gian phản hồi tổng 2,8–3,6 giây gồm mạng/auth/khởi động, không phải số đo inference hoặc cold start riêng. Chưa đo peak memory/CPU trên Edge.

Artifacts trong `output/utraffic_speed/` (Git ignore): [backup remote](../../output/utraffic_speed/deployment_backup/), [manifest cuối](../../output/utraffic_speed/deployment/manifest.json), [phiên bản remote](../../output/utraffic_speed/deployment/remote_versions.json), [read-back/probes](../../output/utraffic_speed/deployment/verification.json), [đóng gói network](../../output/utraffic_speed/edge_network_pack.json). Không sửa lại lịch sử ETA/deadline khi rollout.

## Kiểm tra đã chạy

- 47 Node tests production: ETA nghiệp vụ, cached refresh, early departure idempotence, deadline, demo, directed matching/partial fallback và parity.
- 61 Flutter tests tập trung đã qua qua các lượt chạy và chạy lại file bị lỗi: profile, báo giá/controller, route analyzer/layer, demo, navigation steps, GPS speed và Start/Stop. Lỗi node JSON numeric và ISO khác cách biểu diễn cùng thời điểm đã sửa trước kết quả này.
- Parity production: 2.720 predictions so trực tiếp LightGBM, 10 route/time fixtures so Python; sai số vận tốc 0, thời gian khoảng 3,3×10⁻¹² phút.
- Native forecast worker được test bằng model/network assets thật: load một lần, reuse clock, đổi clock và fallback khi thiếu assets.
- Analyze tập trung các file runtime/wiring/UI/test: không có issue; format và `git diff --check`.
- Render 6 ảnh Flutter fixture: map/control sheet ở 390/1024 px và control sheet riêng ở 320 px với text scale 1,6. Tile trong suốt và route đã cache; không phải phiên app đăng nhập với bản đồ nền thật. Ví dụ [18h 390px](../../output/utraffic_speed/ui/390_congested.png), [12h 390px](../../output/utraffic_speed/ui/390_clear.png).

Lệnh Node từ repository root:

```powershell
node --test --test-reporter=dot supabase/functions/_shared/delivery_eta_test.mjs supabase/functions/_shared/delivery_eta_demo_test.mjs supabase/functions/_shared/delivery_eta_utraffic_test.mjs supabase/functions/_shared/delivery_eta_utraffic_parity_test.mjs supabase/functions/accept-driver-order/deadline_test.mjs
```

Flutter từ `packages/giaohang_mobile/`:

```powershell
flutter test --no-pub test/delivery_eta_route_profile_test.dart test/delivery_quote_test.dart test/delivery_traffic_route_analyzer_test.dart test/traffic_aware_order_route_layer_test.dart test/traffic_demo_route_test.dart test/traffic_demo_comparison_test.dart test/utraffic_runtime_test.dart test/driver_ai_speed_controls_test.dart test/order_quote_controller_test.dart test/osrm_navigation_step_test.dart
```

## Phần chưa kiểm tra

Trong lượt chẩn đoán [GH-10225](DISPATCH_FIX.md), người dùng xác nhận đã thấy lời mời; query server xác nhận nhận đơn/giao hàng và stored snapshot v5 UTraffic. Sau bản sửa GPS trước nhận đơn, người dùng tạo/nhận đơn demo 600 m và xác nhận chặng tài xế → lấy không còn “Ngoài vùng”; chưa đọc snapshot lượt thành công vì không có mã đơn mới và CLI bị 403. Chưa có E2E tự động nhiều vai trò, chưa kiểm tra trực tiếp refresh/Start/Stop/deadline trên đơn thật sau rollout. OPTIONS/401 và tests không thay thế các kiểm tra này. Chưa chạy full suite, release build, kiểm tra Android/iOS thật hoặc phát hành binary app mới. Source app cần chạy lại/build; Edge Functions đã triển khai độc lập.
