# Báo sự cố đơn hàng của tài xế

Tài xế sử dụng một biểu mẫu: chọn lý do, nhập mô tả và đính kèm ảnh. Biểu mẫu không yêu cầu thao tác lấy GPS riêng. Vị trí đang có từ màn hình được gửi kèm nếu có.

| Thời điểm | Lý do hiển thị | Category hiện có |
| --- | --- | --- |
| Chưa xác nhận nhận hàng | Hàng không đúng thông tin | `cargo_issue` |
| Chưa xác nhận nhận hàng | Không thể nhận hàng | `contact_issue` |
| Đã xác nhận nhận hàng | Không thể giao hàng | `contact_issue` |
| Cả hai giai đoạn | Sự cố khác | `other` |

## Yêu cầu hủy nhận đơn vì hàng sai thông tin

- Chỉ áp dụng khi đơn còn `assigned`/`picking_up` và `actual_picked_up_at` chưa được ghi. Trạng thái `picking_up` tự nó không chứng minh tài xế chưa nhận hàng.
- Hàng sai loại, kích thước hoặc trọng lượng bắt buộc có ít nhất một ảnh. Báo cáo không tự động hủy đơn hoặc giải phóng tài xế.
- Đơn mới khai báo khối lượng kg khi đặt hàng. CSKH và tài xế đọc cùng giá trị này; đơn cũ chưa có khối lượng hiện **Chưa khai báo**. Không có trường dài × rộng × cao; hàng quá cỡ được đối chiếu bằng ảnh và mô tả. Xem [Thông tin đơn và liên hệ CSKH](support_order_information.md).
- Khi báo cáo đang mở và chưa có quyết định của CSKH, giao diện khóa xác nhận nhận hàng và cung cấp nút **Xem trao đổi**. Backend cũng chặn RPC nhận hàng và việc ghi trực tiếp trạng thái/mốc nhận hàng.
- CSKH nhận xử lý, xác minh rồi gọi RPC hủy nhận đơn hiện có. Tài xế cũ được giải phóng; đơn khách hàng giữ dữ liệu thanh toán và trở lại tìm tài xế qua luồng OSRM hiện có. Tài xế vừa được hủy không nhận lại lời mời của đơn đó.
- Sau khi xử lý xong, CSKH đóng hồ sơ theo luồng hiện có. Trong lúc hồ sơ còn mở, báo cáo cùng đơn và cùng nhóm sự cố không được tạo lặp; các bên tiếp tục trao đổi trong hồ sơ hiện có.
- Nếu CSKH đóng báo cáo hoặc quyết định cho tiếp tục, chặn nhận hàng được gỡ. Các điều kiện ảnh nhận hàng, vị trí và ký quỹ hiện có vẫn áp dụng.
- Trước khi gạt nhận hàng, tài xế được nhắc kiểm tra loại hàng, kích thước và trọng lượng. Sau khi xác nhận, không được yêu cầu hủy nhận đơn vì các thông tin này nữa. Form mở từ trước cũng bị backend từ chối nếu đã nhận hàng ở phiên khác.

## Phạm vi giữ nguyên

Hội thoại CSKH, R2, dữ liệu khách hàng và các nhóm báo cáo của khách hàng được tái sử dụng. Sự cố người nhận vẫn theo quy định chờ/liên hệ và bằng chứng cuộc gọi hiện có. Những nhiệm vụ hoàn/bàn giao đã được CSKH duyệt trước đó vẫn có thể hoàn tất.

Riêng thay đổi biểu mẫu/bảo vệ nhận hàng không thêm bảng, cột hoặc dịch vụ lưu trữ. Migration `20261011001748_compact_driver_incidents_before_pickup.sql` thay thế ba hàm hiện có và giữ nguyên chữ ký/quyền gọi. Phần bổ sung khối lượng sau đó thêm cột vào bảng `orders` hiện có, được mô tả trong tài liệu thông tin đơn. Các migration đã được áp dụng trên Supabase và kiểm thử SQL đạt sau khi áp dụng.

## Kiểm chứng

- Widget/controller/repository: lý do theo giai đoạn, ảnh bắt buộc, gửi một lần, khóa nhận hàng và mở lại sau khi xử lý; các luồng hỗ trợ/hoàn hàng hiện có.
- Bố cục: màn hình 320×568, 390×844, 1280×800; cỡ chữ 100%/160%; trạng thái bàn phím.
- Đã xem ảnh render widget thật với font của dự án, gồm trước/sau nhận hàng, màn hình nhỏ và màn hình rộng. Ảnh kiểm tra nằm trong `.tmp/driver-incidents/`.
- CSKH: hủy trước nhận hàng, không cung cấp thao tác hủy vì hàng sai thông tin sau nhận hàng, tiếp tục xử lý nhiệm vụ bàn giao đã được duyệt.
- SQL `supabase/tests/driver_incident_before_pickup.sql`: thiếu ảnh, gửi trùng, chặn RPC/ghi trực tiếp khi chờ xử lý, từ chối sau nhận hàng, giải phóng trước nhận hàng, bảo toàn dữ liệu khách hàng/thanh toán và chống lặp audit. Dữ liệu kiểm thử được rollback.

Kiểm thử SQL không xác nhận tài xế tiếp theo được mời tức thì: việc tính tuyến và gửi lời mời qua OSRM diễn ra ở bước xử lý nền. Chưa chạy toàn bộ test suite, build phát hành hoặc kiểm thử trên điện thoại thật.
