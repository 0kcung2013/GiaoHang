# Bàn giao: phân loại khách hàng và phí sàn thực thu

Tài liệu này là hướng dẫn hiện hành, thay cho phạm vi chỉ hiển thị ở migration
`customer_classification_platform_fee_display`. Code mobile dùng chung tại
`packages/giaohang_mobile`; cấu hình Admin tại `apps/operations_web`.

## 1. Chính sách đã triển khai

| Đối tượng | Tỷ lệ khởi tạo | Cách thu |
| --- | ---: | --- |
| Khách cá nhân | 5% | Cộng vào cước người gửi/người nhận đã chọn trả |
| Khách doanh nghiệp/shop | 3% | Cộng vào cước người gửi/người nhận đã chọn trả |
| Tài xế | 10% | Khấu trừ khỏi thu nhập cước giao |

Admin chỉnh tại **Cấu hình nghiệp vụ → Phí sàn**. Hỗ trợ 0–100%, tối đa hai số
thập phân; 100 basis points = 1%. Lưu bắt buộc có lý do và kiểm tra revision,
có lịch sử trước/sau. CSKH, customer và driver không được sửa tỷ lệ.

Migration kích hoạt thay các số 0 của giai đoạn hiển thị bằng 5%/3%/10%; giữ tỷ
lệ khác 0 mà Admin đã đặt. Sau rollout, Admin có thể chủ động đặt 0% để miễn phí.

Phân loại là thông tin tự khai, không phải xác minh pháp nhân. Doanh nghiệp bao
gồm hộ kinh doanh/shop; tên và địa chỉ bắt buộc, mã số thuế tùy chọn. Customer
chưa phân loại phải hoàn thiện qua app; backend áp dụng mức cá nhân nếu một
client cũ vẫn gửi yêu cầu khi hồ sơ chưa phân loại.

### Công thức tiền

Gọi `D` là cước giao, `C` là tiền COD, `Rc/Rd` là tỷ lệ khách/tài xế theo basis
points. Phí được làm tròn đến đồng gần nhất, nửa đồng làm tròn lên:

```text
Fc = round(D × Rc / 10000)
Fd = round(D × Rd / 10000)
Thu nhập tài xế = D − Fd
Phí dịch vụ khách trả = D + Fc
Người nhận trả = C + (người nhận trả cước ? D + Fc : 0)
total_price = C + D + Fc
```

Không tính phí trên COD, giá trị hàng, tiền làm tin hoặc phí hoàn hàng.
Ví dụ D=18.000, C=20.000, cá nhân 5%, tài xế 10%: Fc=900, Fd=1.800,
khách trả dịch vụ 18.900; tài xế thực nhận 16.200. Trả tiền mặt: người nhận trả
38.900; ví tài xế nộp 2.700 phí khi hoàn tất, độc lập 20.000 COD đã ứng.

## 2. Thời điểm thu, hoàn và xử lý lặp

| Tình huống | Customer | Driver |
| --- | --- | --- |
| Người gửi trả bằng ví | Trừ D+Fc khi xác nhận, nguyên tử với tạo đơn | Cộng D−Fd khi giao thành công |
| Người gửi trả VNPAY | Phiên thanh toán ký đúng D+Fc từ server | Cộng D−Fd khi giao thành công |
| Người nhận trả tiền mặt | Thu C+D+Fc lúc giao | Giữ cước tiền mặt, ví nộp Fc+Fd |
| Hủy trước khi nhận hàng | Hoàn toàn bộ D+Fc đã trả vào ví customer; tiền mặt chưa thu nên không hoàn | Không thu phí sàn |
| Hết lượt tìm tài xế trước nhận hàng | Hoàn D+Fc nếu đã trả | Không thu phí sàn |
| Tìm lại tài xế | Trừ lại đúng D+Fc từ ví; VNPAY đã hoàn chuyển sang thanh toán ví | Giữ snapshot phí cũ |
| Tài xế được phân công lại khi chưa nhận hàng | Giữ khoản thanh toán, không thu/hoàn lần nữa | Không thu phí sàn ở tài xế bị thu hồi |
| Hoàn hàng vật lý thành công | Hoàn Fc đã trả vào ví; giữ cước D đã sử dụng. Tiền mặt chưa thu Fc thì miễn Fc | Cộng D−Fd và phí hoàn hiện có; không tính phí sàn trên phí hoàn |
| VNPAY thành công nhưng đến sau hết hạn/phiên đã expired hoặc failed | Hoàn toàn bộ số tiền nhận được vào ví, không kích hoạt đơn | Không phát sinh thu nhập |

