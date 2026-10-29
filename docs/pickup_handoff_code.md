# Xác nhận bàn giao hàng bằng mã

Được người dùng duyệt triển khai và thay đổi Supabase ngày 2026-10-19.

## Quy tắc

- Chỉ người tạo đơn được mở mã 4 số. Người giao hàng thực tế có thể phối hợp
  nhận mã từ người tạo đơn; không cấp quyền đọc mã cho tài xế hoặc CSKH.
- Mốc chuyển trách nhiệm giữ hàng là lúc server xác nhận thành công.
- Ảnh nhận hàng và kiểm tra phạm vi 100 m vẫn bắt buộc. Tải ảnh không xác nhận
  bàn giao; tài xế phải nhập mã của người tạo đơn.
- Sau xác nhận, đơn chuyển sang `delivering`. Không hủy hoặc đưa về tìm tài xế
  khác theo luồng thông thường. Dùng luồng CSKH/hoàn trả/bàn giao đã có.
- Mã có hiệu lực 15 phút kể từ lần mở đầu tiên. Hết hạn thì người tạo đơn mở
  lại để nhận thử thách mới. Mở lại mã còn hạn không thay đổi mã.
- Nhập sai 5 lần khóa nhập mã 5 phút. Đây chỉ là khóa thử mã của lần phân công,
  không phải điểm vi phạm hoặc khóa đăng nhập/nhận đơn mới.
- Đổi tài xế hoặc hủy trước bàn giao vô hiệu thử thách cũ. Xác nhận thành công
  tiêu thụ thử thách và giữ biên nhận; gọi lại không tạo thêm sự kiện/thu tiền.

## Dữ liệu và quyền

Tái sử dụng `orders` và `order_status_logs`, không tạo bảng nghiệp vụ mới.
`orders.pickup_handoff` chỉ chứa nonce, định danh các bên, hạn, lượt sai,
khóa nhập hoặc biên nhận đã xác nhận. Không chứa mã hoặc hash mã.

Mã được suy ra bằng HMAC từ đơn, người tạo đơn, tài xế và nonce ngẫu nhiên;
khóa bí mật chỉ nằm trong Supabase Vault (`pickup_handoff_hmac_key`). Dữ liệu
đơn qua SELECT/Realtime không đủ để suy ra mã. Không ghi mã vào log hoặc push.

- `get_customer_pickup_code(uuid)`: kiểm tra `auth.uid()` trùng người tạo đơn,
  trả mã còn hạn hoặc biên nhận nếu đã nhận hàng.
- `confirm_driver_pickup_code(uuid,text)`: chỉ tài xế đang được phân công; khóa
  dòng đơn, kiểm tra mã, sự cố, bằng chứng/vị trí và ví; ghi biên nhận và gọi
  luồng chuyển trạng thái hiện có trong cùng giao dịch.
- Hai RPC public dùng `SECURITY INVOKER`, ủy quyền cho lệnh có kiểm tra người
  dùng trong schema `private`. Hàm suy ra mã không cấp EXECUTE cho client.
- Sai mã trả kết quả `success=false`, không ném lỗi SQL làm rollback lượt sai.
- `confirm_driver_pickup(uuid)` cũ chỉ đọc lại mốc đã xác nhận, không được
  tạo mốc nhận hàng mới. API chuyển trạng thái và UPDATE trực tiếp cũng không
  được bỏ qua mã; client không được sửa metadata bàn giao hoặc chủ đơn.

Khóa dòng tuần tự hóa hủy/xác nhận: hủy trước thì mã không khôi phục được đơn;
xác nhận trước thì hủy không xóa trách nhiệm giữ hàng. Giờ được lấy lại sau
khi có khóa dòng để không dùng thời gian cũ trong lúc chờ khóa.

## Giao diện

Khách mở mã tại theo dõi hoặc chi tiết đơn. Mã mặc định che, tự ẩn khi hết hạn,
đổi trạng thái/phân công hoặc đưa app xuống nền. Sau bàn giao hiển thị biên nhận.
Chi tiết đơn theo dõi Realtime để cập nhật quyền hủy khi nhận hàng thành công.

Tài xế nhập mã ở form nhận hàng, cùng ảnh và checklist. Lỗi mã/mạng giữ form,
ảnh và nội dung nhập để thử lại; không tải lại cùng ảnh trong một form. Đang
xác nhận thì chặn thao tác xác nhận lặp và đóng form bằng nút back.

## Triển khai và kiểm tra

Backend đã áp dụng trên project DATN. Cần chạy/phát hành phiên bản mới của cả
hai app để dùng giao diện mã. App cũ không thể nhận kiện mới bằng ảnh đơn thuần.
Các mốc nhận hàng đã có trước rollout tiếp tục được bảo vệ bằng thời điểm cũ.

`supabase/tests/customer_pickup_cancellation_regression.sql` tạo đơn thử riêng,
kiểm tra quyền, chống bỏ qua, khóa/expiry, đổi tài xế, hủy trước/sau, geofence,
thiếu ảnh và gọi lặp; toàn bộ fixture, ví và nhật ký được rollback.

Flutter có kiểm tra service, thẻ mã ở 320/390/1200dp với chữ 160%, form nhận hàng
với bàn phím trên màn hình ngắn, thử lại khi sai mã và navigation sau xác nhận.

Đã chạy 35 test Flutter, 5 lượt render và analyze tập trung. Các SQL regression
về mã/hủy đơn, tiền làm tin tài xế, phí trả qua ví khách hàng, sự cố trước nhận,
CSKH thu hồi và phân công lại đều đã qua trên Supabase, với dữ liệu rollback.
Test phân công lại mô phỏng lời mời sau khi worker routing bất đồng bộ hoàn tất.
Chưa build phát hành hoặc kiểm tra trên thiết bị thật.

Vault tham khảo: https://supabase.com/docs/guides/database/vault
