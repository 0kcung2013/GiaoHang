# Driver Wallet, COD, and VNPAY Sandbox Finance Design

## Goal

Xây dựng hệ thống tài chính demo đầy đủ cho Delivery App: khách hàng khai báo giá trị hàng và chọn trả trước/COD; tài xế có ví ứng tiền nạp qua VNPAY Sandbox; hệ thống tính phí nền tảng 15%, kết toán thu nhập ròng và lưu ledger bất biến.

## Scope and sequencing

Phase A của đặc tả này gồm ví tài xế, nạp VNPAY Sandbox, tài chính đơn hàng, COD, phí nền tảng, thu nhập tài xế và cấu hình phí trên Operations Web.

Phase B **không nằm trong lần triển khai này**. Sau khi Phase A hoàn thành và được kiểm chứng, Phase B sẽ có đặc tả riêng cho giao thất bại, hoàn hàng, hoàn/cấn trừ khoản ứng và điều hướng tài xế về điểm lấy hàng.

## Confirmed business rules

- VNPAY chỉ dùng để tài xế nạp ví ứng; khách hàng không thanh toán đơn qua VNPAY trong Phase A.
- Khách hàng chọn một trong hai chế độ: `prepaid` hoặc `cod`.
- `prepaid` nghĩa là tiền hàng và phí giao đều đã được thanh toán; tài xế không ứng và không thu tiền.
- `cod` nghĩa là tài xế ứng giá trị hàng cho người gửi và thu `giá trị hàng + phí giao` từ người nhận.
- Phí nền tảng mặc định bằng 15% tổng phí giao hàng, không tính trên giá trị hàng/COD.
- Tổng phí giao gồm mọi thành phần của chính sách giá, bao gồm phí mở đơn và phí quãng đường. Mức phí mở đơn có thể thay đổi độc lập mà không đổi công thức ví.
- Thu nhập ròng tài xế bằng `phí giao − phí nền tảng`.
- Tất cả số tiền mới dùng số nguyên VND; không dùng số thực cho ledger.

## Financial flows

### Prepaid

1. Tài xế nhận đơn mà không cần giữ tiền trong ví.
2. Khi giao thành công, hệ thống tạo settlement và cộng thu nhập ròng vào ví.
3. Tài xế không thu bất kỳ khoản nào từ người nhận.

### COD

1. Khi tài xế nhận đơn, hệ thống yêu cầu số dư khả dụng tối thiểu bằng `giá trị hàng + phí nền tảng`, rồi giữ cả hai khoản.
2. Khi xác nhận lấy hàng, phần giữ của giá trị hàng được capture thành khoản trừ ví; phần phí nền tảng tiếp tục được giữ.
3. Khi giao thành công, tài xế thu tiền mặt bằng `giá trị hàng + phí giao` từ người nhận; hệ thống capture phí nền tảng và tạo settlement thu nhập ròng.
4. Tiền COD và tiền mặt đã thu được ghi nhận trong settlement nhưng không được cộng nhầm vào số dư ví hoặc thu nhập.
5. Hủy trước khi lấy hàng giải phóng toàn bộ khoản giữ. Xử lý sau khi đã lấy hàng thuộc Phase B.

## Data architecture

### Tables

- `driver_wallets`: một ví cho mỗi hồ sơ tài xế; `available_balance`, `held_balance`, `currency`, version và timestamps.
- `wallet_transactions`: ledger append-only gồm top-up, hold, release, COD capture, platform-fee capture và prepaid earning credit; có `idempotency_key`, số dư sau giao dịch và liên kết order/top-up.
- `wallet_topups`: yêu cầu nạp tiền VNPAY với `txn_ref` duy nhất, amount, trạng thái pending/succeeded/failed/expired, mã giao dịch VNPAY và timestamps.
- `order_financials`: snapshot một-một theo order gồm payment mode, goods value, delivery fee, platform fee rate/amount, driver net earning, driver advance và receiver collection.
- `order_settlements`: kết quả tài chính bất biến của cuốc, gồm kênh nhận tiền `wallet` hoặc `cash`, các thành phần tiền và thời điểm settlement.
- `platform_fee_policies`: lịch sử policy append-only gồm rate, `effective_from`, người tạo và timestamps; policy hiệu lực mặc định là 15%.

Các trường tài chính hiện có trên `orders` tiếp tục được đọc để tương thích, nhưng `order_financials` là nguồn sự thật mới. `order_items.price` phải là giá trị hàng, không còn được gán bằng phí giao.

### Atomic commands

Mọi thay đổi số dư chạy qua PostgreSQL RPC trong một transaction và khóa hàng ví. Flutter không được insert/update trực tiếp ledger hay số dư.

Các command chính:

- tạo top-up pending;
- xác nhận top-up idempotent từ VNPAY IPN;
- nhận đơn và giữ tiền COD;
- release khoản giữ khi hủy trước pickup;
- capture tiền ứng khi pickup;
- settle đơn prepaid/COD khi delivered;
- Admin tạo policy phí mới có thời điểm hiệu lực; không sửa/xóa policy cũ.

