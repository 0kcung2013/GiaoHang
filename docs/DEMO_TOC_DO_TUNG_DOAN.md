# AI dự đoán tốc độ từng đoạn và ETA demo — 2026-10-13

> Bản giải thích ngắn để trình bày: [GIAI_THICH_AI_ETA_NGAN.md](GIAI_THICH_AI_ETA_NGAN.md).
> Chi tiết ETA trên app đã bổ sung quãng đường, tốc độ trung bình toàn tuyến và
> thời gian di chuyển. Tốc độ trung bình lấy tổng quãng đường chia tổng thời gian
> di chuyển AI, không cộng thời gian chuẩn bị/nhận/bàn giao vào mẫu số.
> Bảng đối chiếu 80 tuyến/240 trường hợp: `segment_ai/route_average_speeds.csv`.
> Bản v2 đã train lại dữ liệu tốc độ và thêm góc rẽ thực tế của tuyến vào AI.
> Ví dụ đường thẳng → giảm tốc → cua → tăng tốc: **48 → 34 → 21 → 34 → 49 km/h**.
> Dùng các trường quãng đường/thời gian sẵn có, không thêm database fields.

## Cách tính hiện tại

LightGBM được train lại để dự đoán **km/h từng đoạn**, thay mô hình ETA tổng
và bộ tốc độ sinh bằng quy tắc ở runtime. OSRM cung cấp đường đi thật, khoảng
cách và node OSM. App/server chỉ nạp trọng số rồi chạy cây LightGBM.

Một kết quả AI dùng cho ba việc:

- Thời gian di chuyển = tổng `độ dài đoạn × 3,6 / tốc độ AI`.
- Xe mô phỏng di chuyển theo tốc độ AI của đoạn đang đi; nhãn hiển thị km/h.
- Màu biểu thị tốc độ dự đoán. Các đoạn liền nhau cùng màu được gộp khi vẽ;
  ETA và chuyển động vẫn giữ tốc độ riêng của từng đoạn.

Không lấy ETA tổng phân bổ ngược. Bộ quy tắc tạo nhãn nằm trong script train,
không chạy để thay dự đoán AI trong app. Kiểm tra thay giá trị trả về của model
từ 20 thành 40 km/h khiến thời gian di chuyển giảm đúng một nửa.

## Dữ liệu và giới hạn demo

Dùng PBF OpenStreetMap Việt Nam đã có, không thu thập GPS người dùng.
Trích 2.592.573 node đường trong hình chữ nhật 10,30–11,65 vĩ Bắc,
106,20–107,65 kinh Đông. Đây là vùng trích thuộc tính OSM mở rộng,
không phải vùng huấn luyện hoặc ranh giới hành chính.

Từ 2026-10-17, bản xem trước/demo trong Flutter chỉ áp dụng AI nếu **toàn bộ
tuyến** nằm trong vùng lấy mẫu graph huấn luyện: **10,65–10,95 vĩ Bắc,
106,50–106,90 kinh Đông**, khớp `context.bounds` và `features.py`.
Nếu bất kỳ đoạn nào ra ngoài vùng (kể cả hai đầu tuyến ở trong), toàn tuyến
dùng thời gian OSRM và polyline **xanh dương đồng nhất**; giao diện ghi
“Ngoài vùng dự đoán AI · ETA từ OSRM”. Kết quả AI xem trước cũ được kiểm tra lại
theo `coverage_version`, không giữ màu/tốc độ AI ngoài vùng. Thiếu model trong
vùng là một trạng thái riêng, không bị ghi nhầm là ngoài vùng.

Đây là giới hạn vùng dữ liệu phục vụ demo, không phải bằng chứng mô hình đã
học hay chính xác với giao thông thật. Vẫn dùng các tuyến chưa tham gia train
để đánh giá; nhãn tốc độ là mô phỏng.

Backend đã được đồng bộ ngày 2026-10-17 sau khi được chấp thuận riêng:
`accept-driver-order` v16 và `refresh-order-eta` v14. Khi tạo snapshot mới,
mỗi chặng (đến điểm lấy / đến điểm giao) kiểm tra toàn bộ hình học tuyến;
chặng ngoài vùng lưu `used_ai: false`, thời gian OSRM và lý do
`outside_training_area` để Flutter vẽ xanh dương, hiển thị nhãn phù hợp.
Snapshot/hạn giao đã lưu trước triển khai vẫn được giữ nguyên, không tính lại
đơn đang giao. Gói triển khai chỉ đổi hai module profile/segment speeds,
giữ nguyên các file còn lại và xác thực JWT. Không đổi schema hoặc RLS.

