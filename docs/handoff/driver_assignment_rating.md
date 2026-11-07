# Chọn tài xế khi bằng khoảng cách — 2026-11-03

## Hành vi

Ưu tiên khoảng cách đường bộ OSRM từ tài xế đến điểm lấy, tăng dần. Nếu khoảng
cách bằng nhau chính xác, ưu tiên `drivers.rating` cao hơn. Điểm này là trung
bình sao khách hàng đánh giá tài xế qua các đơn đã giao; luồng review hiện có
lưu một chữ số thập phân. Không dùng tổng sao, số đơn hoàn tất hoặc số lượt
đánh giá làm tiêu chí ưu tiên mới.

Ví dụ: A và B cùng cách 1.000 m, A đạt 4,2 sao và B đạt 4,9 sao → mời B trước.
Nếu A cách 999,9 m thì mời A trước. Không làm tròn khoảng cách hoặc bổ sung
dung sai; hai giá trị hiển thị cùng 1,0 km chưa chắc bằng nhau khi so sánh.

Tài xế chưa có đánh giá có rating null; dùng 0 riêng khi xếp hạng và không ghi
0 trở lại hồ sơ. Nếu cả khoảng cách và rating đều bằng nhau, backend giữ thứ
tự thời gian OSRM ngắn hơn rồi mã tài xế tăng dần. Flutter giữ mã tài xế tăng
dần như trước. Lời mời đã gửi còn hiệu lực và phân công đã nhận được giữ nguyên;
quy tắc mới có hiệu lực ở lần tìm/gửi lời mời tiếp theo.

## Triển khai

Người dùng đã duyệt riêng việc sửa và áp dụng backend ngày 2026-11-03.
Migration `20261103072351_driver_rating_distance_tiebreak.sql` đã áp dụng lên
DATN qua MCP, khớp version trong migration history. Không chạy lại migration.

- `road_dispatch_candidates` bổ sung rating hiện tại vào JSON gửi cho Edge.
- `road_lookup_candidates` thêm rating vào thứ tự khi bằng khoảng cách.
  Edge vẫn tính đường bộ cho toàn bộ ứng viên trước khi giới hạn kết quả.
- `commit_road_driver_offer` đọc rating trực tiếp từ `drivers` khi quyết định
  cuối cùng, bỏ qua điểm rating trong JSON quote. Khóa và kiểm tra điều kiện
  tài xế, ví, GPS, giữ đơn, bán kính và thời hạn tiếp tục dùng luồng hiện có.
- Shared helper `road_distance.mjs` thêm rating giữa khoảng cách và thời gian.
  Đã deploy `dispatch-road-orders` v3, `verify_jwt=false` như trước (xác thực
  bằng secret hiện có); `find-nearest-drivers-redis` v20, `verify_jwt=true`.
- `NearestDriverService` thêm rating trước mã tài xế cho phân phối lời mời
  và tìm người tiếp theo sau từ chối/chuyển đơn. Flutter cần hot restart hoặc
  bản app mới; phần quyết định phân công tự động ở server đã có hiệu lực.

Không thêm bảng/cột, RLS policy, dependency, biến môi trường hoặc secret.
Tái sử dụng `drivers.rating`, RPC, Redis/OSRM và cấu hình sẵn có; không thay
cách tính rating hoặc pipeline GPS/R2. Ba RPC vẫn chỉ cho `service_role` gọi.

## Kiểm chứng

- `flutter test test/nearest_driver_offer_allocation_test.dart --reporter expanded`
  tại `packages/giaohang_mobile`: 12 test đạt, gồm gần hơn, bằng khoảng cách,
  chưa có rating, bằng cả rating, loại người từ chối và chia đơn khác tài xế.
- `dart analyze lib/core/services/nearest_driver_service.dart test/nearest_driver_offer_allocation_test.dart`:
  không có lỗi.
- `node --test supabase/functions/_shared/road_distance_test.mjs`: 17 test đạt,
  gồm rating cao hơn dù thời gian dài hơn, không làm tròn khoảng cách, null,
  thứ tự ổn định và ứng viên ở batch OSRM sau.
- Chạy trên DATN: `driver_rating_tiebreak_regression.sql`,
  `road_distance_dispatch_regression.sql`, `recipient_hold_automatic_dispatch.sql`.
  Cả ba đạt; fixture, điểm rating, lời mời, thông báo và giao dịch ví đều rollback.
  Test mới còn xác nhận quote giả rating không thay thế được rating ở database.
- Supabase Security Advisor không báo finding cho ba RPC vừa sửa; kiểm tra
  quyền trực tiếp xác nhận `anon`/`authenticated` không gọi được các RPC này.
  Advisor vẫn có các finding ở đối tượng/cấu hình khác ngoài phạm vi thay đổi.
- Không chạy full test suite, build app hoặc E2E giao diện vì không sửa UI.

SQL regression cần hai tài khoản tài xế thử nghiệm đang rảnh và một khách
hàng. Nó khóa ngắn hai hồ sơ và luôn rollback; không chạy cùng lúc các SQL
fixture dùng chung tài xế. OSRM được giả lập trong Node test; SQL test dùng
quote hợp lệ theo hợp đồng server, không gọi public OSRM.

## Đối soát và khôi phục

Khi thứ tự không như mong đợi, đối chiếu khoảng cách OSRM chưa làm tròn,
`drivers.rating` và điều kiện đủ tư cách nhận đơn. Tài xế rating cao vẫn có
thể bị loại do offline, GPS cũ, thiếu số dư, khóa nhận đơn, đang thực hiện
nhiệm vụ khác hoặc đã từ chối đơn đó. Kiểm tra cả RPC quyết định cuối, không
chỉ thứ tự JSON Edge. OSRM lỗi vẫn để đơn chờ theo luồng hiện có.

Bản định nghĩa ba RPC ngay trước triển khai được lưu tại
`docs/proposals/driver_rating_tiebreak/rollback.sql`. Nếu cần khôi phục, so
với server hiện tại trước để giữ các bản vá không liên quan mới hơn, rồi tạo
migration rollback riêng; không sửa migration đã áp dụng. Edge có thể bỏ dòng
so sánh rating trong shared helper và deploy lại cả hai function, giữ nguyên
thiết lập JWT. Khôi phục Flutter tương ứng nếu cần. Không sửa điểm rating,
tọa độ, trạng thái đơn hoặc số dư thật để ép thứ tự; không cần backfill dữ liệu.