RLS cho phép tài xế chỉ đọc ví, top-up, transaction và settlement của chính mình. Customer chỉ đọc tài chính đơn do họ tạo. Support/Admin đọc theo vai trò; chỉ Admin được gọi command đổi phí. Không role client nào được sửa số dư trực tiếp.

## VNPAY Sandbox integration

Ba Supabase Edge Functions được dùng:

- `vnpay-create-wallet-topup`: xác thực tài xế, validate số tiền từ 5.000đ đến 10.000.000đ, tạo pending top-up và trả payment URL đã ký HMAC-SHA512.
- `vnpay-wallet-ipn`: endpoint server-to-server, kiểm tra TmnCode, checksum, amount, txn ref và trạng thái hiện tại; credit ví đúng một lần rồi trả `RspCode`/`Message` theo VNPAY.
- `vnpay-wallet-return`: kiểm tra response để hiển thị trạng thái cho người dùng rồi deep-link về app; UI vẫn chờ trạng thái do IPN xác nhận, không tin Return URL để cộng tiền.

`VNPAY_TMN_CODE` và `VNPAY_HASH_SECRET` chỉ lưu bằng Supabase secrets. Giá trị secret người dùng đã gửi không được ghi vào source, migration, log, test fixture hoặc tài liệu. Secret sandbox cần được rotate trước khi cấu hình.

## UI design

Thiết kế dùng phương án A đã duyệt: **ưu tiên con số** và hạn chế chữ.

### Customer

- Trong phần kiện hàng: input tiền `Giá trị hàng` và hai payment cards `Đã thanh toán` / `COD`.
- Confirmation chỉ hiển thị ba dòng tiền: `Tiền hàng`, `Phí giao`, `Đã thanh toán` hoặc `Người nhận trả`.
- Badge xanh cho prepaid; badge cam cho COD.

### Driver order cards and detail

- COD: chip cam `COD · CẦN ỨNG`; số tiền cần ứng là typography lớn nhất; bên dưới là hai ô `Thu người nhận` và `Thực nhận`.
- Nếu ví thiếu: thay CTA nhận đơn bằng `Nạp thêm <số tiền>`; không cho nhận đơn.
- Prepaid: chip xanh `ĐÃ THANH TOÁN`; thông điệp chính `0đ cần thu`; thu nhập ròng là con số phụ nổi bật màu success.
- Breakdown phí nền tảng nằm trong bottom sheet/expandable detail, không chiếm card chính.

### Driver wallet and earnings

- Hero nền navy hiển thị `Số dư khả dụng`; `Đang giữ` là chỉ số nhỏ; CTA cam `Nạp qua VNPAY`.
- Các mức nạp nhanh 100.000đ, 200.000đ, 500.000đ và số tiền tùy chọn.
- `Thu nhập hôm nay` tách khỏi số dư ví để COD tiền mặt không bị hiểu nhầm là tiền trong ví.
- Transaction list dùng icon, dấu `+`/`−`, số tiền và thời gian; chi tiết chỉ mở khi chạm.

### Operations Web

- Finance settings card cho Admin hiển thị tỷ lệ 15% và một control cập nhật có xác nhận.
- Bảng audit/ledger chỉ hiển thị dữ liệu cần đối soát; không cho sửa transaction.

UI dùng `AppColors`, `AppTextStyles`, `AppSpacing`, `AppRadius`, semantic label và target chạm tối thiểu 48dp.

## File-size plan

`create_order_screen.dart` hiện 436 dòng. Không thêm trực tiếp logic tài chính vào file này. Trước khi wiring, tách trạng thái/công thức tài chính sang controller/model riêng và tạo widget payment riêng; screen chỉ giữ provider/navigation. Các màn ví, earnings và Admin finance được chia thành screen, controller/repository, widgets và utils; không tạo file mới quá 400 dòng.

## Error handling and invariants

- Top-up pending hết hạn không được credit.
- IPN lặp lại trả thành công nhưng không tạo transaction thứ hai.
- Amount/TmnCode/checksum không khớp không thay đổi dữ liệu.
- Số dư không được âm và `held_balance` không vượt tổng nguồn tiền hợp lệ.
- Một order chỉ có một financial snapshot và một settlement thành công.
- Platform fee rate được snapshot khi tạo đơn; thay đổi cấu hình không làm đổi đơn cũ.
- Nếu deep link/Return URL mất kết nối, app refresh top-up từ server; IPN vẫn là nguồn sự thật.

## Focused verification

- Migration contract tests cho tables, RLS và atomic RPC.
- Unit tests cho công thức phí, snapshot và wallet state transitions.
- Edge Function tests cho signing, checksum, amount mismatch và IPN idempotency bằng fixture giả; không gọi VNPAY thật trong test tự động.
- Widget tests tập trung cho payment selector, COD/prepaid driver card, insufficient-wallet CTA và wallet balance/transaction rows.
- Chỉ analyze các package/feature/file bị sửa. Không chạy full test suite hoặc full build trừ khi người dùng yêu cầu.
