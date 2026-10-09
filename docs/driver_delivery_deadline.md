# Hạn giao hàng

Tái sử dụng `orders.estimated_delivery_at` và `order_status_logs`. Không thêm
bảng hoặc cột. Mốc này cũng là thời gian giao dự kiến hiển thị cho khách hàng;
dùng để ghi nhận giao muộn và áp dụng khóa nhận đơn theo quy tắc đã duyệt bên dưới.

Edge Function `accept-driver-order` xác minh JWT bằng getUser, lấy tọa độ trên
server và gọi OSRM cho tuyến tài xế → điểm lấy → điểm giao. Chỉ server được
gọi RPC mới, RPC tiếp tục gọi accept_order/claim_free_pick_order hiện có để giữ
quyền nhận đơn, khóa nhận đơn, phạm vi FreePick và kiểm tra ví.

Thời gian cho phép = max(25, ceil(thời gian tuyến tính bằng phút × 1.3 + 15)).
Thời điểm bắt đầu lấy từ clock_timestamp của server khi nhận đơn. Nhận đơn và
lưu deadline nằm trong cùng transaction. Gọi lại không kéo dài mốc đã lưu.
Client không gửi tọa độ, thời lượng hoặc deadline; không được tự sửa deadline.

OSRM timeout sau 4 giây hoặc trả dữ liệu lỗi: dùng khoảng cách địa lý × 1.5,
tốc độ giả định 20 km/h. Nếu thiếu GPS mới của tài xế, thêm 15 phút dự phòng.
Ghi nguồn fallback trong nhật ký; không coi dữ liệu fallback là bằng chứng lỗi.

Đơn cũ đang assigned/picking_up/delivering nhưng thiếu mốc được khởi tạo một lần
khi mở điều hướng, tính từ thời điểm server hiện tại để không phạt hồi tố.
Đơn đã có mốc, đơn đã hủy/hoàn tất và giao dịch ví không bị thay đổi bởi backfill.
App phiên bản cũ vẫn có thể gọi RPC nhận đơn cũ, và được bổ sung hạn khi mở
điều hướng bằng phiên bản mới. Mốc đã có vẫn giữ nguyên khi GPS/route đổi.

Đã duyệt quy tắc tự khóa nhận đơn ngày 2026-10-02: 3 đơn giao muộn hoàn tất
trong 2 giờ gần nhất khóa nhận đơn mới 30 phút. Trigger dùng giờ server,
chỉ tính đơn có nhật ký backend cấp hạn, ghi sự kiện trong order_status_logs
và đánh dấu 3 đơn đã dùng để không khóa lại từ các đơn đó. Đơn chưa hoàn tất,
hủy/hoàn hàng, thiếu hạn hoặc ETA cũ không được tính. Không có phạt hồi tố.

Dùng lại drivers.acceptance_locked_until; giữ nguyên khóa đang có nếu còn
hiệu lực, ý định online và đơn đang giao. Thông báo khóa dùng notifications
hiện có. Không mở lại form quy định đã được người dùng yêu cầu bỏ.

Quy tắc này không kết luận nguyên nhân/lỗi tài xế và không tạo điểm vi phạm
14 ngày. Không cần CSKH xác nhận từng đơn; CSKH vẫn xử lý khiếu nại theo
luồng hiện có. Các thời gian dự phòng/fallback do backend cấp hiện cũng áp
dụng quy tắc này. Chưa có cơ chế miễn trừ tự động do chờ người nhận.

Chưa triển khai trạng thái đến điểm giao. Thời gian trên Flutter là phần
hiển thị theo đồng hồ thiết bị; bộ kiểm tra quá hạn chạy hoàn toàn trên server.
