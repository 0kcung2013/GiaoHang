# Benchmark vận tốc UTraffic, 2026-10-12

Demo 15,3 km trong báo cáo này là fixture nghiên cứu/rollout gốc. Demo app hiện dùng [tuyến địa điểm thật 585 m trên Linh Đông](SHORT_DEMO.md); benchmark model và fixture hồi quy backend dưới đây được giữ nguyên.

Kết quả chính: `road_time` giảm MAE thời gian quy đổi theo quan sát 9,86% so với 25 km/h và 9,20% so với model chỉ thời gian. Lợi thế 1,70% so với trung bình lịch sử chưa chắc chắn về thống kê; khi cho mỗi đoạn trọng số bằng nhau, model còn kém baseline 25 km/h. Đây là candidate tích hợp/demo, chưa phải bằng chứng về sai số ETA đơn giao thực tế.

## Thiết kế và chọn model

[Audit](AUDIT.md) giữ nhãn thấp/zero và chia nguyên ngày theo thời gian. 18 cấu hình được đánh giá trên validation: 3 nhóm feature (`time_only`, `road_time`, `road_time_ids`) × 3 mục tiêu (raw L1, raw L2, log1p L2) × 2 mức capacity. Các lựa chọn được khai báo trước lần đọc test. Chọn theo MAE `d/v` validation, dùng MAE vận tốc để phá hòa.

`road_time` raw L1 thắng validation: 170 cây, 15 leaves, depth 4, min child 80, learning rate 0,045, lambda 0,5, seed 42. Validation MAE thời gian 48,298 giây và MAE vận tốc 15,255 km/h. Max 600 cây, early stop 60 vòng. Artifact không refit và không thay winner dựa trên test.

15 numeric features: giờ có phút, weekday Monday=0, weekend, sin/cos giờ, midpoint lat/lng, chiều dài, max_velocity và missing flag, cấp đường và missing flag, type code, sin/cos bearing. `road_time_ids` thêm segment/street encoding nhưng không thắng validation. Không dùng LOS, velocity quan sát, tên đường, GPS ứng dụng hoặc thống kê vận tốc tương lai làm feature.

## Đối chứng trên 15.886 quan sát test

Thời gian tham chiếu là `length_m * 3.6 / velocity_dataset` giây, với đơn vị km/h theo [giả định audit](AUDIT.md). Không có nhãn thời gian hoàn tất đơn hàng. Tất cả nhãn test dương; 446 nhãn zero nằm trong train. Baseline lịch sử dùng mean segment/hour nếu ≥3 nhãn train, rồi segment nếu ≥3, hour nếu ≥30, cuối cùng global train mean.

| Phương án | MAE km/h | RMSE km/h | MAE thời gian, giây | RMSE thời gian, giây | MAE trung bình mỗi đoạn, giây |
| --- | ---: | ---: | ---: | ---: | ---: |
| Cố định 25 km/h | 21,048 | 24,215 | 61,339 | 118,313 | **13,305** |
| Trung bình lịch sử train-only | 17,637 | 22,767 | 56,246 | 112,104 | 15,878 |
| LightGBM chỉ thời gian | 17,771 | 24,499 | 60,893 | 112,194 | 24,235 |
| **LightGBM đường + thời gian, được chọn** | **16,874** | **21,762** | **55,291** | **110,424** | 16,046 |
| LightGBM thêm IDs | 17,663 | 22,402 | 55,184 | 110,916 | 14,960 |

Kết quả đầy đủ: [benchmark.json](../../output/utraffic_speed/model/benchmark.json), [test_predictions.csv](../../output/utraffic_speed/model/test_predictions.csv), [feature importance](../../output/utraffic_speed/model/road_time_importance.csv). Thêm IDs có test MAE thời gian thấp hơn 0,106 giây, nhưng không được chọn lại theo test.

### Uncertainty và điểm yếu

Bootstrap 2.000 lần theo toàn ngày UTC+7, 40 ngày test, seed 42, model cố định. Dấu dương là model được chọn giảm MAE theo quan sát.

| Đối chứng | Giảm MAE, giây | Khoảng 95% theo cụm ngày, giây |
| --- | ---: | ---: |
| 25 km/h | 6,049 | [0,535; 17,629] |
| Chỉ thời gian | 5,602 | [0,940; 13,093] |
| Trung bình lịch sử | 0,956 | [-3,087; 5,599] |

