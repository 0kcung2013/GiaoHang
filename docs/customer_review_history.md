# Lịch sử đánh giá của khách hàng

Điểm vào: **Tài khoản → Hoạt động → Đánh giá của tôi**.

## Giao diện và thao tác

- Danh sách các đánh giá khách đã gửi cho tài xế, mới nhất trước.
- Bộ lọc Tất cả / 5 sao / 4 sao / 3 sao / 2 sao / 1 sao.
- Mỗi thẻ có số sao, thời điểm gửi, nhận xét, nhãn đánh giá, mã đơn và điểm giao.
  Nhận xét hoặc nhãn không có dữ liệu sẽ được bỏ qua.
- Xem đơn hàng mở tab theo dõi theo mã đơn qua route hiện có.
- Kéo xuống để làm mới; Xem thêm tải tiếp 20 đánh giá.
- Phân biệt tải lần đầu, chưa có đánh giá, bộ lọc rỗng và lỗi tải.
  Lỗi tải thêm giữ các thẻ đã có và cho thử lại đúng trang.
- Bộ lọc cuộn cùng danh sách. Nội dung tối đa 640dp; chữ lớn dùng wrap và
  tăng chiều cao thanh tiêu đề. Thao tác chính có vùng chạm tối thiểu 48dp.

## Dữ liệu

Đọc bảng `reviews` hiện có, lọc `reviewer_id` theo phiên hiện tại và
`direction = customer_to_driver`. Bộ lọc sao và phân trang chạy trên server;
sắp xếp theo `created_at DESC, id DESC`. Join trái tới `orders` chỉ lấy
`tracking_code` và `delivery_address`, giữ đánh giá khi quan hệ đơn không đọc được.
Kết quả trả về sau khi đổi phiên bị loại bỏ. Phản hồi từ bộ lọc cũ không được ghi
đè bộ lọc mới.

Không thay đổi schema, RLS, RPC gửi đánh giá hoặc quy tắc đánh giá/điểm vi phạm.

## Kiểm tra tập trung

- `review_history_repository_test.dart`: phạm vi người gửi/chiều đánh giá,
  truy vấn lọc và phân trang, quan hệ đơn trống, đổi phiên khi đang tải.
- `review_history_controller_test.dart`: đổi bộ lọc khi yêu cầu cũ chưa xong,
  lỗi và thử lại tải thêm, làm mới giữ bộ lọc.
- `customer_review_history_ui_test.dart`: trạng thái, bộ lọc, viewport
  390×844, 320×568 chữ 160%, 844×390 chữ 160%, 1280×800.
- `customer_account_ui_test.dart`: điểm vào, quay lại và mở đúng đơn qua route cũ.

Ảnh xem trước từ widget test dùng dữ liệu mẫu, font thay thế trong test và
Material Icons thật. Chưa kiểm tra bằng phiên khách hàng trên thiết bị thật.
