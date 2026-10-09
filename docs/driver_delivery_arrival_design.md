# Đến điểm giao và báo cáo sự cố

## Giao diện

- Trước khi đến: gạt “Đã đến nơi giao hàng” bị khóa, hướng dẫn đến gần điểm giao.
- Đến gần: mở thao tác gạt; GPS gần điểm giao chưa tự ghi nhận thời gian chờ.
- Gạt thành công: chuyển thanh chính sang “Gạt đã giao”, bên dưới hiển thị “Chờ 10:00 · Báo sự cố”.
- Đủ 10 phút: mở “Không liên lạc được với khách”. Không bắt tài xế chờ mới được hoàn tất giao hàng.
- Form gọn, nền trắng, điểm nhấn cam; bản đồ vẫn là nội dung chính.
- Báo cáo bắt buộc ảnh lịch sử cuộc gọi thể hiện ít nhất 3 lần gọi người nhận trong 10 phút chờ tính từ mốc gạt đã đến. Có thể một ảnh thể hiện nhiều lần gọi; không đồng nhất 3 cuộc gọi với 3 ảnh.
- Tái sử dụng báo cáo sự cố, ảnh bằng chứng và audit hiện có. CSKH đối chiếu số người nhận, giờ gọi và ảnh rồi quyết định xử lý hoàn hàng; ảnh tải lên không tự chứng minh nội dung cuộc gọi và không tự động duyệt hoàn hàng.
- Tai nạn/an toàn, hàng hóa, địa chỉ và thanh toán vẫn báo được ngay.

Danh sách tài xế hiện có 4 lựa chọn chính: an toàn, địa chỉ, liên lạc/bàn giao,
hàng hóa. “Thanh toán / sự cố khác” mở thêm hai lựa chọn. Chỉ lựa chọn đang chọn
hiển thị mô tả. Giữ category hiện có để CSKH đọc và xử lý như trước.

## Triển khai được duyệt ngày 2026-10-03

`DriverDeliveryArrivalRegion` nối vào `DriverNavigationView` và quản lý snapshot server,
refresh khi trở lại app, thử lại và thời gian chờ. `DriverDeliveryWaitCard` vẫn là
component trình bày độc lập. Thanh tác vụ thực tế dùng `DriverNavigationArrivalBar` để
không xếp thêm một card lớn che bản đồ. Có “Giao hàng ngay” trước khi gạt đến.

Migration `20261003131306_driver_delivery_arrival_wait.sql` đã áp dụng lên Supabase, tái sử dụng
`order_status_logs`: mốc có title “Tài xế đã đến điểm giao”, `logged_by` là tài xế,
`created_at` do server ghi. Unique index theo đơn/tài xế và khóa đơn chống gạt lặp;
trigger bảo vệ mốc khỏi client giả hoặc sửa. Không thêm bảng, cột, enum hay storage.

RPC `confirm_driver_delivery_arrival` xác minh role, tài xế được phân công,
đơn đang delivering, vị trí trong `drivers` mới trong 60 giây và cách điểm giao
không quá 100m. Flutter đồng bộ một vị trí mới qua pipeline hiện có trước khi gọi.
RPC `get_driver_delivery_arrival` trả mốc, `server_now` và `can_report_recipient`.
Stopwatch chỉ giúp hiển thị trôi giữa các lần đọc; không cấp quyền báo cáo.

Trigger trước INSERT báo cáo chặn `contact_issue` của tài xế khi đang delivering
nếu chưa có mốc hoặc chưa đủ 10 phút. Constraint trigger cuối transaction bắt buộc
ảnh trong `risk_report_attachments`, tương thích RPC ghi report rồi ghi attachments.
Các đường menu hỗ trợ, `initialCategory` và RPC trực tiếp đều chịu kiểm tra server.
Form kiểm tra ảnh bắt buộc và đọc lại quyền server trước khi upload/gửi.

Audit `risk_report_events` dùng loại `note_added` hiện có để lưu thời điểm bắt đầu,
kết thúc cửa sổ gọi, yêu cầu ít nhất 3 cuộc gọi và hướng dẫn CSKH xác minh. Ghi chú
hiển thị giờ Việt Nam trong lịch sử xử lý hiện có. Ảnh dùng R2 client/prefix hiện tại.
Server kiểm tra có ảnh; CSKH kiểm tra nội dung ảnh và quyết định hoàn hàng theo
luồng đã có. Không tự động kết luận ảnh chứng minh đủ cuộc gọi.

Khi mở lại app, tải lại mốc từ server. Lỗi xác nhận không bắt đầu đếm; cho thử
lại. Luồng lấy hàng dùng cơ chế hiện có và không chịu quy tắc chờ người nhận.
Không thêm enum order status chỉ để biểu diễn trạng thái UI này.

## Kiểm tra

`supabase/tests/driver_delivery_arrival_wait_regression.sql` chạy trong transaction
và rollback fixture. Bao gồm quyền, GPS cũ/xa, gạt lặp, chưa gạt, trước/đủ 10 phút,
ảnh bắt buộc, báo an toàn trước 10 phút, audit CSKH và không tự tạo lệnh hoàn.
Widget/controller tests bao gồm snapshot server, gạt đến/giao riêng, ảnh một tấm
có thể thể hiện ba cuộc gọi, khóa theo quyền server và mobile/chữ phóng lớn.

## Sửa lỗi xác nhận ngày 2026-10-03

Log thực tế trả `DELIVERY_LOCATION_STALE`. Cập nhật latest GPS trước đây gửi
`DateTime.now().toIso8601String()` theo giờ local, thiếu múi giờ. Database UTC
diễn giải giờ Việt Nam thành thời điểm ở tương lai 7 giờ và từ chối xác nhận.
`location_updated_at` và `updated_at` nay gửi UTC có hậu tố `Z` qua luồng hiện có.
Không sửa dữ liệu vị trí của đơn thật bằng tay; lần đồng bộ tiếp theo thay thế
thời gian sai. Điều kiện vị trí mới 60 giây, bán kính 100m và chờ 10 phút giữ nguyên.

Thử lại sau lỗi gạt thực hiện lại lấy/đồng bộ vị trí và RPC xác nhận, thay vì chỉ
tải snapshot. Thông báo phân biệt GPS cũ, xa điểm giao, quyền vị trí và timeout.
`location_ingest_arrival_timestamp_test.dart` kiểm tra chuỗi ingest → xác nhận
với Edge hoạt động và fallback, kể cả tài xế đứng yên gửi lại. Widget regression
kiểm tra lỗi GPS → thử lại → bắt đầu chờ, chưa mở báo cáo.