Hoàn tiền vào **ví trong hệ thống**, không gọi API hoàn tiền về ngân hàng.
Giao dịch VNPAY đã thực thu từ ngân hàng vẫn tồn tại tại nhà cung cấp; ví ghi
nghĩa vụ phải trả của nền tảng cho khách. Không hoàn tay tại ngân hàng thêm lần
nữa sau khi ví đã được ghi có.

Đơn và phiên VNPAY chốt tỷ lệ, loại khách, số tiền khi tạo. Đổi hồ sơ hoặc tỷ lệ
sau đó không đổi đơn/phiên đang có. Snapshot không có `platform_fee_version=1`
giữ chính sách cũ, kể cả phiên VNPAY được thanh toán sau rollout.

Khóa theo đơn, khóa ví và idempotency key ngăn thu/hoàn hai lần. Lặp callback,
lặp xác nhận giao/hoàn và retry thanh toán ví không tạo thêm nghĩa vụ tiền.
Thanh toán VNPAY còn pending được dùng lại phiên cũ; phiên refunded có thể tạo
lại phiên mới. Không dùng thao tác chỉnh status trực tiếp từ client để giao/hoàn.

### Số dư tài xế âm

Giao tiền mặt đã thu cước nhưng ví có thể chưa đủ để nộp phí. Backend vẫn hoàn
tất giao hàng và ghi nợ phí vào ví. Không chặn bàn giao đang diễn ra. Tài xế
phải nạp bù để nhận đơn mới; `accept_order` kiểm tra cả đơn COD=0. Tiền làm tin
và COD tiếp tục theo luồng hiện có, không bị đổi thành phí nền tảng.

## 3. Dữ liệu và bút toán

Không tạo bảng mới hoặc dịch vụ tài chính thứ hai.

- `users`: `customer_type`, `business_name`, `business_address`,
  `business_tax_code`; RLS own-row và quyền cập nhật theo cột hiện có.
- `system_settings.business_settings`: ba key `customer_individual_fee_bps`,
  `customer_business_fee_bps`, `driver_platform_fee_bps`; top-level
  `platform_fee_version=1`; revision lịch sử trong cùng bảng.
- `orders.business_policy`: snapshot trên server, thêm `customer_type`.
- `orders.customer_platform_fee_rate_bps/amount`: snapshot phí khách mới.
- `orders.platform_fee_rate_bps/amount`: phí tài xế; `driver_net_earning` đã trừ
  phí, có thể bằng 0 tại tỷ lệ 100%. Không fallback về cước gốc khi thực nhận 0.
- `driver_wallet_transactions`: `platform_fee_capture` nộp phí tài xế tiền mặt;
  `customer_platform_fee_capture` nộp lại khoản phí khách đã thu hộ. Hai khoản
  này không cộng vào thu nhập. `prepaid_earning`, `cod_settlement`,
  `return_delivery_earning` lưu thu nhập **net**. Trả trước/hoàn hàng đã cộng net
  nên không ghi thêm một lần trừ phí vào ví.
- `customer_wallet_transactions`: tái sử dụng `delivery_fee_payment/refund`.
  Với thanh toán muộn chưa có đơn, `order_id` được phép NULL và bắt buộc có
  `payment_session_id` tham chiếu phiên thanh toán. Các dòng còn lại giữ order_id.
  Tổng COD nhận được không cộng các khoản hoàn phí.

Các snapshot tiền bị chặn sửa, kể cả client có quyền đọc/cập nhật đơn. Các helper
settlement ở schema `private`, đã thu hồi quyền gọi trực tiếp. RPC thanh toán
provider chỉ dành cho service role; client không quyết định phí hay trạng thái paid.

## 4. Setup và thứ tự triển khai

### Điều kiện có sẵn

- Flutter/Dart phù hợp workspace (`^3.9.0`; baseline dự án Flutter 3.35.1), Node
  hỗ trợ `--experimental-strip-types` để chạy kiểm tra callback, Supabase CLI.
- Một Supabase backend GiaoHang tương thích với các migration trước thay đổi
  này: Auth, users/orders/drivers, hai sổ ví, payment sessions, nghiệp vụ giao/
  hoàn, cấu hình có revision và mã bàn giao lấy hàng.
