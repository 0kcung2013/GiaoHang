# Đề xuất tích hợp UTraffic segment speed

Ngày 2026-10-12. **Người dùng đã duyệt riêng bằng “đồng ý”; phạm vi dưới đây đã được thực hiện.** Flutter đã nối runtime UTraffic, **`accept-driver-order` v8 và `refresh-order-eta` v6** đã triển khai và đang ACTIVE, JWT vẫn bật. [Kết quả và giới hạn kiểm tra](../experiments/utraffic_speed/RUNTIME.md). Không đổi entrypoint, auth/JWT, RPC, schema, RLS, migrations, database fields hoặc pipeline GPS/R2.

Sau rollout, theo yêu cầu rút ngắn demo, bỏ các đoạn chưa có dự đoán và chọn địa điểm thật, hai nút trong app đã đổi sang [tuyến 585 m trên Linh Đông phủ AI đầy đủ](../experiments/utraffic_speed/SHORT_DEMO.md). Giờ 18h/12h và backend giữ nguyên; tọa độ 15,3 km trong phạm vi phê duyệt gốc dưới đây chỉ còn ở fixture hồi quy.

Model `hcm_utraffic_segment_speed_v1`: LightGBM raw L1, road + time, 170 cây. [Audit](../experiments/utraffic_speed/AUDIT.md) và [benchmark](../experiments/utraffic_speed/BENCHMARK.md) đã hoàn thành. MAE thời gian proxy giảm từ 61,339 xuống 55,291 giây so với 25 km/h; lợi thế so với trung bình lịch sử chưa chắc chắn và macro segment error còn kém baseline 25 km/h. Velocity đang được hiểu là km/h theo suy luận, chưa được nhà xuất bản ghi đơn vị tường minh. Đề xuất này không xác nhận chất lượng ETA vận hành hoặc traffic realtime.

## Bản thay đổi có thể review

[Patch](../output/utraffic_speed/integration_candidate/edge_candidate.patch), [manifest SHA-256 trước/sau](../output/utraffic_speed/integration_candidate/manifest.json) và [full candidate files](../output/utraffic_speed/integration_candidate/supabase/functions/_shared/) lưu bản đã review trước phê duyệt. Source thật đã áp dụng 8 file dưới đây. Network sau đó được nén không mất dữ liệu; metadata production được đánh dấu `runtime_approved: true`. [Manifest triển khai thực tế](../output/utraffic_speed/deployment/manifest.json) ghi SHA-256 cuối cùng, đã đối chiếu thành công với 22 file tải lại từ hai deployments.

| File trong `supabase/functions/_shared/` | Thay đổi cụ thể |
| --- | --- |
| `delivery_eta_model_data.mjs` | Thay payload SmartTraffic bằng cây UTraffic; metadata nguồn, version 6, synthetic=false, realtime=false, unit assumption |
| `delivery_eta_road_network_data.mjs` (mới) | 56.857 static driving edges trong boundary đang có, geometry/hướng/attributes và training count; không có GPS history |
| `delivery_eta_utraffic_model.mjs` (mới) | Decode numeric tree, 15 features UTC+7, raw speed bounds 1–90, invalid input được từ chối |
| `delivery_eta_road_matcher.mjs` (mới) | Grid index, directed geometry/node validation, từ chối ambiguity, reverse và ngoài vùng |
| `delivery_eta_utraffic_profile.mjs` (mới) | Per-section speed theo giờ dự kiến vào đoạn, OSRM distance scale, partial fallback 25, exact coalescing |
| `delivery_eta_traffic.mjs` | Adapter route → model/matcher/profile; không dự đoán một directed segment từ một điểm đơn lẻ |
| `delivery_eta_speed_profile.mjs` | Demo clocks 16/12/2020 18:00 và 12:00; order thường dùng assignment clock thực; trả một profile chung |
| `delivery_eta.mjs` | OSRM thêm annotations nodes/distance; giữ thời gian profile có fallback từng phần; snapshot version 5 và metadata UTraffic |

