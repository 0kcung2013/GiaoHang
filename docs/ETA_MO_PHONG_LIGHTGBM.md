# ETA LightGBM cho bản demo

> **Cập nhật 2026-10-13:** đã train LightGBM dự đoán tốc độ từng đoạn;
> AI trực tiếp tính ETA, tô màu và chạy xe mô phỏng, tối thiểu 15 km/h. Xem
> [hướng sửa hiện tại và kiểm tra](DEMO_TOC_DO_TUNG_DOAN.md).
> Phần dưới là ghi chép lịch sử của mô hình ETA toàn tuyến. Dataset, trọng số
> và số liệu của mô hình từng đoạn mới nằm trong `output/eta_simulation/segment_ai/`.

## Kết quả và trạng thái

Đã tạo dataset, huấn luyện và tích hợp model mới vào Flutter. Model dự đoán
thời gian chạy cả tuyến, với điểm lấy/giao người dùng chọn trong vùng demo
TP.HCM; không giới hạn vào vài tuyến dựng sẵn.

**Đã triển khai server sau khi người dùng duyệt riêng:** `accept-driver-order`
phiên bản **10**, `refresh-order-eta` phiên bản **8**; cả hai `ACTIVE`, JWT bật.
Đơn nhận mới dùng `hcm_synthetic_route_eta_v1`, cùng trọng số/cách tính với
Flutter. Các ETA đã chốt trước rollout được giữ nguyên.

Đã đọc lại mã nguồn từ Supabase: 12 file của accept và 10 file của refresh khớp
chính xác payload đã kiểm tra. OPTIONS trả 200, POST không đăng nhập trả 401.
Kết quả ở `output/eta_simulation/deployment_verification.json` và
`localized_live_http_checks.json`; source triển khai ở `output/eta_simulation/edge/`.

Bản phân bổ đoạn **profile v2** sửa hiện tượng trải thời gian chờ ra cả tuyến.
Trên cùng 160 trường hợp OSRM, số tuyến đỏ toàn bộ giảm từ **53 xuống 1**;
8 trường hợp thiếu vị trí phù hợp để phân bổ phần chờ vẫn giữ ETA nhưng hiển thị
chưa xác định mức chậm từng đoạn. Đây là kiểm tra cách minh họa mô phỏng, không
phải đánh giá độ đúng của tình trạng giao thông thực tế. Trọng số LightGBM,
dataset và ETA toàn tuyến không thay đổi.

| Kiểm tra trên dữ liệu mô phỏng | Kết quả |
| --- | --- |
| Dataset | 115.200 chuyến; 2.400 tuyến khác nhau |
| Train / validation / test | 77.472 / 17.280 / 20.448 chuyến |
| Tuyến test hoàn toàn chưa học | 426 tuyến; 24 vùng xuất phát chưa học |
| MAE ETA LightGBM | **21,43 giây** |
| Sai số tương đối trung bình | **2,92%** |
| 90% trường hợp có sai số tương đối không quá | **6,02%** |
| MAE thời gian cơ sở graph OSM offline | 200,90 giây |
| MAE khoảng cách / 25 km/h | 192,38 giây |
| MAE công thức mô phỏng biết trước, bỏ nhiễu | 20,67 giây |

Công thức biết trước giải thích giới hạn do nhiễu: AI học gần quy luật đó,
không vượt công thức mô phỏng đã biết. Tỷ lệ 99,98% nằm trong sai số 15% ở test
là kết quả mô phỏng, không phải bảo đảm cho mọi chuyến.

Kiểm tra riêng sau khi đóng băng model: gọi OSRM cho **40 cặp điểm mới**, ở
07:30, 12:00, 18:00 ngày thường và 18:00 cuối tuần, tổng **160 trường hợp**.
So với nhãn mô phỏng trên những tuyến OSRM này: MAE **21,80 giây**, sai số tương
đối trung bình **2,14%**, P90 **4,94%**. OSRM chưa điều chỉnh có MAE 374,53 giây
so với cùng nhãn. Không có thời gian giao thực tế trong phép đo này; không dùng
40 tuyến này để chọn lại hoặc chỉnh model.

Theo khoảng cách test: MAE 2,56 giây dưới 1 km; 10,11 giây từ 1–5 km; 33,15 giây
trên 5–15 km; 64,99 giây trên 15 km. Có lỗi lẻ cao hơn trung bình.
Số chi tiết ở `output/eta_simulation/benchmark.json` và `osrm_benchmark.json`.

## Luồng hoạt động đơn giản

