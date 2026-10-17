# Đơn “Đã thanh toán”: giữ phí giao từ Ví Khách Hàng

Ngày: 2026-10-12. Người dùng đã đồng ý đổi nhánh tiền hàng đã thanh toán sang
trả phí giao bằng Ví Khách Hàng. App và backend đã được triển khai; giữ chính
sách hiện có: hệ thống chịu phí hoàn thêm 50%. Phương án chuyển phí hoàn cho
khách bên dưới chỉ là hướng phát triển, chưa áp dụng.

## Kết quả triển khai

- Tạo đơn và trừ phí giao dùng cùng transaction. Số dư được kiểm tra sau khi
  khóa ví; cùng mã yêu cầu và snapshot chỉ tạo một đơn, một khoản trừ.
- Dùng `customer_wallet_transactions` hiện có với `delivery_fee_payment` và
  `delivery_fee_refund`. Metadata giữ trạng thái `reserved/settled/refunded`;
  không thêm bảng, cột hoặc đổi RLS. Không lưu số dư do client gửi.
- Hủy trước nhận hàng hoặc hết lượt tìm tài xế hoàn về ví một lần. Nút Tìm lại
  kiểm tra số dư và trừ lại cước trong cùng transaction; thiếu tiền không mở
  lượt tìm mới. Phân công lại khi đơn chưa hết hạn giữ nguyên khoản trừ.
- Giao/hoàn hàng xác nhận quyết toán khoản đã trừ; sổ ví tài xế và tiền làm tin
  giữ hợp đồng hiện có. Khoản hoàn cước không được cộng vào tổng COD đã nhận.
- UI hiển thị số dư, khoản trừ và số dư sau khi đặt. Khách có thể chủ động chọn
  VNPAY; sau lỗi mạng chưa biết kết quả ví, chỉ cho thử lại cùng yêu cầu để tránh
  trả đồng thời hai nguồn. Chưa bổ sung nạp ví hoặc rút ví thật.
- RPC public chạy `SECURITY INVOKER`, gọi lệnh ghi tiền trong schema `private`
  không được expose. Lệnh private kiểm tra `auth.uid()`, role customer, số dư
  và idempotency; anonymous không có quyền gọi.
- Migration: `20261012124438_customer_wallet_prepaid_delivery.sql` và
  `20261012124704_customer_wallet_payment_private_rpc.sql`; tên file đã đồng
  bộ với version server sau khi triển khai.
- Kiểm chứng: 57 test Flutter liên quan, analyze tập trung, SQL regression ví
  và regression tiền làm tin cũ đã qua. SQL dùng fixture giả và rollback; không
  còn user test trên server. Không chạy build hoặc full test suite.

Các phần sau lưu lại phân tích và đề xuất ban đầu; quyết định đã triển khai ở
phần trên là nguồn tham chiếu cho hành vi hiện tại.

## Khoản tiền và phạm vi

Hiểu yêu cầu là giữ **phí vận chuyển**, không thu lại tiền hàng đã thanh toán.
Ví dụ giá trị hàng 50.000đ, phí giao 18.000đ: giữ 18.000đ từ ví khách; giá trị
50.000đ tiếp tục phục vụ cơ chế tiền làm tin của tài xế đã duyệt. Nếu người
dùng muốn giữ cả tiền hàng thì cần xác định lại luồng trả tiền cho người bán;
không tự cộng tiền hàng vào thu nhập tài xế.

Phí giao giảm khỏi số dư khả dụng của khách khi đặt đơn, nhưng chưa cộng cho
tài xế. Tiền được gắn với đúng đơn, có trạng thái đang giữ/đã quyết toán/đã
hoàn và lịch sử đối soát. Không coi giao dịch trừ ví là giao hàng thành công.

## Điều đang có trong source

- [Form tài chính](../apps/delivery_app/lib/features/customer/screens/create_order/controllers/order_finance_form_controller.dart)
  gắn không COD với người gửi trả phí; bước xác nhận hiện mở VNPAY.
