# PIN thanh toán Ví khách hàng

Triển khai ngày 2026-11-02 theo phương án được người dùng duyệt. PIN cố định gồm
6 chữ số, giữ được số 0 đầu; khách tự đặt, nhập lại khi thiết lập và nhập cho mỗi
giao dịch trả phí bằng Ví. Tổng tiền xác nhận gồm phí giao và phí sàn của khách.

## Nghiệp vụ và giao diện

- Tài khoản → Cài đặt → Đăng nhập và bảo mật → Mã PIN thanh toán: tạo/đổi PIN.
- Chưa có PIN: từ xác nhận đơn mở màn tạo mã rồi quay lại xác nhận thanh toán;
  không tự thanh toán sau khi tạo mã. Hủy nhập PIN giữ đơn nháp, không trừ tiền.
- Chỉ thanh toán khi bấm nút xác nhận. Sai mã thông báo số lần còn lại.
- 5 lần sai liên tiếp khóa xác nhận PIN 15 phút theo giờ server, dùng chung giữa
  thanh toán và đổi PIN trên mọi thiết bị. Đổi PIN cần mã hiện tại; không dùng
  thao tác đổi mã để vượt khóa. PIN đúng sau hết khóa xóa số lần sai.
- Đây là khóa xác nhận PIN cho Ví; không ghi khóa đăng nhập, khóa nhận đơn hoặc
  điểm vi phạm. VNPAY và các luồng thu tiền hiện có giữ nguyên phạm vi.
- PIN chỉ được giữ trong input và tham số yêu cầu đang chạy; không ghi vào
  shared_preferences, hồ sơ, payload đơn hàng, metadata giao dịch hoặc log.

## Lưu trữ và quyền

`private.customer_wallet_security` giữ `customer_id`, bản băm bcrypt cost 10,
số lần sai, hạn khóa, thời điểm đổi mã và bằng chứng khôi phục đã tiêu thụ.
Bảng có RLS và policy restrictive deny-all; không có quyền SELECT/INSERT/UPDATE
cho anon/authenticated/service_role. Hàm private do owner chạy mới truy cập được.

Không dùng `public.users` vì hồ sơ được đọc trực tiếp ở nhiều màn hình; không
dùng `customer_wallet_transactions` để giữ bí mật đăng nhập hoặc sửa số lần sai.
Đây là dữ liệu credential có quyền/vòng đời riêng, không phải bảng cho trạng thái UI.
Không thêm database, bucket, Edge Function hoặc dịch vụ gửi mail riêng.

RPC public dùng SECURITY INVOKER và ủy quyền sang private helper có kiểm tra
`auth.uid()`, role customer và `private.account_enabled`:

| RPC | Mục đích |
| --- | --- |
| `get_customer_wallet_pin_status()` | Chỉ trả trạng thái, giờ server, số lần còn lại và email đã xác thực của chính khách |
| `set_customer_wallet_pin(p_new_pin,p_current_pin)` | Thiết lập hoặc đổi PIN |
| `create_customer_order_with_wallet(p_order_payload,p_request_id,p_pin)` | Kiểm tra PIN và trả `{ok, order}` hoặc lỗi nghiệp vụ `{ok:false, code,...}` |
| `reset_customer_wallet_pin(p_new_pin,p_request_id)` | Khôi phục bằng phiên Auth recovery mới được xác minh |

Lỗi PIN trả JSON, không RAISE sau khi tăng bộ đếm, vì exception sẽ rollback số lần sai.
Kiểm tra PIN và trừ tiền giữ chung advisory lock `customer-wallet:{customer_id}`.
PIN đúng xóa chuỗi sai kể cả khi thiếu số dư hoặc báo giá bị từ chối; phần tài
chính chạy trong subtransaction để rollback toàn bộ thay đổi tiền/đơn khi lỗi.
Lỗi nghiệp vụ này trả `{ok:false,error_kind:'payment',code,sqlstate}` và client
chuyển về exception nghiệp vụ hiện có, giữ hành vi đổi sang VNPAY/xem lại báo giá.
Giữ nguyên helper nghiệp vụ tạo đơn/bút toán/kiểm tra báo giá, đổi tên thành
`private.create_customer_order_with_wallet_unchecked` và thu hồi mọi quyền client.
RPC 2 tham số cũ trả `CUSTOMER_WALLET_PIN_REQUIRED`, không còn đường trừ tiền thiếu PIN.

Sau mất phản hồi, gửi lại cùng request_id/payload để đọc biên nhận trước khi hỏi
PIN lại. Biên nhận đã có trả lại cùng đơn, kể cả khách vừa bị khóa PIN. Payload
khác vẫn bị từ chối. Không lưu PIN để phục vụ retry. Hoàn tất điều hướng/lưu địa
chỉ sau tạo đơn lỗi chỉ thực hiện lại bước hoàn tất, không thanh toán lần nữa.

## Khôi phục bằng email: phần cần vận hành thiết lập

Client recovery riêng, chỉ trong bộ nhớ, gọi `resetPasswordForEmail(email)` và
`verifyOTP(type: OtpType.recovery, ...)`. Luồng này chỉ dùng để xác minh quyền
truy cập hộp thư; không gọi thay đổi mật khẩu đăng nhập. Không thay thế session
chính, không gọi `claim_active_session`, không thu hồi phiên khác. Khi đóng màn,
đăng xuất riêng phiên recovery với scope local rồi dispose client.

Backend đọc phiên đang tồn tại trong `auth.sessions` và AMR `recovery` trong
`auth.mfa_amr_claims`, yêu cầu email đã xác thực khớp token. Bằng chứng xác minh
có hiệu lực 5 phút và dùng một lần; cùng request_id/PIN cho phép đọc lại kết quả
khi mất mạng. Refresh token/iat/user_metadata không phải bằng chứng khôi phục.
Google login và phiên password thường không đủ để đặt lại PIN.

