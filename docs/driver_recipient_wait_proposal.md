# Chờ người nhận và giao lại — phương án cần duyệt backend

## Yêu cầu đã chốt

- Sau khi tài xế đủ điều kiện báo cáo không liên lạc được người nhận (đã chờ
  10 phút tại điểm giao), chờ thêm **15 phút từ lúc server tạo báo cáo**.
- Trong khoảng này tài xế có thể nhận đơn mới, vẫn giữ hàng của đơn chờ.
- Form giữa màn hình: mã đơn, thời gian còn lại, khách gọi giao lại,
  phí **5.000đ/km**, người nhận thanh toán; có thể thu gọn và mở lại.
- Phí tính từ vị trí tài xế khi khách gọi lại đến điểm giao ban đầu,
  dựa trên quãng đường đường bộ. Không cộng phí mở cửa của chuyến giao đầu.
- Hết 15 phút tự hiện yêu cầu xin phép hoàn hàng về nơi lấy. Đây là yêu cầu
  cho CSKH, không tự bắt đầu hoàn hàng hoặc bỏ qua lệnh CSKH.

## Phần frontend đã làm, dùng backend hiện có

Form theo dõi báo cáo `contact_issue` của đúng tài xế và chỉ hiện khi can thiệp
đang `awaiting_triage`, đơn còn `delivering`. Quyết định của CSKH hoặc báo cáo
đã đóng sẽ bỏ form. Thời điểm gửi và giờ server từ RPC arrival hiện có quyết
định đồng hồ; mở lại app không khởi động một khoảng 15 phút mới.

Form phí thể hiện điều kiện tính phí, chưa phát sinh khoản thu hoặc tổng phí.
Nút trao đổi mở đúng cuộc hội thoại báo cáo hiện có. Hết giờ, tài xế có thể gửi
tin nhắn yêu cầu hoàn trong báo cáo; kiểm tra lại giờ và can thiệp trước khi
gửi, hiển thị trạng thái đã gửi. Đọc lịch sử tin nhắn để giữ trạng thái khi mở lại.
Tin nhắn không tạo lệnh hoàn; CSKH duyệt bằng luồng `order_returns` hiện có.

**Chưa mở nhận đơn mới.** Trang chủ đang ẩn đơn mới khi có đơn `delivering`.
`accept_order`, `claim_free_pick_order` và điều phối server cũng kiểm tra đơn
đang hoạt động. Index `orders_one_active_per_driver_idx` cấm cùng một tài xế
có hai đơn `assigned`, `picking_up`, `delivering`, `return_approved`, `returning`.
Chỉ bỏ kiểm tra UI hoặc RPC sẽ không giải quyết được index và dễ lệch trạng thái.

## Phạm vi backend đề nghị duyệt riêng

1. Tái sử dụng `orders.status = risk_hold`, `risk_reports`,
   `risk_report_interventions`, `risk_report_events.details` và
   `order_status_logs`. Không cần bảng mới, không thay đổi index một nhiệm vụ
   đang hoạt động cho mỗi tài xế. Tạo bản ghi trạng thái chờ trong audit hiện có
   với hạn 15 phút, lý do, người thực hiện. Chỉ cho báo cáo tài xế `contact_issue`
   đã vượt kiểm tra 10 phút chuyển đơn sang chờ; báo cáo khác giữ hành vi cũ.
2. Sửa RPC tạo báo cáo/can thiệp và kiểm tra nhận đơn/điều phối để phân biệt
   đơn đang chờ người nhận với nhiệm vụ đang di chuyển. Đơn chờ vẫn giữ
   `driver_id` và trách nhiệm bảo quản hàng. Các khóa nhận đơn, phê duyệt tài xế,
   online và ví vẫn có hiệu lực. Bảo vệ chuyển trạng thái bằng khóa transaction.
3. Sửa các chuyển trạng thái driver/support để không tự đưa đơn chờ trở lại
   `delivering` khi tài xế đang thực hiện một đơn mới. Giao lại/hoàn hàng phải
   xếp chờ đến khi tài xế rảnh, tránh xung đột index và gián đoạn đơn mới.
4. RPC đọc trạng thái chờ trả `server_now`, `wait_until`, quyền nhận đơn,
   quyền yêu cầu giao lại/hoàn. Không dùng giờ thiết bị để cấp quyền.
   Giữ deadline CSKH 10 phút hiện có tách biệt khỏi cửa sổ chờ khách 15 phút.
5. RPC báo giá/xác nhận giao lại lấy vị trí tài xế server đã xác thực, tính
   quãng đường đường bộ, trả tổng phí cùng đơn giá 5.000đ/km và người trả.
   Người nhận xác nhận tổng phí trước khi thu. Ghi audit và dùng tài chính/thu
   tiền hiện có; không tin tổng phí Flutter gửi. Không dùng đường chim bay khi
   routing lỗi; giữ yêu cầu chờ và báo chưa lấy được báo giá.
6. RPC yêu cầu hoàn có idempotency, kiểm tra hết 15 phút và chỉ dẫn hiện hành;
   CSKH cho phép bằng luồng hoàn hiện có. Không tự chuyển sang `returning`.
7. Đồng bộ danh sách tài xế/khách/CSKH và bộ chọn nhiệm vụ GPS: đơn chờ được
   đánh dấu rõ, chỉ nhiệm vụ đang di chuyển chiếm navigation/tracking. Không
   thay đổi nơi lưu GPS, R2, secrets hoặc retention.

Không thay đổi schema/RPC/index/migrations/Edge Functions ở bước frontend này.
Phần phía trên là phạm vi để duyệt, chưa phải migration đã chạy.

## Kiểm chứng frontend

36 test tập trung đã qua trong `driver_recipient_wait_test.dart`,
`driver_delivery_arrival_wait_test.dart`, `driver_risk_instruction_test.dart`
và `driver_navigation_pickup_resume_test.dart`. Analyze 10 file thay đổi/test
không có vấn đề. Đã render ba form ở 390×844 và 320×568 với chữ 160% trên
màn hình nhỏ; nội dung dài cuộn được. Ảnh kiểm tra dùng font Segoe UI thay
font Jakarta để render offline, chưa kiểm chứng trên thiết bị thật.
Không chạy full suite hoặc build toàn app.

## Kiểm tra khi backend được duyệt

Gửi báo cáo ở 9:59 bị từ chối, 10:00 được tạo; chờ 15 phút không reset sau mở
lại app; đơn contact của người khác không mở quyền; retry không tạo báo cáo,
phí hoặc yêu cầu hoàn trùng. Hai lệnh nhận đồng thời chỉ một thành công.
CSKH cho phép giao/hoàn khi tài xế có đơn mới phải xếp chờ; hoàn tất đơn mới
mới kích hoạt nhiệm vụ tiếp theo. Mất GPS/routing/Realtime không được tự thu
phí, cấp quyền hoặc kết thúc đơn. Bằng chứng, ví và trạng thái thu tiền phải
nhất quán trong một transaction; rà soát deadline giao muộn của đơn tạm chờ
để không phạt tài xế cho thời gian chờ xử lý đã được xác nhận.
