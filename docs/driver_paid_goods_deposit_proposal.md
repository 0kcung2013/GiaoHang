# Tiền hàng làm tin cho đơn đã thanh toán

Ngày: 2026-10-08. Trạng thái: người dùng đã duyệt; mã app đã tích hợp và backend
đã triển khai migration
[20261008130642_paid_goods_driver_deposit.sql](../supabase/migrations/20261008130642_paid_goods_driver_deposit.sql).

Bản render Flutter: [Chưa giữ tiền](../.tmp/driver-ui/paid-deposit-required.png),
[Đang giữ tiền](../.tmp/driver-ui/paid-deposit-held.png),
[Đã hoàn tiền](../.tmp/driver-ui/paid-deposit-refunded.png),
[Nhập giá trị hàng](../.tmp/driver-ui/paid-deposit-customer.png).

## Chính sách đã triển khai

Đơn chọn **Đã thanh toán** vẫn cần giá trị hàng để giữ tiền làm tin của tài xế.
Tiền giữ bằng 100% giá trị hàng khai báo. Khoản này được hoàn vào ví khi giao
thành công và không phải thu nhập. Phí giao vẫn thanh toán qua luồng VNPAY hiện tại.

| Thời điểm | Ví tài xế | Trang Thông tin đơn |
| --- | --- | --- |
| Nhận đơn | Kiểm tra đủ số dư; chưa trừ | Tiền làm tin · Chưa giữ tiền |
| Xác nhận lấy hàng | Giảm số dư khả dụng, tăng tiền đang giữ | Đang giữ tiền làm tin |
| Đang giao | Giữ nguyên tiền làm tin | Hoàn vào ví khi giao thành công |
| Giao thành công, có giao dịch hoàn | Hoàn toàn bộ tiền giữ và cộng cước riêng | Đã hoàn tiền cọc giữ hàng · +số tiền |
| Đã giao, chưa tải được giao dịch hoàn | Tải lại dữ liệu ví | Chờ xác nhận hoàn tiền |
| Dữ liệu tiền giữ/hoàn không khớp | Yêu cầu CSKH đối soát | Cần kiểm tra ví |

Ví dụ: ví có 500.000đ, hàng 120.000đ, cước 25.000đ. Sau nhận hàng: khả dụng
380.000đ, đang giữ 120.000đ. Sau giao thành công: khả dụng 525.000đ, đang giữ
0đ, thu nhập 25.000đ. Tiền hoàn 120.000đ không làm tăng doanh thu báo cáo.

## Màn hình khách hàng

- Khi chọn Đã thanh toán, vẫn nhập **Giá trị hàng**. Không dùng ô thu hộ để
  suy đoán số tiền làm tin và không lấy lại số tiền COD cũ một cách ngầm định.
- Gợi ý: “Dùng để giữ tiền làm tin của tài xế.”
- Với đơn mới áp dụng chính sách này, giá trị phải lớn hơn 0 và không vượt
  2.000.000đ, cùng giới hạn nhập tiền hàng hiện có. Backend kiểm tra lại.
- Số tiền người nhận trả vẫn là 0đ. VNPAY vẫn chỉ thu phí giao như luồng hiện tại;
  giá trị hàng đã thanh toán ngoài app không được cộng lại vào tiền VNPAY.
- Tái sử dụng `goods_value` và payload hiện có. Giá trị hàng là snapshot tại
  lúc tạo đơn; không cho thay đổi sau khi đã có tài xế nhận.

## Màn hình tài xế

- Thẻ đơn mới giữ bố cục đã thống nhất: thực nhận, quãng đường, điểm lấy/giao.
  Ảnh và thông tin hàng chỉ hiện sau khi nhận đơn.
- Trang Thông tin đơn có thẻ thanh toán với ba khoản: **Thu người nhận**,
  **Tiền làm tin**, **Thu nhập giao hàng**. Màu navy/cam theo AppColors; trạng thái
  hoàn dùng nền xanh nhạt kèm chữ và icon xác nhận.
- Tiền làm tin hiện rõ trạng thái Chưa giữ → Đang giữ → Đã hoàn. Số dư thiếu chỉ
  hiện trước khi giữ; không yêu cầu nạp lại khoản tiền đã giữ.
- Xác nhận lấy hàng hiện thông báo giữ tiền làm tin thay cho thông báo ứng COD.
  Đơn được xác nhận nhận hàng và khoản giữ cùng một transaction backend; nếu
  thiếu tiền, cả hai không được ghi thành công.