**Cần kiểm tra trong Supabase Dashboard trước khi mở luồng Quên mã cho người dùng:**

1. Authentication → Email Templates → Reset Password/Recovery: dùng nội dung
   `supabase/templates/wallet_pin_recovery.html`, có biến `{{ .Token }}` để email
   hiển thị mã. Mẫu chỉ có liên kết không đáp ứng màn nhập mã trong app.
2. Cấu hình Email OTP dài 6 chữ số. Khuyến nghị hạn mã email 10 phút; đây là cài
   đặt Auth dùng chung, cần đối chiếu các luồng email khác trước khi chỉnh.
   Hạn bằng chứng 5 phút phía RPC tính sau khi xác minh mã email, là hạn riêng.
3. Kiểm tra SMTP của dự án gửi được tới email khách hàng thực tế; dùng SMTP đã
   được vận hành cấu hình. Không đặt SMTP password/service_role xuống Flutter.
4. Gửi thử tới hộp thư kiểm thử do vận hành quản lý, kiểm tra inbox/spam, mã sai,
   hết hạn, gửi lại (UI chờ 60 giây), phiên app chính vẫn còn sau khi khôi phục.

Ngày 2026-11-07 đã cấu hình Gmail SMTP và mẫu Recovery có `{{ .Token }}` trên
project DATN bằng Management API sau khi chủ dự án xác thực. Mã email đã chuyển
từ 8 sang 6 chữ số; hạn hiện có vẫn là 3600 giây, hạn mức email toàn project là
30 thư/giờ. Đăng nhập SMTP đã kiểm tra thành công, chưa gửi email thực tế để
kiểm tra inbox/spam hoặc khôi phục PIN. Chi tiết cấu hình và bước kiểm tra còn
lại xem [password_recovery_otp.md](password_recovery_otp.md). Không ghi mật khẩu
ứng dụng Gmail vào repo. Tạo/đổi PIN, thanh toán và khóa PIN không phụ thuộc SMTP.
UI có liên kết CSKH nếu tài khoản chưa có email xác thực hoặc không nhận được mã.

Tham chiếu chính thức:
- https://supabase.com/docs/reference/dart/auth-resetpasswordforemail
- https://supabase.com/docs/reference/dart/auth-verifyotp
- https://supabase.com/docs/guides/auth/auth-email-templates
- https://supabase.com/docs/guides/auth/auth-smtp

## Deploy và khôi phục an toàn

- Migration PIN chính, policy deny-direct-access và xử lý bộ đếm khi lỗi giao dịch
  nằm trong `supabase/migrations/`.
  Đã áp dụng lên project DATN trong phiên triển khai. Không có seed PIN mặc định,
  không chuyển PIN tài xế sang khách hàng và không đổi bảng tài chính hiện có.
- Phát hành Customer app tương ứng sau backend: app cũ gọi RPC 2 tham số sẽ bị
  từ chối thanh toán Ví. Tài khoản cũ tạo PIN ở lần trả phí Ví tiếp theo.
- Không thêm dependency hoặc biến môi trường/secret mới. Client recovery dùng
  runtime config chung hiện tại; việc chuyển runtime config sang .env là việc riêng.
- Khi gặp sự cố, giữ cổng PIN ở server, hướng dẫn đổi sang VNPAY/CSKH hoặc phát
  hành bản sửa. Không cấp lại quyền unchecked helper, tắt kiểm tra PIN hoặc xóa
  bản băm hàng loạt. Khôi phục của từng khách phải qua xác minh email.
- `PIN_INVALID` có số lần còn lại; `PIN_LOCKED` có giờ server/hạn khóa;
  `EMAIL_VERIFICATION_REQUIRED` yêu cầu gửi mã email mới. Không log raw request
  body ở RPC/proxy có chứa `p_pin`, `p_current_pin`, `p_new_pin` hoặc mã email.

## Kiểm tra

- Flutter: `customer_wallet_pin_ui_test.dart`, `customer_wallet_pin_service_test.dart`,
  `customer_wallet_pin_recovery_service_test.dart`, `order_confirmation_wallet_controller_test.dart`,
  `customer_order_payment_service_test.dart`.
- SQL: `supabase/tests/customer_wallet_payment_pin.sql` dùng tài khoản/phiên Auth/
  đơn/số dư giả trong BEGIN/ROLLBACK. Kiểm tra thiếu mã, mã cũ, 5 lần sai, khóa,
  hết khóa, quyền đọc hash/gọi helper, trừ tiền đúng một lần, payload thay đổi,
  khôi phục thiếu/quá hạn/đã dùng/phiên bị thu hồi, quyền sở hữu và anonymous.
- SQL đã chạy thành công trên project DATN; dữ liệu thử được rollback.
  `platform_fee_collection_regression.sql` cũng đã qua sau khi chuyển sang RPC
  có PIN và cố định giá fixture, gồm thu phí sàn/hoàn phí và các luồng VNPAY hiện có.
- Render đã kiểm tra 320×568, 390×844, 1200×800, chữ 160% và bàn phím mở;
  ảnh `artifacts/wallet_pin/payment_pin.png` đã được xem trực tiếp.
- Không chạy full suite/build app. Gửi email SMTP thực và giao dịch bằng tài
  khoản/số dư thật chưa kiểm thử trong phiên này.
- Kết quả: 26 kiểm thử Flutter tập trung đã qua (gồm lượt capture render),
  analyze các file thay đổi không có issue. Security advisors không phát sinh
  cảnh báo mới so với baseline; các cảnh báo hệ thống có sẵn nằm ngoài thay đổi này.
