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

### Minimal-table decision

Supabase hiện có 24 bảng trong `public`, trong đó `spatial_ref_sys` là bảng hệ thống của PostGIS và 23 bảng còn lại là bảng nghiệp vụ. Không có bảng ví hoặc thanh toán cũ phù hợp để tái sử dụng. Phase A chỉ tạo **hai bảng mới**:

- `driver_wallet_transactions`: dùng chung cho yêu cầu nạp VNPAY, top-up hoàn tất/thất bại, giữ tiền COD, giải phóng tiền giữ, capture tiền ứng, capture phí nền tảng và credit thu nhập prepaid. Bảng có `idempotency_key`, `provider_txn_ref`, `available_delta`, `held_delta`, liên kết order và metadata đối soát. Chỉ trạng thái của dòng yêu cầu top-up được chuyển từ `pending`; các hiệu ứng tiền đã hoàn tất không được sửa/xóa.
- `system_settings`: cấu hình key/value tối giản, khởi tạo `platform_fee_rate_bps = 1500`, có `updated_by` và `updated_at`. Chỉ Admin cập nhật qua RPC có kiểm tra vai trò.

Tái sử dụng bảng hiện có:

- `orders` là nguồn snapshot tài chính của đơn, bổ sung `payment_mode`, `goods_value`, `platform_fee_rate_bps`, `platform_fee_amount`, `driver_net_earning`, `driver_advance_amount` và `receiver_collection_amount`.
- `order_items.price` trở lại đúng nghĩa đơn giá hàng hóa. Dữ liệu lịch sử đang bị ghi bằng phí giao được chuẩn hóa về `0` vì không thể suy ra giá hàng thật.
- `orders.delivery_fee` tiếp tục là toàn bộ phí giao; `orders.total_price` bằng `goods_value + delivery_fee`.
- `orders.payment_method` tiếp tục mô tả kênh `cash/card/wallet`; `payment_mode` mới mô tả thời điểm `prepaid/cod`, tránh đổi nghĩa dữ liệu cũ.
- `order_status_logs` chỉ lưu trạng thái vận chuyển, không dùng làm sổ tiền.

Số dư khả dụng và số tiền đang giữ được tính từ tổng `available_delta`/`held_delta` của transaction `completed` qua RPC. Với quy mô hiện tại, cách này tránh bảng `driver_wallets` và vẫn bảo đảm tính đúng bằng khóa giao dịch theo tài xế. Thu nhập hôm nay tính từ snapshot các đơn đã giao, không trộn tiền mặt COD vào số dư ví.

### Atomic commands

Mọi thay đổi số dư chạy qua PostgreSQL RPC trong một transaction và khóa hàng ví. Flutter không được insert/update trực tiếp ledger hay số dư.

Các command chính:

- tạo top-up pending trong ledger;
- xác nhận top-up idempotent từ VNPAY IPN;
- nhận đơn và giữ tiền COD;
- release khoản giữ khi hủy trước pickup;
- capture tiền ứng khi pickup;
- settle đơn prepaid/COD khi delivered;
- Admin cập nhật `platform_fee_rate_bps`; mỗi đơn luôn snapshot mức phí tại lúc tạo.

RLS cho phép tài xế chỉ đọc transaction của chính mình. Customer đọc tài chính qua đơn do họ tạo. Support/Admin đọc theo vai trò; chỉ Admin được gọi command đổi phí. Không role client nào được insert/update/delete ledger hay sửa cấu hình trực tiếp.

## VNPAY Sandbox integration

Ba Supabase Edge Functions được dùng:

- `vnpay-create-wallet-topup`: xác thực tài xế, validate số tiền từ 5.000đ đến 10.000.000đ, tạo pending top-up và trả payment URL đã ký HMAC-SHA512.
- `vnpay-wallet-ipn`: endpoint server-to-server, kiểm tra TmnCode, checksum, amount, txn ref và trạng thái hiện tại; credit ví đúng một lần rồi trả `RspCode`/`Message` theo VNPAY.
- `vnpay-wallet-return`: kiểm tra response để hiển thị trạng thái cho người dùng rồi deep-link về app; UI vẫn chờ trạng thái do IPN xác nhận, không tin Return URL để cộng tiền.

`VNPAY_TMN_CODE` và `VNPAY_HASH_SECRET` chỉ lưu bằng Supabase secrets. Giá trị secret người dùng đã gửi không được ghi vào source, migration, log, test fixture hoặc tài liệu. Secret sandbox cần được rotate trước khi cấu hình.

### Sandbox Return settlement fallback

Môi trường Sandbox hiện không gọi IPN URL đã deploy, trong khi Return URL nhận
được phản hồi thanh toán thành công. Để luồng demo không bị treo ở `pending`,
Return Function được phép hoàn tất top-up với các điều kiện bắt buộc sau:

- checksum HMAC-SHA512 hợp lệ;
- `vnp_TmnCode` khớp cấu hình server;
- transaction reference tồn tại và đang thuộc top-up VNPAY;
- `vnp_Amount` khớp tuyệt đối với số tiền pending;
- `vnp_ResponseCode` và `vnp_TransactionStatus` đều bằng `00`.

Return và IPN gọi cùng RPC hoàn tất top-up nên unique/idempotency guard bảo đảm
chỉ cộng tiền một lần dù hai callback đến đồng thời hoặc bị replay. IPN vẫn là
luồng chuẩn cho production; fallback Return chỉ phục vụ Sandbox/demo và phải
được tắt khi terminal VNPAY production đã đăng ký IPN URL.

UI không hiển thị top-up `pending` như tiền đã nhận: giao dịch pending dùng màu
trung tính, nhãn `Đang xử lý` và không có dấu cộng. Chỉ transaction `completed`
mới hiển thị xanh và được cộng vào số dư khả dụng; `failed` hiển thị trạng thái
thất bại màu đỏ.

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
- Một order giữ đúng một snapshot tài chính trực tiếp trên `orders`; unique idempotency key ngăn settlement hoặc top-up trùng.
- Platform fee rate được snapshot khi tạo đơn; thay đổi cấu hình không làm đổi đơn cũ.
- Nếu deep link/Return URL mất kết nối, app refresh top-up từ server; IPN vẫn là nguồn sự thật.

## Focused verification

- Migration contract tests cho tables, RLS và atomic RPC.
- Unit tests cho công thức phí, snapshot và wallet state transitions.
- Edge Function tests cho signing, checksum, amount mismatch và IPN idempotency bằng fixture giả; không gọi VNPAY thật trong test tự động.
- Widget tests tập trung cho payment selector, COD/prepaid driver card, insufficient-wallet CTA và wallet balance/transaction rows.
- Chỉ analyze các package/feature/file bị sửa. Không chạy full test suite hoặc full build trừ khi người dùng yêu cầu.