- Tài khoản Admin đúng role trong `public.users`; đăng ký qua app tạo customer/
  driver, không nâng quyền Admin bằng user metadata.

Chạy `supabase/operations/platform_fee_setup_check.sql` bằng SQL Editor để kiểm
tra baseline và trạng thái feature. Script chỉ đọc.

Nếu tiếp quản và dùng chung backend DATN đã triển khai, chỉ cần clone repo,
`flutter pub get`, chạy app và dùng tài khoản đúng role. Không chạy lại migration
hoặc ghi đè secrets của backend đang dùng. Các bước deploy dưới đây dành cho
môi trường chưa được cập nhật hoặc cần triển khai source mới.

**Môi trường database trắng:** lịch sử repo hiện không có migration khởi tạo
`users`/`orders`, nên không được coi `supabase db reset` là bootstrap đầy đủ.
Người bàn giao backend phải cung cấp baseline/backup tương thích, bao gồm Auth
triggers, extension, quyền và dữ liệu cấu hình hệ thống; không cần dữ liệu khách
thật. Có thể xuất schema để rà soát bằng `supabase db dump --linked --file
<duong-dan-backup.sql>` (cần Docker theo CLI). Schema dump không chứa dữ liệu
cấu hình, Auth settings, secrets, R2 hay cron bên ngoài: những phần này phải được
thiết lập theo tài liệu tương ứng. Không chạy tất cả migration lịch sử lên một
baseline đã chứa chúng; phải đối chiếu lịch sử migration của môi trường đích.

### Cập nhật backend đang có

1. Sao lưu, kiểm tra đúng project đích và lịch sử migration. Ba migration liên
   quan theo thứ tự: `customer_classification_platform_fee_display`,
   `collect_customer_driver_platform_fees`, `require_order_command_for_fee_snapshots`.
2. Deploy source mobile/Admin có payload `quoted_customer_fee` và hiển thị tổng
   tiền gồm phí. Khi cần triển khai đồng thời, tạm dừng tạo đơn; backend sẽ từ
   chối quote cũ thiếu/sai phí thay vì âm thầm thu thêm.
3. Tại root, `supabase db push --linked --dry-run`, xem chính xác migration dự
   kiến. Chỉ khi danh sách đúng mới `supabase db push --linked`. Không dùng
   `--include-all` để ép chạy các migration lịch sử không khớp.
4. Deploy các function thay đổi: `supabase functions deploy vnpay-order-return
   vnpay-create-order-payment vnpay-create-wallet-topup --project-ref <PROJECT_REF>
   --use-api`. `config.toml` đã tắt gateway JWT cho
   callback; callback tự kiểm chữ ký HMAC và terminal/số tiền.
5. Xác nhận `vnpay-wallet-ipn` đang chạy phiên bản trong repo. Trên môi trường mới,
   deploy function này cùng các function Return/nạp ví hiện có; không cần
   sửa logic IPN để tính phí vì nó lấy số tiền từ phiên trên server.
6. Chạy lại setup check, regression SQL và đối soát ở mục 6; Admin kiểm tra ba
   tỷ lệ. Khởi động lại/release các client tương ứng.

Migration không đổi runtime config. Ba app đang đọc URL/anon key tại
`packages/giaohang_config/lib/src/supabase_constants.dart`; khi setup project mới,
đặt đúng giá trị môi trường đích tại cơ chế hiện có. Không đưa service role hoặc
VNPAY hash secret vào Flutter. Chuyển sang `.env` là công việc riêng.

### VNPAY và secrets

Template tên biến: `docs/handoff/platform_fee_secrets.example`. Điền thông tin
merchant vào file riêng ngoài Git rồi nạp bằng cơ chế Supabase Secrets. Các biến
`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` được runtime
Supabase cung cấp; không sao chép giá trị vào tài liệu/source.

```powershell
supabase secrets set --project-ref <PROJECT_REF> --env-file <file-secret-da-dien-ngoai-git>
```

| Biến | Thiết lập |
| --- | --- |
| `VNPAY_TMN_CODE` | Terminal merchant tương ứng môi trường |
| `VNPAY_HASH_SECRET` | Secret ký/kiểm chữ ký; chỉ server |
| `VNPAY_ENVIRONMENT` | `sandbox` khi thử; `production` khi dùng merchant thật |
| `VNPAY_PAYMENT_URL` | Sandbox có mặc định; production bắt buộc nhập URL thanh toán HTTPS do merchant cung cấp |
| `VNPAY_ORDER_RETURN_URL` | `https://<PROJECT_REF>.supabase.co/functions/v1/vnpay-order-return` |
| `VNPAY_ORDER_APP_RETURN_URL` | Tùy chọn deep link app; bỏ biến để dùng trang kết quả mặc định |