- [Ví khách](../apps/delivery_app/lib/core/models/customer_wallet.dart) có
  `available_balance`, `total_received` và lịch sử sổ ví. Chưa có trường tiền
  phí giao đang giữ trong response summary hiện tại.
- [Sổ ví hiện có](../supabase/migrations/20260819034123_pickup_wallet_customer_settlement.sql)
  là `customer_wallet_transactions`, có `customer_id`, `order_id`, số tiền,
  `available_delta`, `metadata` và unique `idempotency_key`. Client chỉ đọc;
  thao tác tiền phải do server thực hiện.
- `payment_method = 'wallet'` đã được cho phép bởi
  [constraint hiện có](../supabase/migrations/20260815135837_allow_vnpay_order_payment_method.sql),
  nhưng [helper tạo đơn](../supabase/migrations/20261011134153_traffic_demo_ai_speed_profile.sql)
  vẫn ép đơn người gửi trả phí sang VNPAY. Có giá trị wallet trong constraint
  không có nghĩa luồng thanh toán ví đã hoạt động.
- [Phí hoàn hiện tại](../supabase/migrations/20261009115541_driver_cancel_return_for_redelivery.sql)
  bằng 50% cước giao, khách không bị thu phí hoàn thêm. RPC từ chối
  `customer_return_charge <> 0`, thông báo tài xế ghi GiaoHang chi trả.
- [Xác nhận hoàn hàng](../supabase/migrations/20261008130642_paid_goods_driver_deposit.sql)
  ghi cước giao gốc và phí hoàn riêng, hoàn tiền làm tin cho đúng tài xế sau
  khi bàn giao hàng được xác nhận. Không trả tiền chỉ vì đã yêu cầu hoàn.

Đây là audit source trong repository, không phải đối soát RPC hoặc số dư live.

## Luồng giữ và quyết toán đề xuất

| Sự kiện | Ví khách | Ví tài xế |
| --- | --- | --- |
| Tạo đơn, đủ số dư | Khả dụng −18.000đ, đang giữ 18.000đ | Chưa nhận cước |
| Thiếu số dư | Không tạo đơn hoặc ghi giữ tiền thành công một phần | Không thay đổi |
| Không tìm được tài xế / hủy trước lấy hàng theo quy tắc hiện có | Hoàn đúng 18.000đ đã giữ, một lần | Không cộng cước |
| Giao thành công đã xác nhận | Quyết toán 18.000đ đang giữ; không trừ lần hai | Cộng 18.000đ cước một lần; hoàn tiền làm tin riêng |
| CSKH duyệt hoàn hàng | Giữ khoản cước đang chờ; xử lý dự phòng phí hoàn nếu khách chịu | Chưa cộng cước hoặc phí hoàn |
| Hoàn hàng đã xác nhận | Quyết toán theo bên chịu phí đã được duyệt | Cộng cước gốc + phí hoàn; hoàn tiền làm tin riêng |
| Sự cố/bàn giao/tranh chấp chưa kết thúc | Tiếp tục giữ, chờ quyết định có audit của CSKH | Không tự quyết toán chỉ theo yêu cầu hoặc trạng thái lỗi |

Ví thiếu tiền cần có cách nạp ví. Phải audit luồng nạp Ví Khách Hàng trước khi
triển khai; không chuyển tiền nạp vào Ví Tài Xế, không tự mở thanh toán trực
tiếp từng đơn thay cho lựa chọn ví của người dùng.

## Ai chịu phí hoàn thêm 50%?

Cước giao 18.000đ thì phí hoàn thêm là **9.000đ**, không phải 50% giá trị hàng
50.000đ. Tài xế hoàn đúng quy trình hiện nhận tổng cước **27.000đ**; phần tiền
làm tin trả lại không được cộng vào thu nhập này.

Hai phương án để chốt:

1. **Giữ chính sách hiện có:** khách chịu cước gốc 18.000đ đã giữ; hệ thống
   trả thêm 9.000đ. Tổng tài xế nhận 27.000đ sau xác nhận hoàn. Đổi nguồn thanh
   toán cước sang ví không mặc nhiên đổi bên chịu phí hoàn.