Candidate trước nén có tổng source 9.489.966 bytes, chủ yếu static network. Network JSON 9.374.536 bytes được nén gzip thành 2.140.045 bytes, nhúng base64 trong module 2.853.832 bytes; giải nén một lần khi worker khởi động, giữ nguyên dữ liệu và parity. Entry files và dependencies ngoài 8 shared files của từng function được giữ đúng bản remote đã backup, kể cả deadline helper. `quoteRoute` legacy không nằm trong đường accept hiện tại; adapter vẫn có kiểm tra tương thích cho helper này. Không có thay đổi SQL.

## Hợp đồng dữ liệu và nghiệp vụ

Tái sử dụng `orders.delivery_eta` cùng `approach` / `delivery`, `route_points`, `distance_meters`, `travel_minutes`, `speed_profile`. Bổ sung metadata **bên trong JSON hiện có**, không thêm cột/bảng. Mỗi section giữ `start_meters`, `end_meters`, `speed_kmh`, thêm `used_ai`, `forecast_at`, `travel_minutes`, segment/source/match provenance. Leg có `ai_coverage_ratio` và `all_sections_ai`.

Một profile tính một lần sẽ là nguồn cho thời gian chặng, màu polyline và GPS mô phỏng. Phần match/inference không đạt dùng 25 km/h, màu unavailable. Các phần AI còn lại vẫn đóng góp `d/v`; không bỏ dự đoán cả chặng. Tổng section distance bằng OSRM distance; thời gian là tổng `section_meters * 0.06 / speed_kmh`.

Các ràng buộc được giữ:

- `assignment_once_v1`: ETA toàn đơn gồm chuẩn bị 5 phút + chặng đến lấy + nhận 5 phút + chặng giao + bàn giao 5 phút.
- Snapshot đã lưu được trả lại khi refresh; không tính lại ETA theo GPS hoặc theo Start/Stop, không đổi đơn đã phân công sang model mới.
- Xuất phát sớm hợp lệ trong 5 phút đầu chỉ trừ chuẩn bị 5 phút một lần. `initial_predicted_at` và profile không đổi.
- Hạn giao vẫn ETA **ban đầu** +25 phút theo RPC/server hiện có; không rút theo ETA sau trừ chuẩn bị.
- Giám sát chưa xuất phát/mất GPS, thu hồi, người giữ hàng, COD, CSKH, điểm/tự khóa và audit trail dùng nguyên luồng hiện tại.
- Start/Stop chỉ điều khiển tiến độ GPS; marker vòng tròn, nhãn km/h bên phải, không có hệ số tăng tốc.

Python có regression so sánh nguyên phần source xử lý các chính sách ETA trước `roadRoute` và nguyên file deadline helper. Candidate Node kiểm tra cached refresh, early departure idempotent, giữ neo deadline, fallback và zero distance. Các chứng cứ này không thay thế live RPC/JWT validation.

Đã đối chiếu migration hiện có `20261010171152_eta_initial_deadline_buffer.sql`: RPC nhận `p_snapshot jsonb`, giữ snapshot đã computed và đặt deadline bằng `initial_predicted_at + interval '25 minutes'`. Không có kiểm tra bắt buộc version 4 hoặc danh sách khóa section cố định trong hợp đồng này. Candidate tiếp tục gửi các khóa nghiệp vụ bắt buộc; không cần đổi SQL để lưu provenance bên trong JSON hiện có.

## Phần Flutter đã tích hợp

Module Dart production nằm trong `apps/delivery_app/lib/core/ml/utraffic/`, model/network nằm trong `assets/ml/`. Loader/cache đã nối preview và báo giá. Native worker parse/index một lần ngoài UI thread. Runtime production đã đối chiếu 2.720 predictions LightGBM và 10 route/time fixtures với Python/JS.

Mỗi section nhận `used_ai` riêng cho màu; snapshot cũ không có cờ section dùng cờ leg. Speed GPS, remaining minutes và projection đọc cùng sections. 61 focused Flutter tests đã qua sau sửa lỗi chuyển node numeric và so sánh thời điểm ISO tương đương; Start/Stop giữ nguyên. Không coi widget tests là bằng chứng E2E trên thiết bị.

Các thay đổi app đã thực hiện:

1. Đưa 3 module Dart và model/network export vào `core/ml/` cùng loader/cache. Parse network và lập grid index ngoài UI thread; không init model trong widget `build`. Key cache có route geometry, OSRM distance, annotation nodes và forecast origin.
2. `core/services/osrm_service.dart`: giữ OSRM distance và optional node annotation. Chỉ đối chiếu nodes với geometry khi cardinality và geometry/hướng đạt điều kiện; không mặc định node thứ i là point thứ i.
3. `core/utils/delivery_traffic_route_analyzer.dart`: bỏ cách chấm mọi chunk bằng cùng quotedAt/time-only model; nhận profile đã tính theo đồng hồ tiến. Giữ ngưỡng màu trong DESIGN/tokens và metadata unavailable.
4. `TrafficAwareOrderRouteLayer`: render sections từ profile được tính ngoài widget, cùng route points/OSRM distance. Không gọi model riêng để tạo màu.
5. `OrderQuoteController` / `DeliveryFeeCalculator`: dùng travel minutes từ chính preview profile cho phần dự báo tuyến; giữ distance pricing, validation, service type, điều hướng và hợp đồng đặt đơn hiện có. Trước phân công chỉ dự báo pickup → delivery; ETA toàn đơn vẫn xuất hiện sau khi có tài xế.
6. `TrafficDemoClock` / `TrafficDemoScenario`: cùng pickup `(10.7849,106.6684)` và delivery `(10.8505,106.7421)`, cùng driver seed `(10.7790,106.6765)`. Hai nút đổi **thời điểm model** 18:00 / 12:00 ngày 16/12/2020; không gán vận tốc hoặc màu bằng isCongested. Nhãn nguồn phải là vận tốc dự báo lịch sử, không phải traffic hiện tại.
7. Tracking khách / navigation tài xế / location tracker: sau phân công nhận **server snapshot**, không dự đoán lại trong app. Tái sử dụng `DeliveryEtaRouteProfile` cho speedAt, traffic segments và remaining time; thay profile khi nhận phân công khác, giữ Start/Stop và cadence GPS/monitoring.

Không cần thay operations_web để tính lại ETA: CSKH/Admin tiếp tục đọc ETA/hạn/giám sát từ backend. Không sao chép domain models hoặc design tokens sang app khác.

## Triển khai sau phê duyệt

Đã hoàn thiện wiring Flutter, test tập trung cho preview, route profile, GPS và demo; render fixture Flutter ở 390/1024 px và control sheet 320 px với text scale 1,6. Ảnh dùng tile trong suốt, không phải màn hình app có phiên đăng nhập hoặc bản đồ nền thật.

Đã đối chiếu SHA-256 trước áp dụng, đọc/lưu backup remote và giữ regression nghiệp vụ trong các tests production. Sau triển khai đã tải lại source và xác nhận 12 file của accept +10 file của refresh khớp manifest.

Hai functions đã khởi động và trả OPTIONS 200 / POST không có user session 401. Chưa đo peak memory/CPU trên Edge, chưa kiểm tra luồng nhận đơn mới → stored profile → khách/tài xế bằng phiên đăng nhập hợp lệ. OPTIONS/401 chỉ chứng minh probe khởi động/auth, không chứng minh luồng này. Full suite, release build và E2E chưa chạy.

Chỉ áp dụng model mới cho phân công mới. Đơn đã có snapshot giữ bản cũ tới khi kết thúc hoặc phân công lại theo nghiệp vụ. Nếu lỗi rollout, khôi phục shared bundle/2 deployments đã backup; không viết lại lịch sử ETA, điểm vi phạm hoặc deadline. Không cần migration.

## Quyền thay đổi

[AGENTS.md, phần Supabase MCP](../AGENTS.md) yêu cầu: “không thay đổi Supabase schema, RLS policies, migrations, Edge Functions, hoặc database fields nếu chưa được hỏi và chấp thuận riêng.” Quyền dành cho bản SmartTraffic trước đó không bao phủ việc thay model UTraffic này.

Phê duyệt “đồng ý” đã cho phép **sửa 8 shared files theo candidate và triển khai lại `accept-driver-order` + `refresh-order-eta` sau wiring/kiểm tra**. Phạm vi không bao gồm SQL, bảng/cột mới, RLS, pipeline R2, retrain bằng GPS hoặc thay các chính sách ETA/hạn/giám sát.