Đặc trưng gồm loại đường (hẻm/đường dân cư/đường lớn), độ cong, giao lộ,
đèn tín hiệu, mức cao điểm, cuối tuần, bối cảnh tốc độ địa phương mô phỏng
và ảnh hưởng của ngã rẽ thực tế. Loại đường ưu tiên tag OSM;
đường có tag chiều rộng ≤3,5 m được coi là hẻm. Khi thiếu node tương ứng
giữa bản đồ OSM và OSRM, suy ra loại đường từ tốc độ nền từng đoạn OSRM;
nếu thiếu cả annotation thì lấy bối cảnh khu vực. Mọi trường hợp trong vùng
vẫn dùng model dự đoán từ đặc trưng sẵn có, không tuyên bố biết chính xác
chiều rộng của đường không có tag.

Nhãn mẫu theo các mức:

| Loại đường | Ngoài cao điểm | Cao điểm |
| --- | --- | --- |
| Đường lớn, thẳng | khoảng 46–50 km/h | khoảng 33–37 km/h |
| Đường dân cư, thẳng | khoảng 35–40 km/h | khoảng 26–31 km/h |
| Hẻm, thẳng | khoảng 21–25 km/h | khoảng 15–19 km/h |

Các mức trên là mẫu nền khi thông thoáng; cong đường, giao lộ và đèn giảm thêm.
Tốc độ khi chạy giới hạn **15–50 km/h**. Góc rẽ được nhận diện từ hướng tuyến
trước/sau điểm rẽ, gồm cả rẽ giữa hai đường mà tag cong OSM cũ bỏ sót.
Với cua 90°, vùng giảm tốc dài khoảng 70 m trước cua và 50 m sau cua;
đoạn ở góc cua giảm về khoảng 15–22 km/h. Chia vùng này tối đa 8 m để chuyển
tốc độ theo từng bước nhỏ; các đoạn cùng màu vẫn được gộp khi vẽ. Dừng nhận/giao
hàng có vận tốc 0 và thời gian dừng riêng. Công thức tạo nhãn chỉ chạy lúc train;
km/h runtime vẫn là kết quả LightGBM, không ép lại tốc độ cua sau dự đoán.

Cùng node đường và khung giao thông 15 phút giữ cùng đặc trưng/tốc độ khi
đổi điểm đến và đi cùng hướng. Khi đổi từ đi thẳng sang rẽ, chỉ vùng gần ngã rẽ
được thay đổi để phản ánh thao tác khác nhau. Đường lớn thông thoáng có thể
toàn xanh; không ép tuyến có đủ màu.
Tuyến trong vùng cần OSRM định tuyến được. Khi thiếu/lỗi model hoặc ngoài vùng,
hiển thị ước tính routing, không gắn nhãn đã dùng AI.

## Màu và ETA nghiệp vụ

- Xanh: ≥35 km/h.
- Vàng: 25 đến dưới 35 km/h.
- Cam: 20 đến dưới 25 km/h.
- Đỏ: 15 đến dưới 20 km/h.

Chú giải ghi **Tốc độ AI dự đoán · km/h**, không gọi các mức này là kẹt xe.
Nhãn tốc độ tài xế dùng cùng màu của đoạn đang đi. Snapshot cũ giữ chú giải
mức chậm tương đối và không bị gắn nhãn AI sai.

ETA đơn cộng thời gian đến lấy + thời gian đến giao + 5 phút chuẩn bị +
5 phút nhận hàng + 5 phút bàn giao. Hai chặng dùng cùng thời điểm giao thông.
Quy tắc xuất phát sớm và ETA đã chốt của các đơn cũ được giữ nguyên.

Model `hcm_synthetic_segment_speed_v2`, profile 6, snapshot ETA 10.
Các chặng/đoạn mới có `used_ai: true`, `ai_coverage_ratio: 1` và
`color_metric: speed_kmh`. UI ghi AI là nguồn tính ETA chính.

## Huấn luyện và kiểm chứng

216.000 mẫu trên 18.000 đoạn đường: 151.200 train, 32.400 validation,
32.400 test. Road ID không trùng giữa các tập. Chọn model bằng MAE validation;
model được chọn có 360 cây, tối đa 31 lá.

Dành riêng 80 tuyến trước khi tạo dữ liệu train: loại tất cả cạnh của chúng
khỏi cả train và validation. Kiểm tra ba khung giờ thành 240 trường hợp.

- MAE tốc độ trên nhãn mô phỏng có nhiễu: **0,290 km/h**.
- MAE ETA so với tốc độ kỳ vọng của bộ mô phỏng trên 80 tuyến: **0,380 giây**.
- MAPE ETA: **0,153%**; baseline cố định 25 km/h có MAE **197,91 giây**.
- Đây là sai số trên dữ liệu mô phỏng; không đo độ chính xác giao thông thực.
  Benchmark ETA dùng tốc độ kỳ vọng không nhiễu; benchmark tốc độ dùng nhãn
  có nhiễu 0,35 km/h. Mỗi đoạn có mẫu thẳng và sáu mức ảnh hưởng của cua;
  benchmark tuyến trích đặc trưng bằng đúng bộ xử lý geometry dùng ở runtime.

