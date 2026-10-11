# Hạn giao hàng

Chính sách được duyệt ngày 11/10/2026:

```
Hạn giao = ETA ban đầu (initial_predicted_at) + 25 phút
```

Tái sử dụng orders.estimated_delivery_at, orders.delivery_eta và
order_status_logs; không thêm bảng/cột. ETA vẫn tính theo hai chặng đường
ở 25 km/h, chuẩn bị 5 phút, nhận hàng 5 phút, bàn giao 5 phút và LightGBM
khi có dữ liệu. Không cộng 30%, 15 phút hay nhân LightGBM lần nữa vào hạn.

accept-driver-order nhận đơn qua RPC hiện có, sau đó tính ETA dùng chung
với refresh-order-eta. commit_order_delivery_eta khóa dòng, lưu ETA và hạn
trong cùng transaction; kết quả đầu tiên thắng. RPC nhận đơn giữ tham số
route_duration_s để tương thích nhưng không dùng nó tính hạn nữa.
Nếu GPS cũ hoặc OSRM lỗi, nhận đơn vẫn thành công, ETA/hạn chờ dữ liệu;
refresh-order-eta thử lại. Không phát sinh hạn giả từ công thức cũ.

Hạn được tính từ initial_predicted_at, không từ predicted_at đã giảm.
Khởi hành sớm chỉ trừ 5 phút khỏi ETA; hạn không đổi. Đến sớm, đổi trạng thái,
mở lại app hay gọi lại API không kéo dài hạn. Phân công lại xóa ETA/hạn cũ
và tính mốc mới cho lượt nhận mới. JWT, quyền RPC server và FreePick giữ nguyên.

Migration chuyển các đơn còn hoạt động có ETA cố định sang chính sách mới,
ghi audit; đơn hoạt động chưa có ETA bỏ hạn cũ và chờ ETA. Không sửa đơn
đã hoàn tất/hủy, không tính lại khóa đã phát sinh.

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

Kiểm chứng: 25 kiểm thử Node ETA và hai kịch bản SQL rollback
(staged_delivery_eta.sql, driver_delivery_deadline_lightgbm.sql) đạt.
Edge accept-driver-order v5 ACTIVE, JWT bật. Chưa kiểm thử trên thiết bị.