Lợi thế so với trung bình lịch sử chưa phân biệt rõ khỏi 0. Khi mỗi ngày có trọng số bằng nhau, model kém baseline này 0,963 giây. MAE chuẩn hóa mỗi km của model là 1.328,52 giây/km, so với 1.311,59 của baseline lịch sử. Đoạn nhiều quan sát và nhãn 1–2 km/h có ảnh hưởng lớn lên kết quả theo dòng.

| Nhóm test | Dòng | MAE thời gian model | 25 km/h | Trung bình lịch sử |
| --- | ---: | ---: | ---: | ---: |
| Đoạn đã có trong train | 10.488 | 53,465 | 62,373 | 54,096 |
| Đoạn chưa có trong train | 5.398 | 58,837 | 59,332 | 60,424 |
| Đoạn có ≤3 nhãn train | 3.989 | 79,608 | 80,751 | 77,245 |
| Vận tốc quan sát 1–2 | 6.474 | 118,050 | 136,172 | 114,067 |
| Vận tốc quan sát ≥3 | 9.412 | 12,122 | 9,866 | 16,474 |

Các nhóm sparse và low-speed chưa thắng baseline lịch sử; nhóm ≥3 chưa thắng 25 km/h. Bias thời gian model -47,423 giây, p90 absolute error 155,856 giây, WAPE 0,836. Không diễn giải giảm MAE tương đối thành ETA vận hành chính xác. [Uncertainty JSON](../../output/utraffic_speed/model/uncertainty.json) và [sai số theo ngày](../../output/utraffic_speed/model/test_date_errors.csv) giữ dấu vết.

### Đúng phạm vi runtime export

Không train hoặc chọn lại model. Lấy cùng predictions đã cố định, lọc test theo 56.857 driving edges trong boundary hiện có: còn 15.143 quan sát trên 3.271 đoạn.

| Phương án | MAE km/h | MAE thời gian, giây | MAE trung bình mỗi đoạn, giây |
| --- | ---: | ---: | ---: |
| 25 km/h | 21,137 | 61,944 | 12,762 |
| Trung bình lịch sử | 17,479 | 56,415 | 14,754 |
| Chỉ thời gian | 17,343 | 60,503 | 21,980 |
| Model đường + thời gian | 16,769 | 55,621 | 15,564 |

Cùng xu hướng và cùng giới hạn với benchmark toàn bộ nhãn hợp lệ. [runtime_scope_benchmark.json](../../output/utraffic_speed/model/runtime_scope_benchmark.json) chứa cả kết quả model IDs.

## OSRM → directed segments → một profile

Matching kiểm tra geometry đầu/cuối/midpoint, hướng đi và projection lên edge: lateral ≤8 m, sai hướng ≤20°, slack endpoint 3 m, probe ≤20 m. Candidate song song/overlap chênh ≤3 m bị từ chối. Chỉ ưu tiên cặp node OSRM khi số node tương ứng số geometry points, ID có khớp và geometry/hướng cũng đạt yêu cầu. Không dùng midpoint gần nhất hoặc tên đường để ép match.

Độ dài mỗi phần được scale theo tổng chiều dài OSRM; section cuối được sửa sai số số học để profile phủ chính xác `[0, distance_meters]`. Mỗi dự đoán dùng giờ dự kiến vào phần đó, cộng `d/v` để tiến đồng hồ. Chỉ gộp hai phần kề nhau nếu vận tốc và provenance khớp tuyệt đối; không lấy trung bình vận tốc dự đoán.

Phần không match, model lỗi/invalid, ngoài boundary hoặc tuyến >25 km dùng 25 km/h và `used_ai: false`. Partial AI được giữ; không biến cả chặng thành fallback vì một phần không match. Fallback có màu unavailable, không coi là thông thoáng.

Coverage dưới đây là tỷ lệ chiều dài nhận dự đoán AI, **không phải độ chính xác matching đã có ground truth**. Cache route, các giờ probe và profile ở [routes/](../../output/utraffic_speed/routes/).

| Tuyến probe | OSRM, km | AI coverage | Giờ được chọn | Chênh thời gian tuyến, phút |
| --- | ---: | ---: | --- | ---: |
| Driver seed → điểm lấy | 1,238 | 81,47% | Không tự chọn cặp giờ vì ít support | — |
| Demo cũ | 2,800 | 86,87% | 07 / 08 | 0,424 |
| CMT8 → khu Phạm Văn Đồng | 15,306 | 86,92% | **18 / 12** | **42,265** |
| Nội thành | 4,913 | 80,87% | 18 / 13 | 17,528 |
| Phạm Văn Đồng | 15,205 | 75,92% | 17 / 12 | 45,887 |

