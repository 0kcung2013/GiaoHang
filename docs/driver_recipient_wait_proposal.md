# Không liên lạc được người nhận — luồng đã chốt

## Luồng hiện tại

1. Tài xế xác nhận đã đến điểm giao; thời gian chờ 10 phút được ghi nhận bằng
   giờ server. Trong lúc chờ, tài xế gọi/nhắn người nhận và có thể liên hệ CSKH.
2. Đủ 10 phút vẫn không gặp được người nhận, tài xế gửi **báo cáo kèm yêu cầu
   hoàn** trong một lần. Cần vị trí và ảnh rõ số người nhận, ít nhất 3 cuộc gọi
   trong thời gian chờ. CSKH xác minh bằng chứng trước khi quyết định.
3. Ứng dụng hiển thị **Chờ CSKH duyệt**, giữ hàng và chờ hướng dẫn. Không có
   vòng chờ thêm 15 phút hoặc thao tác gửi yêu cầu lần hai cho báo cáo mới.
4. CSKH hướng dẫn tiếp tục giao hoặc duyệt hoàn bằng luồng `order_returns`
   hiện có. Hết hạn phản hồi của CSKH không tự cấp phép hoàn.

Tai nạn, mất an toàn, sai địa chỉ, hàng hóa và thanh toán được báo ngay;
không áp dụng mốc chờ người nhận hoặc tự kèm yêu cầu hoàn.
Báo cáo liên hệ của khách hàng hoặc trước khi lấy hàng giữ hành vi hiện có.

## Triển khai bằng hợp đồng dữ liệu hiện có

Yêu cầu hoàn được ghi ở đầu mô tả khi tạo báo cáo `contact_issue` của tài xế
đang `delivering`, cùng ảnh, vị trí và nội dung tài xế nhập. Giữ kiểm tra quyền
báo cáo trên server ở thời điểm gửi. Không tạo thêm case hoặc cần một lần gửi
tin nhắn thứ hai để hoàn tất yêu cầu. Giới hạn nhập mô tả chừa chỗ cho yêu cầu,
không cắt nội dung tài xế khi gửi.

Màn chờ chỉ theo dõi báo cáo của đúng tài xế, đơn còn `delivering`, can thiệp
đang `awaiting_triage`. Khi CSKH quyết định hoặc báo cáo đóng, màn chờ được
gỡ để luồng chỉ dẫn/hoàn hiện có tiếp tục. Mở lại app đọc trạng thái đã gửi từ
báo cáo, không chạy lại đồng hồ hoặc tự gửi yêu cầu trùng.

Báo cáo cũ chưa có yêu cầu hoàn cho gửi ngay trong case hiện tại sau khi
kiểm tra lại quyền 10 phút và quyết định CSKH. Lịch sử tin nhắn nhận diện cả
yêu cầu từ phiên bản cũ; yêu cầu đã gửi không xuất hiện nút gửi lại.

Nút **Chat với CSKH** mở cuộc trao đổi của chính báo cáo đang chờ duyệt.
Tin nhắn công khai gắn với `risk_report_id`, xuất hiện trong tab **Trao đổi**
của báo cáo ở CSKH; không tạo hay dùng lại ticket trong **Chat hỗ trợ**.
Chat hỗ trợ chung trong menu chuyến đi vẫn dùng `ticket_id` và độc lập.
Không mở lại form tiến độ báo cáo cũ.
**Khách gọi giao lại** mở điều kiện phí 5.000đ/km, người nhận thanh toán,
rồi trao đổi CSKH; chưa phát sinh báo giá hoặc khoản thu.

Không sửa schema, RPC, RLS, migrations, Edge Functions, trạng thái đơn hoặc
quyền nhận đơn. Deadline CSKH hiện có được theo dõi riêng.

## Những phần cần duyệt backend riêng

Chưa mở nhận đơn mới khi đang giữ hàng. Trang chủ, RPC nhận đơn, điều phối và
index `orders_one_active_per_driver_idx` hiện giới hạn một nhiệm vụ hoạt động
cho mỗi tài xế. Nếu mở tính năng này, cần tái sử dụng trạng thái `risk_hold`
và audit hiện có, bảo toàn trách nhiệm giữ hàng, xếp chờ giao lại/hoàn đến khi
tài xế rảnh và đồng bộ nhiệm vụ GPS. Không thêm bảng chỉ để phục vụ màn chờ.

Báo giá/thu phí giao lại cần quãng đường đường bộ, vị trí server xác thực,
xác nhận của người nhận và audit tài chính. Đây là phạm vi cần duyệt riêng;
chưa triển khai trong thay đổi luồng chờ này.

## Kiểm chứng

Kiểm tra tập trung: mốc 9:59/10:00 và quyền server, bằng chứng bắt buộc,
báo cáo kèm yêu cầu hoàn một lần, retry/mở lại không gửi trùng, tương thích
báo cáo cũ, mất mạng, quyết định CSKH, chat trực tiếp và báo cáo sự cố khẩn cấp.
Kiểm tra bố cục 320×568, 390×844 và chữ 160%; không chạy full suite hoặc build
toàn app.
