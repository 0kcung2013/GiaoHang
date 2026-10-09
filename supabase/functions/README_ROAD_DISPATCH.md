# Phân công theo quãng đường

- PostgreSQL kiểm tra tài xế online, approved, GPS trong 3 phút, khóa nhận đơn,
  đơn đang giao/hoàn, lời mời khác, rejected_by và số dư ví.
- PostGIS lọc rộng 2,2 km; 200 m bổ sung phục vụ sai lệch snap của routing.
  Khoảng cách này chỉ giảm số tọa độ gửi OSRM.
- OSRM Table tính hướng **tài xế → điểm lấy**, xử lý mọi ứng viên theo batch.
  Xếp theo độ dài tuyến được OSRM đề xuất, thời gian rồi user ID khi bằng nhau.
  Profile driving của server công cộng tìm tuyến nhanh; không khẳng định tuyến
  có độ dài nhỏ nhất tuyệt đối hoặc ETA có dữ liệu giao thông thời gian thực.
- RPC commit khóa đơn và tài xế, xác minh quote còn trong 30 giây và tài xế chưa
  di chuyển quá 30 m, rồi kiểm tra lại điều kiện nhận đơn. Giới hạn tự động 2 km
  là quãng đường; lời mời 45 giây và thời hạn tìm tài xế 15 phút được giữ lại.
- Trigger đơn mới, reject, retry, online và cron timeout gọi cùng dispatcher.
  pg_net chỉ gửi request sau khi transaction commit. Cron hiện có chạy mỗi 5 giây.
  Vault giữ secret xác thực giữa PostgreSQL và Edge; không đưa xuống app.
- Redis dùng lease 55 giây, cache theo tọa độ trong 20 giây và giới hạn gọi OSRM.
  Dispatcher mất lease không được commit. OSRM lỗi thì đơn chờ cron thử lại;
  không fallback sang đường chim bay.
- FreePick tìm đơn trong vòng trên 2 đến 3 km theo đường, cập nhật lại sau 25 giây.
  Bản đồ không vẽ vòng tròn đường chim bay để biểu diễn giới hạn quãng đường.
  Edge kiểm tra JWT và lấy quote mới khi nhận đơn; RPC trực tiếp không có proof
  không thể nhận FreePick. Quote là dữ liệu tạm, không thêm cột hoặc bảng.

## Triển khai

Các function dùng secrets Supabase và Upstash đã có. Có thể đặt OSRM_BASE_URL
để dùng routing server riêng; mặc định dùng router.project-osrm.org.

Deploy các Edge Functions và áp dụng migration
20261009004506_road_distance_driver_dispatch.sql và migration
free_pick_three_km_road_limit. dispatch-road-orders tắt
gateway JWT vì tự xác thực bằng secret Vault; các endpoint app bật JWT.

## Kiểm tra tập trung

node --test supabase/functions/_shared/road_distance_test.mjs supabase/functions/_shared/road_redis_test.mjs

SQL regression: supabase/tests/road_distance_dispatch_regression.sql.
Transaction dùng các account tài xế/khách có sẵn và rollback toàn bộ dữ liệu thử.
Kiểm tra HTTP transport qua net._http_response mà không xuất request headers.