Merchant đăng ký IPN đến `https://<PROJECT_REF>.supabase.co/functions/v1/vnpay-wallet-ipn`.
IPN này xử lý cả giao dịch đơn có tiền tố `O` và nạp ví tài xế. Production dùng
IPN đã ký để đối soát; chế độ sandbox cho phép Return đã ký hoàn tất giao dịch.
Client/server không được đánh dấu paid từ thao tác mở URL hay bấm nút.

Gateway được đọc từ cấu hình server cho cả tạo đơn và nạp ví; không phải sửa
source khi chuyển môi trường. Production thiếu URL hoặc cấu hình nhầm sandbox
sẽ bị từ chối. Chỉ chấp nhận HTTPS thuộc miền VNPAY, không có query/credentials.
Vận hành tiền thật cần merchant thật và thử IPN thực tế; các test tự động không
thực hiện giao dịch ngân hàng và không thay thế bước nghiệm thu này.
Pipeline R2, ảnh bằng chứng và GPS giữ nguyên cấu hình hiện hành; phí sàn không
thêm bucket, Worker, cron hoặc secret mới cho các pipeline đó.

### Chạy client

```powershell
# Tại repository root
flutter pub get
# Chọn một app; chạy từng lệnh tại thư mục tương ứng
cd apps/customer_app
flutter run
# Từ root, apps/driver_app: flutter run
# Từ root, apps/operations_web: flutter run -d chrome
```

Không cần package Flutter mới. Tài khoản cũ chưa phân loại vẫn xem được đơn/
tracking/hỗ trợ; tạo đơn mới đi qua hoàn thiện loại khách hàng.

## 5. Kiểm tra trước bàn giao

Các điểm tích hợp chính:

| Đường gọi | Hợp đồng |
| --- | --- |
| `create_customer_order_v2(p_order_payload)` | Đơn người nhận trả cước; payload có `delivery_fee`, `quoted_distance_m`, `settings_revision`, `quoted_customer_fee` |
| `create_customer_order_with_wallet(p_order_payload,p_request_id)` | Cùng UUID request khi retry, không đổi payload khi chưa rõ kết quả |
| Edge `vnpay-create-order-payment` | Trả URL/amount từ phiên trên server; không tự cộng phí lần nữa ở client |
| `complete_customer_order_payment` | Chỉ server gọi sau kiểm chữ ký, terminal và số tiền |
| `confirm_driver_pickup_code`, `advance_driver_order_status`, `confirm_order_return` | Luồng bàn giao hiện có; settlement phí nằm trong cùng transaction |

`quoted_customer_fee` là số tiền khách đã thấy ở xác nhận, không phải quyền quyết
định phí. Backend tự tính lại và từ chối nếu khác; không nhận tỷ lệ từ payload.

Từ `packages/giaohang_mobile`:

```powershell
flutter test --no-pub test/platform_fee_collection_test.dart test/order_finance_test.dart test/customer_order_command_service_test.dart test/customer_order_payment_service_test.dart test/order_confirmation_payment_controller_test.dart test/order_confirmation_wallet_controller_test.dart test/order_confirmation_collection_test.dart test/create_order_payment_step_test.dart test/driver_order_finance_panel_test.dart test/customer_classification_test.dart
```

Từ root: `node --experimental-strip-types --test supabase/functions/tests/vnpay_test.mjs`.
Chạy bằng SQL Editor từng file dưới đây; tất cả fixture/money/config đều rollback:

- `supabase/tests/platform_fee_collection_regression.sql`: thu dương, làm lại,
  đổi hồ sơ/config giữa phiên, hoàn tiền, COD, hoàn hàng, phí 100%, ví âm và chặn
  nhận đơn COD=0 khi nợ, idempotency và quyền gọi helper.
- `supabase/tests/customer_wallet_prepaid_delivery_regression.sql`: vòng đời ví/
  deposit cũ; cô lập tỷ lệ 0 trong transaction để không phụ thuộc cấu hình Admin.
- `supabase/tests/business_system_configuration_regression.sql` và
  `supabase/tests/single_rate_pricing_regression.sql`: giữ công thức cước/snapshot.