```mermaid
flowchart LR
  A[Chọn điểm lấy và giao] --> B[OSRM: đường đi và thời gian cơ sở]
  B --> C[Độ dài, giờ xuất phát, đường, giao lộ]
  C --> D[LightGBM: hệ số điều chỉnh thời gian]
  D --> E[ETA di chuyển cả tuyến]
  E --> F[Phân bổ cho đoạn để vẽ màu và chạy GPS demo]
```

Ví dụ OSRM cho 10 phút, model dự đoán hệ số 1,4 thì thời gian di chuyển 14 phút.
Model đánh giá cả tuyến một lần, không gọi AI liên tục mỗi đoạn 20 m. Thay điểm
hoặc giờ xuất phát tạo đầu vào mới để dự đoán.

Trước phân công, app tính thời gian di chuyển lấy → giao để tô màu tuyến.
Theo yêu cầu giao diện gọn, màn chọn vị trí chỉ giữ hai ô địa chỉ, nút
**Tuyến mẫu Linh Đông**, hai nút **Cao điểm · 18:00 / Ngoài cao điểm · 12:00**
và **Tiếp tục**. Không có dòng km, thời gian di chuyển hay ghi chú ETA bên dưới.
Nút tuyến mẫu điền hai địa chỉ mẫu (mặc định 18:00 nếu chưa chọn giờ); hai nút
giờ chỉ đổi thời điểm của tuyến hiện tại. Đổi địa chỉ hoặc hủy chọn địa chỉ giữ
giờ đã chọn; dùng lại tuyến mẫu cũng giữ lựa chọn giờ. Khi nhận đơn, server chốt
ETA toàn đơn bằng:

`5 phút chuẩn bị + AI tài xế→lấy + 5 phút nhận hàng + AI lấy→giao + 5 phút bàn giao`.

Giữ quy tắc ETA đã chốt, xuất phát sớm, giám sát và snapshot cũ. Model mới không
tự đổi hạn giao của đơn đã nhận trước đó.

## Dữ liệu học

