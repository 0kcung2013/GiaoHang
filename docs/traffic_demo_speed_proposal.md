# Demo AI theo tốc độ tuyến

Đã được người dùng duyệt và triển khai ngày 2026-10-11. Kết quả và hướng dẫn:
[traffic_demo_speed.md](traffic_demo_speed.md).

Phạm vi người dùng đã chốt: hai lựa chọn cùng tuyến, tốc độ AI quyết định ETA,
màu polyline và chuyển động Start/Stop; marker tròn có nhãn km/h; UI không thêm
nhãn mô phỏng hoặc nút tăng tốc.

## Backend cần duyệt riêng

- Thêm một cột nullable `orders.traffic_demo_key` (`peak` / `off_peak`), không bảng mới.
  Cột `delivery_eta` hiện có bị reset khi phân công lại, nên không thích hợp để
  giữ lựa chọn của khách từ trước nhận đơn xuyên qua mọi lần phân công.
- Cập nhật private RPC tạo đơn và validation trước mở thanh toán để lưu allowlist.
  Không đổi chữ ký RPC, RLS, phí, thanh toán hoặc dữ liệu đơn cũ.
- Cập nhật hai Edge Function ETA: lấy giờ AI theo lựa chọn, còn timestamp ETA/hạn
  vẫn tính từ giờ nhận đơn thật. Lưu tuyến OSRM và profile vận tốc trong JSON
  `delivery_eta` hiện có để client dùng cùng kết quả; đây không phải lịch sử GPS.
- Giữ pipeline GPS/R2; gửi tốc độ theo payload hiện có và bổ sung tốc độ vào
  broadcast realtime phía client. Chỉ lưu tọa độ mới nhất ở drivers như hiện tại.

SQL: [traffic_demo_speed_proposal.sql](traffic_demo_speed_proposal.sql).
Phần vận tốc thực nghiệm: dataset có trung bình gần 30 km/h vào 07:00 và gần
50 km/h vào 14:00; chọn hai khoảng tránh ranh giới chuyển giờ cao điểm.
Hai lựa chọn dùng cùng điểm lấy (10.784900,106.668400) và giao
(10.793838,106.651842). Vị trí tài xế lấy từ phiên GPS hiện có; để so sánh demo,
đặt lại cùng điểm xuất phát trước mỗi đơn.

## Kiểm chứng

So sánh cùng khoảng cách, ETA cao điểm lớn hơn; tốc độ chuyển động/profile/màu
khớp ETA; dừng/tiếp tục không mất vị trí; dừng vẫn gửi mẫu mới; đổi chặng phải
Start lại; mở lại giữ Stop; GPS thường không bị chuyển sang nguồn giả;
không đổi ETA của phân công đã tính và không dùng giờ mô phỏng cho giám sát.