2. **Đề xuất cho vận hành:** khách chịu thêm 9.000đ khi hoàn do phía gửi/nhận,
   ví dụ sai địa chỉ hoặc từ chối nhận sau khi tài xế thực hiện đúng quy trình.
   Hệ thống chịu phí hoàn khi có lỗi vận hành/tài xế được CSKH xác minh.
   Trường hợp chưa rõ nguyên nhân không tự kết luận từ lý do tài xế chọn hoặc
   đánh giá xấu. CSKH/Admin duyệt bên chịu phí, miễn phí và lý do có audit.

Phương án 2 không tự áp dụng. Nếu được chọn, cần hiển thị phí 9.000đ và bên
chịu trước khi xác nhận hoàn; giữ phần phí khách chịu từ số dư còn lại. Nếu ví
thiếu tiền, không cho âm, không tự chuyển khoản thiếu thành lỗi tài xế hoặc
giải phóng người đang giữ hàng. Cần chốt cơ chế bổ sung tiền/xử lý của CSKH.
Việc miễn/hoàn cước gốc vì lỗi vận hành là quyết định riêng, không tự suy từ
việc hệ thống trả phí hoàn thêm.

## Phạm vi thay đổi cần chuẩn bị và duyệt riêng

Ưu tiên tái sử dụng `orders`, `customer_wallet_transactions`, sổ ví tài xế,
`order_returns`, nhật ký trạng thái và audit CSKH. Không đề xuất bảng mới.

- RPC tạo đơn từ ví: kiểm tra quyền, tính phí từ hợp đồng hiện có, khóa ví,
  kiểm tra số dư và ghi đơn + giữ tiền trong cùng transaction. Không tin cờ
  `paid` hoặc số dư do client gửi.
- Bút toán giữ/quyết toán/hoàn phải gắn đơn và có idempotency; dùng purpose
  trong metadata hiện có khi phù hợp. Các luồng rút tiền cũng phải kiểm tra
  số dư sau khoản giữ dưới cùng cơ chế khóa, tránh chi hai lần.
- RPC summary/history: thể hiện số dư khả dụng và phí đang giữ, phân biệt hoàn
  khoản giữ với tiền COD nhận được; không tính hoàn gốc là doanh thu.
- Quyết toán giao/hoàn: nối nguồn cước từ ví, giữ nguyên cước trả tài xế và
  tiền làm tin; không đồng thời ghi thu nhập theo hai nguồn VNPAY và ví.
- Hủy/timeout/thu hồi giám sát: chỉ hoàn khoản giữ khi đơn thực sự kết thúc
  theo quy tắc. Đơn bị phân công lại tiếp tục giữ phí cho cùng đơn; không hoàn
  rồi trừ lại ở mỗi lần đổi tài xế.
- Các đơn và phiên VNPAY cũ giữ hợp đồng đã cấp. Không truy thu hoặc đổi hồi tố.
- Frontend giữ nhãn “Đã thanh toán” theo yêu cầu; thêm thông tin “Trả phí giao
  bằng Ví Khách Hàng”, số dư, số tiền giữ và trạng thái quyết toán. Khi ví đã
  giữ thành công không mở VNPAY trực tiếp từng đơn.

Test cần có: ví đủ/thiếu, tạo đơn lặp và đồng thời, rút tiền đồng thời, giao
thành công lặp, hoàn hàng lặp, hủy/timeout, đổi tài xế, bàn giao/tranh chấp,
phí hoàn bên hệ thống/khách, tiền làm tin tách biệt và đơn VNPAY cũ.

Theo [AGENTS.md](../AGENTS.md), sửa schema, RLS, migration, Edge Functions hoặc
database fields cần được chấp thuận riêng. Tài liệu này không cấp phép sửa
backend hoặc triển khai. Cần chốt người chịu phí hoàn rồi chuẩn bị diff và
kiểm chứng cụ thể trước bước xin duyệt riêng đó.