Đường thật từ [Geofabrik Vietnam / OSM](https://download.geofabrik.de/asia/vietnam.html).
Snapshot tải có SHA-256
`d954e09b891079520bf13799377a9cf783cb1d9fe2745ef11864cb8d2a5b2048`.
Dataset chính `output/eta_simulation/simulated_trips.csv`, khoảng 37,8 MB.

Thời gian mô phỏng phụ thuộc loại đường, đường nhỏ, giờ, ngày trong tuần, rẽ,
giao lộ/đèn, cộng nhiễu 3,5%. Mật độ tổng hợp theo ô OSM khoảng 0,0025 độ,
không phải giao thông đo trực tiếp. Không dùng GPS ứng dụng hoặc R2 để học.
18 trường AI và mã tạo nhãn ở [hướng dẫn pipeline](../experiments/eta_simulation/README.md).
Tách nguyên vùng điểm xuất phát và route ID giữa các tập; chọn model bằng
validation, đánh giá test sau đó.

## Màu đường và GPS demo

AI dự đoán ETA toàn tuyến. Profile v2 tách thời gian chạy và thời gian chờ:
thời gian chạy dựa trên OSRM, loại đường và giờ; phần chờ được phân bổ gần giao
lộ OSM và chỗ rẽ. Tổng thời gian đoạn vẫn khớp ETA. Đây là minh họa mô phỏng,
không phải model học tốc độ thật từng đoạn.

Bối cảnh app/server bổ sung **147.861 vị trí giao lộ** từ graph OSM công khai.
Điểm giao lộ phải cách hình học tuyến không quá 8 m; chỗ rẽ từ 45° cũng có thể
là neo. Bỏ neo sát hai đầu tuyến dưới 20 m, gộp neo cách nhau dưới 80 m và phân
bổ phần chờ trong vùng 25 m mỗi phía. Các mốc này là quy tắc mô phỏng. Không
có neo hoặc vùng chờ không đủ chứa thời gian thì giữ ETA, dùng màu chưa xác
định thay vì tự suy ra nơi tắc. Chi tiết trước/sau ở
`output/eta_simulation/color_audit_before.json` và `color_audit_after.json`.

Màu so với thời gian cơ sở chính đoạn đó: xanh dưới hệ số 1,25; vàng từ 1,25
đến dưới 1,50; cam từ 1,50 đến dưới 1,75; đỏ từ 1,75. Các mốc tương ứng là
chậm thêm **25%, 50%, 75%**. Đường hẹp chạy chậm vẫn có thể xanh nếu không chậm
đáng kể hơn cơ sở. Toàn tuyến đỏ vẫn có thể xảy ra khi cả tuyến mô phỏng chậm;
không ép chia màu để bản đồ đẹp. Chuyển 12:00/18:00 có thể đổi màu và ETA;
không gọi đây là dữ liệu tắc đường hiện tại.

Các mốc được phân loại tại Flutter từ vận tốc cơ sở/vận tốc dự đoán từng đoạn;
profile v2 dùng cùng mốc khi gộp đoạn. Chú thích bản đồ hiển thị phần trăm.
Snapshot UTraffic cũ giữ chú thích/ngưỡng km/h cũ. Cache xem trước có phiên bản
profile để không dùng lại kết quả v1 sau cập nhật; snapshot đơn đã nhận giữ nguyên.

Đợt đổi mốc màu đã qua 30 test Flutter tập trung cho phân loại màu, runtime ETA,
profile và tracking. Kiểm tra đúng tại 25%, 50%, 75%; render chú thích ở 320/390
px với chữ phóng 1,6 lần, không tràn bố cục. Ảnh: `ui/legend-320.png` và
`ui/legend-390.png` trong `output/eta_simulation/`.

## Hiệu năng và kiểm tra

Model 646 cây; hai asset app tổng khoảng 1,91 MB. Android/iOS tính trong isolate;
cache giữ 8 tuyến/thời điểm. Web tính trực tiếp. Trên máy phát triển: tải lần đầu
khoảng 134 ms JavaScript / 139 ms Dart; P90 tính ETA và phân bổ đoạn 34,35 ms
JavaScript / 26,05 ms Dart. Giao lộ được giải mã theo ô lân cận và giữ trong cache.
Đây là đo cục bộ, chưa đo trên điện thoại/Edge hoặc độ trễ request mạng.

Đối chiếu Python/JS/Dart trên 1.000 vector và 160 trường hợp OSRM: sai khác
feature bằng 0; sai khác thời gian tối đa khoảng `1,3e-11` giây.
Các kiểm tra tập trung đã qua:

- 3 test Python: chia tập, nhãn độc lập/tái lập, benchmark.
- 6 test JS profile: dữ liệu sai, ngoài vùng, lỗi model, bảo toàn thời gian,
  hồi quy tuyến từng đỏ toàn bộ và trường hợp thiếu vị trí chờ.
- 4 test tích hợp server, 24 test nghiệp vụ và 5 test kịch bản giờ hiện có.
- 55 test Flutter trong một lượt tập trung: model, quote, snapshot, so sánh giờ,
  tracking, đổi địa chỉ/giờ và render chọn vị trí; gồm 390×760 và 320×600,
  phóng chữ 1,6 lần. Log: `output/eta_simulation/localized_flutter_tests.log`.
- `deno check` cho hai Edge Functions, cả bản chuẩn bị và source đã áp dụng.
- Tổng 39 test JS profile/tích hợp/nghiệp vụ/kịch bản giờ: qua.
- `flutter analyze` tập trung 8 đường dẫn của bản sửa v2: không có vấn đề.

Ảnh render ở `output/eta_simulation/ui/preview-390.png` và `preview-320.png`.
Widget test thay tiles bằng nền trống; tuyến và ETA dùng OSRM chưa học. Chưa
chạy full suite/build phát hành hoặc luồng đăng nhập, nhận/giao đơn trên thiết
bị thật trong đợt này.

## Phạm vi và triển khai

Tuyến 50 m–25 km, toàn bộ điểm trong vĩ độ 10,65–10,95, kinh độ 106,50–106,90.
Dataset bắt đầu 100 m. Điểm chọn phải có đường để OSRM trả tuyến. Ngoài vùng
hoặc lỗi model dùng thời gian routing, không báo có AI. Graph tạo mẫu chưa xét
cấm rẽ; runtime vẫn lấy tuyến từ [OSRM](https://project-osrm.org/docs/v5.24.0/api/).

Server: thêm 6 module, đổi hai module ETA chung và thêm kiểu `string` cho
callback Redis của `accept-driver-order/index.ts`. JWT vẫn bật. Không đổi schema,
RLS, GPS, Redis, R2, phân công hoặc thanh toán. Dùng cùng trọng số/cách tính với
Flutter; không chạy training trên Supabase.

Metadata `hcm_synthetic_route_eta_v1`, `is_synthetic: true`, không traffic
realtime. UTraffic giữ đối chiếu lịch sử. Cần **Hot Restart hoặc chạy lại app**
để worker nạp bối cảnh giao lộ mới; Hot Reload có thể còn giữ worker/cache cũ.

OSM © OpenStreetMap contributors;
[ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/).
Hồi quy dùng [LightGBM](https://lightgbm.readthedocs.io/en/stable/pythonapi/lightgbm.LGBMRegressor.html).