Cặp giờ được tìm trên cùng geometry vào thứ Tư 16/12/2020, chỉ xét giờ có ≥3 đoạn cùng tuyến/giờ được quan sát trong train, chọn thời gian dự đoán lớn/nhỏ nhất. Đây là demo được chọn để nhìn thấy khác biệt, không phải test chất lượng độc lập. Không gán tốc độ hoặc màu bằng scenario.

Tuyến đề xuất: pickup `(10.7849, 106.6684)` → delivery `(10.8505, 106.7421)`, cùng driver seed `(10.7790, 106.6765)`. Route có 422 geometry points và 422 annotation nodes, 287 đoạn UTraffic được match. 18h có 32 nhãn train trên 18 đoạn cùng route/hour; 12h có 18 nhãn trên 14 đoạn. Phần lớn đoạn được suy rộng qua features.

Standalone travel: 18h = 77,654 phút, tốc độ AI 1,090–36,392 km/h; 12h = 35,389 phút, tốc độ AI 14,543–44,503 km/h. Giữ các ngưỡng màu đang có: 18h có ba dải congested/heavy/moderate; 12h có bốn dải. Không đổi thresholds để ép đủ màu.

Candidate tính cả hai chặng và 15 phút thao tác, với forecast của chặng giao bắt đầu sau chuẩn bị + chặng đến lấy + nhận hàng: ETA ban đầu **101,848 phút / 54,551 phút**. Đây là fixture cùng route/driver, không phải đơn thật. Số khác standalone do đồng hồ forecast tiến theo approach và các thời gian thao tác. [assignment_demo.json](../../output/utraffic_speed/routes/assignment_demo.json) lưu đầy đủ hai snapshot.

## Parity, chi phí và kiểm tra

Python reference, JavaScript và Dart được đối chiếu trên 2.720 fixture có expected values trực tiếp từ LightGBM, gồm các mốc UTC+7 qua cuối tuần/nửa đêm. Đây là kiểm tra số học runtime, không phải tập test chất lượng dự đoán mới. Sai số vận tốc tối đa 0 ở cả ba runtime. 10 route/time fixtures gồm tiến giờ/ngày có cùng matching ID, AI/fallback, khoảng cách và forecast; sai số tổng phút tối đa khoảng 3,3×10⁻¹².

- Python: 17 tests qua, gồm label leakage, split, low/zero, reverse/turn/parallel ambiguity, node+geometry validation, invalid inference, partial fallback, distance và protected policy source.
- Candidate Node: 40 tests qua = 24 regression ETA nghiệp vụ + 12 legacy quote/deadline + 4 integration UTraffic. 5 assertions riêng SmartTraffic trong bản copy được thay bằng parity và integration mới; không sửa test production để che lỗi.
- Flutter: 14 tests qua (`delivery_eta_route_profile_test`, `driver_ai_speed_controls_test`); kiểm tra profile mixed AI/fallback, snapshot cũ, speed/time/color cùng dữ liệu, Start/Stop, marker 320/390 px, rotated icon và large text.
- Analyze Dart runtime và hai file app đã sửa: không có issue. `git apply --check` cho Edge patch và `git diff --check` đạt.

[JS verification](../../output/utraffic_speed/runtime/javascript_verification.json) đo cold load 567,772 ms, heap khoảng 80,85 MB; [Dart verification](../../output/utraffic_speed/runtime/dart_verification.json) đo cold load 462,771 ms. Đây là process desktop, chưa phải Edge hoặc điện thoại. JS tạo profile tuyến 15,3 km khoảng 23–36 ms sau load. Gộp section khớp tuyệt đối giảm profile từ khoảng 299 KB xuống khoảng 115 KB; 358–359 sections cho hai giờ standalone.

Binary model 73.096 bytes, static network JSON 9.374.536 bytes; tổng 8 source candidate Edge 9.489.966 bytes. Cần load/cache một lần và tránh parse/index network trên Flutter UI thread. Chưa đo bundle, memory/cold start trên Supabase Edge hoặc Android/iOS.

Các con số và kiểm tra ở phần này thuộc giai đoạn nghiên cứu/candidate trước phê duyệt. Sau phê duyệt ngày 2026-10-12 đã nối model/scenario vào Flutter và triển khai hai functions: 47 Node tests production, 61 Flutter tests tập trung đã qua; analyze các file liên quan không có issue. Có ảnh render fixture cho demo, chưa có E2E bằng phiên đăng nhập. Network Edge đã nén không mất dữ liệu; read-back source 22 file khớp và probe khởi động đạt. Xem [RUNTIME.md](RUNTIME.md) để biết phạm vi thực tế. Không chạy full suite, release build, SQL tests hoặc E2E khách/tài xế/CSKH.
