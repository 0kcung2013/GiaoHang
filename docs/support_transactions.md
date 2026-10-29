# Giao dịch cho CSKH

## Phạm vi

Route `/support-transactions` trong Operations Web, hỗ trợ support/admin.
Ba nhóm: nạp ví tài xế VNPAY; thanh toán đơn bằng VNPAY/ví khách;
hoàn phí giao và hoàn khoản giữ ví tài xế. Tiền mặt/COD thu ngoài hệ thống
xem trong chi tiết đơn, không suy diễn thành giao dịch thanh toán đã xác minh.

Tìm theo mã giao dịch/mã VNPAY, mã đơn, tên, số điện thoại; lọc trạng thái và
ngày tạo. Ngày kết thúc bao gồm cả ngày được chọn, truyền lên server bằng
mốc đầu ngày kế tiếp (exclusive). Phân trang bằng thời gian và mã nguồn + ID,
không tải toàn bộ lịch sử hoặc cắt cố định 200 dòng.

Chi tiết có số tiền, thay đổi ví, mã đối soát, thời gian ghi nhận/hạn thanh toán,
đơn liên quan và yêu cầu hỗ trợ. Tạo yêu cầu tái sử dụng support_tickets và luồng
hội thoại/ghi chú sẵn có, kèm tham chiếu giao dịch trong nội dung. Người giao
dịch và đơn gốc được giữ cố định. Không tạo bảng liên kết riêng.

Phiên quá hạn vẫn `pending` sẽ hiện cảnh báo chờ xác nhận; giao diện không tự
đổi thành thất bại hay ghi nhận hoàn tiền. API chỉ trả mốc thời gian đang có,
không tạo lịch sử sự kiện giả từ metadata.

## API chỉ đọc đã duyệt

Người dùng đã duyệt riêng API và migration ngày 2026-10-20.
SQL chính thức: [20261021142936_support_transactions_read_api.sql](../supabase/migrations/20261021142936_support_transactions_read_api.sql).
Đã áp dụng riêng migration qua Supabase MCP ngày 2026-10-21 vào dự án DATN
`erlpzwfbpjogvaulcxni`. Tên file được đồng bộ với version ghi nhận trên server.

- Public RPC `list_support_transactions` là SECURITY INVOKER.
- Hàm private STABLE/SECURITY DEFINER kiểm tra `auth.uid()` và role trong users
  trước khi đọc dữ liệu; anon/customer/driver bị từ chối.
- Tái sử dụng driver_wallet_transactions, customer_wallet_transactions,
  order_payment_sessions, users và orders. Không cấp SELECT đại trà vào users,
  không đổi RLS, bảng/cột hoặc các RPC ghi tiền.
- Dữ liệu trả về giới hạn trường cần thiết; không trả order_payload hoặc toàn bộ
  metadata, thông tin JWT/secrets, và không gọi cổng thanh toán.
- Mỗi trang mặc định 30, tối đa 100; điều kiện tìm được tham số hóa.

Supabase MCP đã kết nối lại đúng dự án. Regression chỉ đọc chạy thành công
trên dữ liệu thật với role authenticated/JWT claims của CSKH, Admin, khách và
tài xế; anon không có quyền EXECUTE. Ba nhóm khớp ledger gốc: 17 nạp, 15 thanh
toán, 24 giải phóng/hoàn tại thời điểm kiểm tra. Phân trang live dùng trang
2 dòng để kiểm tra hết các trang, không chỉ một trang mặc định.

Nếu môi trường khác chưa cài API, giao diện hiển thị lỗi API chưa được cài đặt,
không hiển thị danh sách rỗng như thể hệ thống chưa có giao dịch.

## Kiểm tra đã chạy

- 35 test Flutter tập trung: nhóm giao dịch, repository, controller, tạo yêu cầu,
  tra cứu đơn, điều hướng CSKH và thông báo hỗ trợ đều đạt.
- Analyze feature, router, scaffold và các test mới không có lỗi.
- 23 kiểm tra SQL và script regression chỉ đọc đã đạt trên PostgreSQL/PGlite
  tạm thời, với fixture theo schema migrations. Không thay database runtime.
- Đã xem ảnh render danh sách và chi tiết ở 1366×768 và 375×568, chữ 160% ở
  màn hình hẹp. Dữ liệu render là fixture, không phải giao dịch thực tế.
- Đã chạy `supabase/tests/support_transactions_read_api_regression.sql` trên
  Supabase thật; kiểm tra số lượng, phân trang không trùng, tối thiểu dữ liệu
  trả về và quyền từng vai trò. Không ghi ledger hoặc gọi VNPAY.
- Chưa kiểm tra end-to-end bằng phiên trình duyệt CSKH; chưa build phát hành.

## Phần còn cần kiểm tra bằng trình duyệt

Mở tab bằng phiên CSKH thật để xác minh dữ liệu, ảnh và điều hướng liên quan.
Kiểm thử filter ngày/tìm kiếm và cursor cùng timestamp đã có ở PostgreSQL
cô lập; regression live không chèn fixture vào ledger để tạo trạng thái giả.
