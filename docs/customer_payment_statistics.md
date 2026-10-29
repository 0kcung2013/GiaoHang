# Thống kê thanh toán của khách hàng

Điểm vào: **Tài khoản → Hoạt động → Thống kê giao dịch**.
Phạm vi người dùng chọn: thanh toán đơn hàng qua Ví khách hàng và VNPay.

## Trải nghiệm

- Mặc định tháng hiện tại, có Ngày / Tuần / Tháng, chọn lịch và chuyển kỳ.
- Lọc Tất cả / Ví khách hàng / VNPay áp dụng đồng thời lên tổng, biểu đồ và danh sách.
- Tổng thanh toán thành công và số giao dịch là nội dung chính.
- Đã hoàn tiền, đang giữ trong ví, chờ hoàn và chờ thanh toán hiển thị riêng.
- Biểu đồ cột chồng phân biệt hai phương thức bằng màu, icon và nhãn.
  Chạm cột để xem tổng. Biểu đồ ngày chia 6 giờ, tuần theo ngày, tháng theo nhóm 5 ngày.
- Bảng theo phương thức thể hiện số tiền thành công; danh sách hiển thị mọi trạng thái.
  Ban đầu 5 giao dịch, mỗi lần xem thêm 20. Chạm giao dịch mở chi tiết và mã tham chiếu.
- Nút thông tin giải thích cách tính. Kéo xuống làm mới; lỗi tải không hiển thị tổng tạm
  hoặc số 0 như một kết quả đã xác nhận.

## Ý nghĩa số liệu

Kỳ lọc theo **ngày tạo giao dịch ở Việt Nam (UTC+7)** và **trạng thái hiện tại**.
Đây là thống kê theo nhóm giao dịch gốc, không phải báo cáo luồng tiền phát sinh theo ngày.

| Nguồn | Điều kiện | Nhóm thống kê |
| --- | --- | --- |
| Ví: `delivery_fee_payment` | `completed` + `payment_state=settled` | Thành công |
| Ví: `delivery_fee_payment` | `completed` + `payment_state=reserved` | Đang giữ |
| Ví: `delivery_fee_payment` | `completed` + `payment_state=refunded` | Đã hoàn |
| Ví | `reversed` hoặc không nhận biết | Đảo giao dịch / Cần đối soát |
| VNPay | `paid` | Thành công |
| VNPay | `pending` / `refund_required` / `refunded` | Chờ thanh toán / Chờ hoàn / Đã hoàn |
| VNPay | `failed` / `expired` | Không thành công / Hết hạn |

Khoản hoàn nằm trong kỳ của giao dịch thanh toán gốc. Không trừ hai lần hoặc cộng lại
dòng `delivery_fee_refund`. Một đơn có thể có nhiều lần thanh toán; số giao dịch không
được gọi là số đơn hàng. Tiền COD nhận về ví và phí trả bằng tiền mặt không thuộc hai nguồn này.

## Đọc dữ liệu

Tái sử dụng `customer_wallet_transactions`, `order_payment_sessions` và quan hệ `orders`
để lấy mã đơn. Hai nguồn lọc `customer_id` theo phiên đăng nhập, giới hạn khoảng thời gian,
và phân trang 100 dòng bằng cursor `(created_at,id)`. Tải hết kỳ trước khi hiển thị tổng;
một nguồn lỗi sẽ làm toàn bộ snapshot lỗi. Kết quả trả về sau khi đổi phiên bị loại bỏ.
Không dùng RPC lịch sử ví chỉ trả 10 dòng gần nhất để tính thống kê.

Không thay đổi schema, RLS, RPC, Edge Functions hoặc hành vi thanh toán/hoàn tiền.

## Xác minh

Test tập trung kiểm tra phân loại, tính tổng, nhóm giờ Việt Nam, lọc phương thức,
đọc quá 100 dòng, lỗi một nguồn, quyền sở hữu, đổi phiên, điều hướng từ Tài khoản,
bộ lọc UI, chi tiết và viewport 390×844, 320×568 chữ 160%, 844×390 chữ 160%, 1280×800.
Ảnh widget test dùng dữ liệu mẫu và font thay thế. Chưa xác minh bằng phiên khách hàng
trên thiết bị thật; không chạy full suite hoặc build phát hành.
