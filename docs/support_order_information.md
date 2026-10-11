# Thông tin đơn và liên hệ CSKH

## Thay đổi đã thực hiện

CSKH dùng cùng một khối thông tin trong hồ sơ sự cố, hội thoại gắn với đơn và hộp chi tiết ở trang tra cứu. Màn hình rộng chia hai cột; màn hình hẹp hoặc chữ lớn chuyển thành một cột có thể cuộn.

| Nhóm | Thông tin |
| --- | --- |
| Hàng hóa đã khai báo | Tên, danh mục, khối lượng kg, mô tả, ảnh khi đặt đơn có thể mở lớn và ghi chú giao hàng |
| Hành trình và liên hệ | Địa chỉ/tọa độ lấy và giao; tên/điện thoại/email người gửi; tên/điện thoại người nhận; tên/điện thoại/email tài xế đang được phân công |
| Thanh toán | Giá trị hàng, COD, phí giao, tổng tiền, người trả phí, phương thức/trạng thái thanh toán, khoản tài xế thu người nhận, ứng/ký quỹ và thực nhận |
| Thời gian và dịch vụ | Dịch vụ, giờ tạo/cập nhật, ETA, hạn giao, mốc nhận/giao/hủy nếu có |

Số điện thoại có nút sao chép. Trong hội thoại có lối mở trao đổi riêng với người gửi/tài xế; tiếp tục tái sử dụng hồ sơ đang mở đúng người yêu cầu và cùng chủ đề. Không tạo một hội thoại chung cho mọi bên.

Tên/điện thoại không được thay bằng UUID. Dữ liệu chưa khai báo hiển thị rõ trạng thái thiếu. Khi chưa có tài xế, ETA hiện **Chờ tài xế nhận đơn**. Không hiển thị ETA lưu của tài xế cũ sau khi đổi phân công.

## Khối lượng hàng hóa

- Form đặt đơn mới bắt buộc nhập số kg lớn hơn 0; nhận dấu `,` hoặc `.` và tối đa ba chữ số thập phân, ví dụ `2,75` hoặc `0.5`.
- Giá trị đi qua bước xác nhận, đơn COD và payload phiên thanh toán trước. Tài xế thấy khối lượng trong chi tiết kiện hàng và form báo cáo.
- Đơn cũ giữ `NULL`, hiển thị **Chưa khai báo**. Không điền mặc định `0 kg` hoặc suy đoán khối lượng.
- Không thêm trường kích thước, không tự đặt giới hạn kg theo xe. Khối lượng không làm thay đổi tiền, ETA hoặc cách phân công.
- Chỉ được yêu cầu CSKH hủy phân công vì hàng sai thông tin/quá cỡ khi chưa xác nhận nhận hàng; cần mô tả và ít nhất một ảnh. Sau khi nhận hàng, yêu cầu này bị chặn cả ở giao diện và backend.
- CSKH xác minh rồi hủy phân công bằng luồng hiện có: giải phóng tài xế và đưa đơn trở lại tìm tài xế. Gửi báo cáo tự nó không hủy đơn.

## Supabase

Không tạo bảng mới. Hai migration đã áp dụng:

1. `20261011005214_order_cargo_weight_kg.sql`: thêm `orders.item_weight_kg` kiểu numeric nullable và CHECK số hữu hạn, dương, tối đa ba chữ số thập phân; cập nhật hai hàm tạo đơn/phiên thanh toán hiện có. Payload cũ không có kg vẫn hoạt động.
2. `20261011005913_support_order_contacts.sql`: thêm RPC chỉ đọc `get_support_order_contacts(p_order_ids uuid[], p_report_id uuid DEFAULT NULL)`, được người dùng chấp thuận riêng. Tái sử dụng `private.require_risk_staff()` để giới hạn CSKH/Admin, giới hạn tối đa 200 mã đơn mỗi lần và chỉ đọc các liên hệ thuộc các đơn đó. Người báo cáo được đọc qua hồ sơ đúng đơn, kể cả khi tài xế đó đã được giải phóng.