- Hộp thoại giao thành công tách tiền hoàn và thu nhập. Chỉ ghi **Đã hoàn tiền
  cọc giữ hàng** khi đã đọc được giao dịch hoàn hoàn tất thuộc chính đơn/tài xế đó.
- Lịch sử ví dùng “Giữ tiền làm tin” / “Hoàn tiền làm tin”; tab Thu nhập chỉ tính
  cước. Không suy ra hoàn tiền từ trạng thái đơn hoặc từ chênh lệch số dư toàn ví.
- Giữ nút MAP và luồng Hủy đơn hiện có.

## Tái sử dụng dữ liệu và sổ ví

Không cần bảng mới, cột mới, loại giao dịch mới, RLS mới hoặc Edge Function mới.
Sổ `driver_wallet_transactions` hiện có đủ `order_id`, `driver_id`, `metadata`,
`available_delta`, `held_delta` và unique `idempotency_key`.

Phân biệt trường hợp bằng `cod_collection_amount`, không chỉ nhìn `prepaid`:
trong backend hiện tại, `prepaid` mô tả người gửi trả cước trước. Một đơn có
người gửi trả cước trước vẫn có thể yêu cầu thu hộ tiền hàng.

- Có COD: giữ cơ chế ứng và quyết toán COD hiện tại, không giữ thêm tiền làm tin.
- Không COD, phí đã trả, giá trị hàng hợp lệ, đơn mới áp dụng chính sách:
  `driver_advance_amount = goods_value` là số dư cần thiết để giữ tiền làm tin.
- `receiver_collection_amount`, `driver_net_earning` và tiền VNPAY không cộng
  khoản làm tin. Đơn cũ có advance bằng 0 không tự áp dụng ngược chính sách.

| Bút toán | Loại có sẵn | available_delta | held_delta | metadata |
| --- | --- | --- | --- | --- |
| Giữ khi nhận hàng | `cod_hold` | −giá trị hàng | +giá trị hàng | `purpose: paid_goods_deposit` |
| Hoàn khi giao/hoàn hàng xác nhận | `cod_release` | +tiền đã giữ | −tiền đã giữ | cùng purpose, kèm lý do hoàn |
| Cước giao trả trước | `prepaid_earning` | +cước thực nhận | 0 | luồng thu nhập hiện có |

Idempotency key phải gồm đơn, tài xế và bước nghiệp vụ, ví dụ
`order:{orderId}:driver:{driverId}:paid_goods_deposit_hold` và
`order:{orderId}:driver:{driverId}:paid_goods_deposit_release`. Tổng hoàn không
vượt tổng giữ thật của tài xế đó. Retry hoặc hai yêu cầu đồng thời không tạo
thêm giao dịch hay ghi thu nhập hai lần.

Lấy toàn bộ giao dịch liên quan đến một đơn và một tài xế từ bảng đã có RLS.
Không lấy 30/100 dòng lịch sử ví rồi kết luận một đơn cũ đã/ chưa hoàn.
Khi tải lỗi hiển thị trạng thái chưa xác minh và thao tác thử lại; không dùng
giá trị local để ghi “đã trừ” hoặc “đã hoàn”.

## Thay đổi backend đã được duyệt

1. `create_customer_order_payment_session`: kiểm tra giá trị hàng trước khi
   tạo phiên VNPAY; server ghi `paid_goods_deposit_version: 1` trong JSON payload
   hiện có cho đơn không COD. Tiền VNPAY vẫn chỉ là phí giao.
   `private.create_customer_order_from_payload` dùng marker server này để tính
   snapshot. Phiên thanh toán cũ chưa có marker vẫn hoàn thành với advance bằng 0.
2. `confirm_driver_pickup`: kiểm tra ví, ghi `cod_hold` có purpose, xác nhận
   nhận hàng trong một transaction. Giữ kiểm tra quyền, chứng từ và custody.
3. `advance_driver_order_status`: không capture COD hoặc trừ lần nữa cho tiền
   làm tin khi bắt đầu giao; khi giao xong ghi release và cước một lần, cùng
   transaction cập nhật trạng thái đơn.
4. Quyết toán khách hàng trong `advance_driver_order_status` và
   `confirm_risk_custody_resolved`: dùng số tiền COD thực tế, không dùng
   `driver_advance_amount` đã bao gồm khoản làm tin. Tránh chuyển nhầm tiền giữ
   của tài xế sang ví khách hàng.