- `supabase/tests/customer_classification_platform_fee_regression.sql`: phân loại,
  quyền và validation cấu hình phần trăm.

Kiểm thử thủ công trên sandbox: tạo hai loại khách; đặt đơn trả ví/VNPAY/tiền
mặt; nhìn tổng trước xác nhận; tài xế nhìn phí/thực nhận trước nhận đơn; giao/
hủy/hoàn; đổi tỷ lệ trong Admin; kiểm tra số tiền đơn cũ không đổi. VNPAY cần
merchant sandbox và mạng hoạt động; regression SQL không thay thế thử gateway.

## 6. Đối soát và xử lý sự cố

Chạy `supabase/operations/platform_fee_reconciliation.sql` với quyền vận hành.
Các truy vấn sai lệch phải trả 0 dòng; báo cáo cuối trả tổng phí theo trạng thái.
Giữ báo cáo cùng chứng từ provider, không gửi bảng chứa dữ liệu cá nhân ra ngoài.

| Triệu chứng | Kiểm tra / xử lý |
| --- | --- |
| `SETTINGS_QUOTE_FEE_MISMATCH` | Dùng client mới, quay lại báo giá; kiểm tra loại khách/tỷ lệ server. Không sửa payload thành 0 để vượt kiểm tra |
| `CUSTOMER_WALLET_INSUFFICIENT_BALANCE` | Tổng cần trả là D+Fc; chọn VNPAY hoặc có đủ số dư ví. Retry sau timeout cũng phải đủ tổng này |
| `INSUFFICIENT_WALLET_BALANCE` khi nhận đơn | Kiểm tra nợ phí và khoản ứng COD/làm tin; nạp ví. Không xóa bút toán nợ |
| Callback paid nhưng không có đơn | Xem session.status và bút toán `payment_session_id`; nếu refunded thì số tiền đã vào ví, không tạo đơn bằng tay |
| VNPAY phiên cũ `refund_required` | Giữ quy trình đối soát cũ; không chạy script hoàn thêm. Rollout không hồi tố |
| Thu nhập 0 ở mức phí 100% | Hành vi hợp lệ; không fallback về D |
| Số tiền nhận hàng khác dự kiến | So `receiver_collection_amount`, không lấy `total_price` cho đơn người gửi đã trả cước |

Tạm dừng phí: Admin đặt ba tỷ lệ 0% với lý do. Chỉ ảnh hưởng đơn mới. Không rollback
schema hoặc phục hồi bản database cũ sau khi đã phát sinh tiền; các snapshot và
bút toán cần được giữ để quyết toán. Điều chỉnh sai lệch thực tế phải qua vận
hành có audit/idempotency, không UPDATE/DELETE số tiền ledger tùy ý.

## 7. Mốc xác minh ngày 2026-10-29

- Backend DATN: migration `20261028180659_collect_customer_driver_platform_fees.sql`
  đã áp dụng; cấu hình revision 6, version thu phí 1, tỷ lệ 500/300/1000 bps.
  Migration `require_order_command_for_fee_snapshots` cũng đã áp dụng để chặn
  direct INSERT giả snapshot legacy từ client.
- Đã deploy `vnpay-order-return` v7, `vnpay-create-order-payment` v6 và
  `vnpay-create-wallet-topup` v6. Không thay merchant/secrets hiện có.
- Kiểm tra SQL thu phí dương, regression ví/cấu hình/cước cũ và phân loại đạt;
  fixture đã rollback. Setup check đạt, năm truy vấn đối soát trả 0 sai lệch.
  Chưa có đơn version 1 hoàn tất thực tế tại mốc xác minh; đối soát 0 không phải
  bằng chứng đã giao dịch ngân hàng thật.
- Test Flutter tập trung về model, xác nhận/thu tiền, retry/refund, ví, phân loại
  và layout đạt sau cập nhật assertion hạn mức theo formatter hiện hành.
- 10 kiểm tra Node về HMAC, callback và gateway đạt. Callback deployed từ chối
  chữ ký giả. Đã xem render component phí/tổng và thực nhận ở viewport 375×667;
  kiểm tra thêm text scale 1.6.
- Chưa build phát hành toàn app, chưa giao dịch ngân hàng thật hay nghiệm thu
  thiết bị thật. Người vận hành tiếp tục checklist sandbox/production ở mục 5.