`users_select_own` vẫn giữ nguyên: CSKH không được SELECT trực tiếp hồ sơ người khác. RPC chỉ trả định danh liên kết, tên, điện thoại, email, avatar và role của người báo cáo; không trả hồ sơ KYC hoặc quyền đọc mọi cột của `users`. Tài khoản khách hàng/tài xế, phiên không xác thực và quyền anon không được dùng RPC. Client đọc liên hệ theo một lần cho cả lô đơn, tránh một RPC cho từng dòng. Nếu phân công đổi giữa hai lần đọc, client không ghép liên hệ tài xế mới với ID tài xế trong snapshot cũ.

Supabase Advisor có thêm [cảnh báo dự kiến về RPC SECURITY DEFINER được authenticated gọi](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable). Đây là quyền gọi có chủ đích để đọc liên hệ qua bộ kiểm tra CSKH/Admin; kiểm thử dưới role authenticated xác nhận các role khác bị từ chối và SELECT trực tiếp vẫn bị RLS chặn. Các cảnh báo cũ khác không thay đổi.

## Kịch bản kiểm tra thủ công

1. Đặt đơn với kg trống/0/số âm/chữ: không qua bước xác nhận. Nhập `2,75`: xác nhận hiện `2,75 kg`.
2. Tạo đơn thu khi giao và đơn thanh toán trước. Mở bằng CSKH/tài xế: cùng tên hàng, khối lượng, ảnh và các khoản tiền đã khai báo.
3. Ở CSKH mở thông tin đơn trong hồ sơ sự cố, hội thoại và tra cứu: có tên/số điện thoại thật của người gửi, người nhận và tài xế. Sao chép từng số, kiểm tra không nhầm bên.
4. Mở đơn cũ: khối lượng hiện **Chưa khai báo**; đơn chưa có tài xế hiện chưa được phân công và chờ ETA.
5. Tài xế chưa gạt nhận hàng báo hàng quá cỡ: thiếu ảnh không gửi được; có ảnh gửi được, vẫn giữ phân công trong khi CSKH xử lý và không thể xác nhận nhận hàng lúc yêu cầu còn chờ.
6. CSKH đối chiếu ảnh khi đặt đơn, kg và ảnh thực tế, xác minh và hủy phân công: tài xế được giải phóng, dữ liệu đơn/thanh toán giữ nguyên. Hồ sơ vẫn hiển thị người báo cáo cũ; CSKH đóng hồ sơ khi hoàn tất xử lý.
7. Tài xế đã gạt nhận hàng: không có lựa chọn yêu cầu hủy vì sai loại/kích thước/kg; biểu mẫu cũ hoặc RPC gửi lại cũng bị từ chối.
8. Đổi phân công rồi tải lại thông tin: liên hệ hiển thị theo tài xế hiện tại, không dùng ETA của tài xế trước. Trong hội thoại có nút **Tải lại thông tin đơn** để lấy snapshot mới. Thu hẹp cửa sổ và tăng cỡ chữ lên 160%: nội dung cuộn được, nút liên hệ/sao chép sử dụng được.

## Kiểm chứng đã chạy

- Analyze tập trung các file sửa trong delivery_app, operations_web và giaohang_domain.
- Test form bắt buộc, model/payload kg, lệnh tạo đơn và xác nhận tiền; form sự cố và điều kiện nhận hàng.
- Test thông tin CSKH ở 320×568 chữ 160%, 882×849 và 1280×850; đơn cũ, lỗi tải/lấy lại dữ liệu, liên hệ qua RPC ở ba repository và tránh ghép nhầm tài xế khi đổi phân công.
- Test màn tra cứu, hồ sơ CSKH, bằng chứng và thao tác can thiệp hiện có.
- SQL `order_cargo_weight_kg.sql`, `support_order_contacts.sql`, `driver_incident_before_pickup.sql`: lưu kg qua hai luồng, giá trị không hợp lệ, payload cũ, quyền đọc liên hệ và bảo vệ nhận hàng/hủy phân công. Dữ liệu kiểm thử được rollback.
- Đã render và xem widget thật ở kích thước rộng/hẹp, chữ 100%/160%; ảnh ở `.tmp/support-order-information/`.

Chưa chạy full test suite, build phát hành hoặc kiểm thử trên điện thoại thật.