5. `confirm_order_return` và các luồng xử lý custody/handoff có hoàn tiền:
   đối soát đúng tài xế giữ hàng và bút toán có purpose; release tiền làm tin
   sau khi bàn giao/trả hàng được xác nhận. Không refund chỉ vì có yêu cầu hoàn.
6. Rà soát luồng hủy/CSKH giải phóng tài xế để không giải phóng tiền giữ khi vẫn
   còn giữ kiện. Hủy trước nhận hàng chưa có hold nên không có tiền để hoàn.

Các helper private giữ/hoàn dùng chung khóa ví, đối soát ledger và idempotency;
client không có quyền gọi trực tiếp. Guard thanh toán hiện có bảo vệ snapshot và
chặn cập nhật trực tiếp trạng thái/mốc giao nhận để bỏ qua RPC giữ/hoàn.
Trigger guard được mở rộng từ các cột thanh toán sang toàn bộ UPDATE, vẫn giữ
quyền truy cập và các guard custody/geofence hiện có.
RPC phân đơn/nhận đơn vẫn kiểm tra `driver_advance_amount`, không đổi chữ ký.
Đã kiểm thử nhận đơn đủ số dư và từ chối khi thiếu; cả hai chưa ghi hold.

## Hủy, hoàn và sự cố

- Hủy trước nhận hàng: không có tiền làm tin bị trừ.
- Sau nhận hàng: tài xế không tự hủy để giải phóng tiền; tiếp tục dùng luồng
  CSKH, trả hàng hoặc bàn giao hiện có.
- Hoàn hàng/bàn giao đã xác nhận: hoàn khoản đã giữ cho đúng tài xế. Tài xế
  nhận tiếp chỉ giữ tiền theo snapshot và sự xác nhận custody của chính mình.
- Rủi ro/mất hàng/tranh chấp: tiền vẫn giữ chờ quyết định CSKH/Admin có audit.
  Không tự tịch thu tiền, chuyển cho khách hoặc hoàn chỉ dựa vào trạng thái lỗi.
- Đơn đang xử lý và phiên thanh toán cũ không bị truy thu. Client mới cần nhập
  giá trị hàng cho đơn đã thanh toán; client cũ gửi giá trị bằng 0 bị từ chối
  tạo phiên trước khi thu tiền VNPAY. Cần chạy bản app cập nhật cho đơn mới.

## Trạng thái thực hiện và kiểm tra

`DriverGoodsDepositRegion` tải ledger theo đúng đơn/tài xế và cập nhật khi ví
thay đổi. Thẻ tài chính runtime, Thông tin đơn, thông báo nhận hàng và giao thành
công đã nối vào luồng thật. Form khách hàng nhập riêng giá trị hàng đã thanh toán,
không tự lấy lại số COD cũ. Lịch sử ví đổi nhãn theo purpose; báo cáo thu nhập
tiếp tục loại khoản giữ/hoàn gốc.

Kết quả Flutter: 84 test liên quan đạt, gồm 13 test đối soát tiền làm tin,
7 test tích hợp form/provider/dialog và kiểm thử request PostgREST tải ledger
không giới hạn lịch sử ví. Analyze tập trung 24 mục đạt. Ba trạng thái tài xế
và form khách hàng đã render, kiểm tra ảnh; test render đạt.

Kết quả backend: [SQL regression](../supabase/tests/paid_goods_driver_deposit_regression.sql)
đạt trước triển khai và chạy lại trên các RPC đã triển khai. 11 tình huống:
nhận đơn, nhận đơn thiếu tiền, giao thành công, thiếu tiền khi nhận hàng,
chứng từ ngoài geofence, tài xế khác, hủy trước nhận hàng, hoàn hàng, bàn giao
CSKH, đơn trả trước cũ và COD có người gửi trả phí giao. Kiểm tra retry không
trùng giao dịch, số dư/tiền giữ, hoàn gốc tách cước, không chuyển nhầm tiền sang
khách hàng, quyền và chặn client bỏ qua RPC. Toàn bộ dữ liệu giả được rollback;
không ghi giao dịch kiểm thử vào ví thật. Advisor bảo mật không phát sinh cảnh
báo mới; RLS và quyền RPC công khai được giữ nguyên.

Chưa chạy hai request đồng thời từ các kết nối độc lập, VNPAY thực tế hoặc trên
thiết bị thật. Không chạy toàn bộ suite hay build phát hành. Analyze cả thư mục
navigation có hai cảnh báo có sẵn ở `driver_navigation_deadline_actions.dart`;
phạm vi file được sửa cho tính năng này không có lỗi analyze.