Lượt sửa v2 đạt 66 kiểm tra Flutter tập trung (runtime, worker/cache, màu,
chuyển động giảm tốc, preview, ETA và tracking), 45 kiểm tra JavaScript.
1.000 vector Python/JS/Dart khớp, 160 profile JS/Dart sai lệch thời gian
tối đa khoảng 4,3e-13 giây. Có kiểm tra AI điều khiển kết quả, sàn 15 km/h,
đoạn chung, gộp màu và thời gian đến đích mô phỏng.

Kiểm tra 120 tuyến từ bộ 2.400 tuyến, cộng 6 lần gọi OSRM trực tiếp gồm
Củ Chi → Phú Nhuận và Cần Giờ → Quận 7. Đủ tốc độ, cao điểm chậm hơn,
dự đoán lặp lại ổn định. Node OSM khớp khoảng 80–99,9% quãng đường
của sáu tuyến trực tiếp; phần còn lại dùng đặc trưng dự phòng.

Render ở 320×600 và 390×760, chữ 1,6 lần ở màn hình nhỏ. Tiles trong
widget test là nền trống, không phải kiểm tra bản đồ nền/GPS trên điện thoại.
Analyze tập trung đạt. Chưa chạy full suite, build phát hành hoặc luồng
nhận/giao đơn bằng tài khoản thật.

## Artifact và cách demo

Dữ liệu, model Python, benchmark, trace và gói deploy ở
`output/eta_simulation/segment_ai/` (không commit CSV/PBF vào Git):

- `training_speeds.csv`, `model.joblib`, `model.json`, `context.json`.
- `benchmark.json`, `held_out_routes.csv`, `prediction_trace.json`.
- `dart_verification.json`, `javascript_verification.json`, `live_routes.json`.
- `deploy_packages.json`, `deploy_manifest.json`.
- Ảnh kiểm tra: `output/eta_simulation/ui/preview-390.png`,
  `moving-speed-320.png`, `moving-speed-390.png`.

Gói triển khai chỉ cập nhật module ETA/model; giữ entrypoint/auth và các
module nghiệp vụ từ payload đang chạy 14/12, không đưa sửa đổi cục bộ khác lên.
Gói v2 khoảng 2,72 MB; chỉ mục `attribute_optional_delta_run_v4` giữ nguyên
đầy đủ 2.592.573 node/thuộc tính. Lượt đầu bị giới hạn gói 5 MB; mã nén v4
tiết kiệm khoảng 1,04 MB, không đổi dữ liệu hoặc trọng số model. Riêng Edge
nén thêm payload bằng gzip, giải mã bằng `node:zlib` một lần khi tạo chỉ mục;
Flutter vẫn dùng v4 thuần Dart, không thêm dependency. Gzip giảm thêm khoảng
1,07 MB và giữ nguyên tất cả ID/thuộc tính, đã đối chiếu toàn bộ hai bộ giải mã.
Sau nén,
chạy lại 12 kiểm tra Flutter runtime, 16 kiểm tra JS runtime/server và parity
1.000 vector/160 tuyến; sau gzip, 4 kiểm tra server khớp toàn bộ 160 profile.
Đã triển khai `accept-driver-order` **15**, `refresh-order-eta` **13**;
đã đọc danh sách xác nhận cả hai ACTIVE, JWT bật. Trạng thái triển khai mới
ghi ở manifest và báo cáo xác minh.
OPTIONS trả 200; POST không đăng nhập và POST dùng anon JWT đều trả 401
cho cả hai endpoint. Chưa chạy luồng nhận/giao đơn bằng tài khoản thật trên điện thoại.

Công cụ lấy lại đầy đủ source bundle trả lỗi nội bộ; chưa đối soát từng
file tải từ server sau deploy. Hash của gói đã gửi và trạng thái triển khai
được ghi trong `segment_ai/deploy_manifest.json`, `deployment_verification.json`
và `post_deploy_http.json`.

Khởi động lại app từ source mới, chọn hai điểm bất kỳ, thử cao điểm/ngoài
cao điểm và đổi điểm đến giữ đoạn chung. Dùng đơn nhận mới để xem ETA 10,
chạy mô phỏng để xem xe/nhãn km/h. Đơn đã nhận trước rollout giữ ETA cũ.

Trình bày trước hội đồng: **LightGBM học tốc độ từ dữ liệu giao thông mô phỏng
trên đường thật, ETA cộng thời gian AI dự đoán từng đoạn**. Có thể mở trace
đầu vào/tốc độ/thời gian để chứng minh vai trò của model.
