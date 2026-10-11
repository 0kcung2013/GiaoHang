# SmartTraffic ETA — triển khai ngày 2026-10-11

Người dùng đã duyệt tích hợp và triển khai theo
[đề xuất](../../docs/smarttraffic_eta_integration_proposal.md).
Model `smarttraffic_hcm_speed_v1` gồm 187 cây, dự đoán vận tốc từ giờ, thứ và
cờ cuối tuần theo múi giờ Việt Nam. Đây là dữ liệu mô phỏng, không phải giao thông
thời gian thực. Dữ liệu chỉ một tuần nên chưa chứng minh khả năng tổng quát hóa.

## Cách tính

OSRM cung cấp tuyến và khoảng cách. Chia khoảng cách từng chặng thành phần tối đa
250 m; cộng `km / vận tốc dự đoán × 60`, dịch thời điểm dự báo theo thời gian
đã cộng trong cùng lần tính. Hai chặng: tài xế → điểm lấy → điểm giao.
Thêm 5 phút chuẩn bị, 5 phút nhận và 5 phút bàn giao. Không nhân hệ số K cũ.
25 km/h chỉ dùng dự phòng khi ngoài phạm vi demo hoặc AI không khả dụng.

ETA giữ cố định theo phân công; chỉ bỏ 5 phút chuẩn bị một lần khi GPS đáp ứng
điều kiện xuất phát sớm hiện có. Hạn giao giữ ETA ban đầu + 25 phút.
Phân công đã có ETA không bị tính lại khi đổi model. Không thêm bảng, đổi RLS
hay pipeline GPS/R2. Không dùng dữ liệu GPS ứng dụng để train.
Phần demo đã được duyệt riêng bổ sung `orders.traffic_demo_key` và validation
RPC tạo đơn/thanh toán, dùng 07:00 và 14:00 trên cùng tuyến. Chi tiết và hướng
dẫn vận hành tại [traffic_demo_speed.md](../../docs/traffic_demo_speed.md).

## Triển khai và đối soát

- `accept-driver-order`: phiên bản 7, ACTIVE, `verify_jwt: true`.
- `refresh-order-eta`: phiên bản 5, ACTIVE, `verify_jwt: true`.
- Lượt triển khai demo cập nhật truy vấn trong hai entrypoint và `delivery_eta.mjs`,
  thêm `delivery_eta_speed_profile.mjs`; giữ nguyên model và các file remote khác.
- Đọc lại cả hai function: toàn bộ file khớp hoàn toàn với bản triển khai.
- HTTP OPTIONS trả 200, POST không xác thực trả 401 ở cả hai endpoint.
- Backup remote trước triển khai nằm tại `output/smarttraffic_eta/rollback/`.

## Kiểm chứng và giới hạn

- 8 kiểm thử Python pipeline đạt ở lượt tích hợp model; 46 kiểm thử Node
  ETA/deadline đạt sau khi bổ sung profile demo.
- Parity Python, JavaScript và Dart trên 10.080 mốc phút trong tuần;
  thêm 16 trường hợp tuyến đi qua ranh giới giờ/ngày.
- Kiểm thử Flutter tập trung cho model, quote, bản đồ, demo và ETA đạt;
  lượt cuối hai file `order_eta_test` và `traffic_demo_comparison_test`: 28 đạt.
- Analyze tập trung đã sạch sau khi sửa hai cảnh báo dấu ngoặc khối;
  kiểm tra whitespace không có lỗi.
- 72 kiểm thử Flutter demo/GPS/map/order và 10 kiểm thử giám sát bổ sung đạt.
- Kiểm tra widget ở nhiều kích thước và cỡ chữ; đã xem ảnh marker, nhãn km/h,
  Start/Stop với font và icon tại 320/390 px, cỡ chữ 1,6 lần. Chưa xem trên
  thiết bị thật.
- Chưa tạo đơn mới để kiểm thử toàn luồng khách hàng/tài xế/CSKH trên server;
  HTTP 401 chỉ kiểm chứng cổng xác thực, không chứng minh luồng có JWT.
- Chưa build phát hành. Cần hot restart/chạy lại Flutter để nạp cây model mới.

Các artifact nghiên cứu giữ cờ chưa duyệt runtime để lần train sau không tự phát
hành. Quyền triển khai ở đây chỉ áp dụng bản xuất đã kiểm chứng nêu trên.
