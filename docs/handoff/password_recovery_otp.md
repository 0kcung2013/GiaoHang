# Quên mật khẩu bằng OTP email

Triển khai cho Customer và Driver ngày 2026-11-07. Từ màn hình đăng nhập,
bấm **Quên mật khẩu?** để mở luồng dùng chung:

1. Nhập email đăng ký, lấy sẵn email đã nhập ở màn hình đăng nhập.
2. Nhập mã OTP 6 chữ số trong email. Hỗ trợ dán mã và autofill; giữ số 0 đầu.
3. Nhập mật khẩu mới và nhập lại, tối thiểu 6 ký tự theo form đăng ký hiện tại.
   Supabase tiếp tục kiểm tra chính sách mật khẩu của project; lỗi mật khẩu yếu
   hoặc trùng mật khẩu cũ được hiển thị bằng tiếng Việt.
4. Sau khi lưu thành công, bấm **Về đăng nhập**. App giữ email, xóa mật khẩu cũ;
   đăng nhập và kiểm tra role/KYC/vô hiệu hóa tài khoản vẫn qua luồng hiện có.

## Thành phần và hành vi

- Mã nguồn nằm trong `packages/giaohang_mobile/lib/features/auth/password_recovery/`:
  screen điều phối form/điều hướng; controller quản lý bước, tác vụ và gửi lại;
  gateway/service giữ giao tiếp Auth; widgets và validation được tách riêng.
- Dùng token `giaohang_design`, nền trắng, chữ navy, CTA cam; form cuộn được khi
  bàn phím mở, hỗ trợ chữ 160%, nút hiện/ẩn mật khẩu, thông báo lỗi và loading.
- Nút gửi lại chờ 60 giây, tính từ mốc thời gian thay vì chỉ giảm một biến đếm.
  Đổi email không bỏ qua thời gian chờ. Supabase vẫn áp dụng rate limit của server.
- Phản hồi gửi mã không công bố email có tài khoản hay không. Gửi mã không tạo
  tài khoản mới. Không log hoặc lưu OTP/mật khẩu vào database hay preferences.
- Có liên hệ CSKH qua email, tái sử dụng thông tin liên hệ hiện có. Nội dung email
  hỗ trợ nói về khôi phục mật khẩu; không tự gửi thư thay người dùng.
- Nếu mất kết nối khi lưu, app báo chưa xác nhận được kết quả và cho thử lại.
  Nếu server đã nhận lần trước, người dùng cũng có thể quay về đăng nhập bằng
  mật khẩu vừa đặt; app không tự suy đoán thành công từ lỗi mạng.

## Phiên xác thực

Service tạo `SupabaseClient` riêng trong bộ nhớ, không dùng session của client
chính và không bật auto refresh:

`resetPasswordForEmail` → `verifyOTP(type: OtpType.recovery)` →
`updateUser(UserAttributes(password: ...))`.

Chỉ gọi update sau khi nhận session recovery và email khớp. Không ghi role vào
metadata, không gọi `claim_active_session`, không tự đưa người dùng vào trang chủ.
Sau thành công hoặc đóng màn hình, đăng xuất **scope local** phiên recovery rồi
dispose client. Nếu đóng khi request còn chạy, cleanup đợi request hoàn tất để
thu hồi cả session trả về muộn. Nếu mạng làm logout thất bại, client vẫn bị
dispose và không có session recovery được lưu trên thiết bị; không cam kết thu
hồi được session ở server trong lúc mất mạng.

Khôi phục PIN ví giữ nguyên RPC và chỉ dùng recovery để chứng minh quyền truy cập
email; luồng mật khẩu mới không gọi RPC PIN, không thay đổi PIN thanh toán.

## Cấu hình và phần cần vận hành kiểm tra

Không thêm dependency, biến môi trường, secret, schema, migration, RLS hoặc Edge
Function. Tái sử dụng runtime config trong `giaohang_config`. Không cần deep link
cho luồng nhập OTP này. Không nâng phiên bản Supabase SDK trong thay đổi này.

Trong Supabase Dashboard:

1. **Authentication → Email Templates → Reset Password/Recovery**: email phải có
   `{{ .Token }}`. Mẫu có sẵn `supabase/templates/wallet_pin_recovery.html` đã dùng
   nội dung chung cho khôi phục PIN và truy cập tài khoản, có thể tái sử dụng.
   File trong repo không tự cập nhật cấu hình hosted Supabase.
2. Kiểm tra **Email OTP length = 6**. Hạn mã do Supabase quyết định; có thể dùng
   khuyến nghị 10 phút trong tài liệu PIN ví. Không tự đổi hạn/rate limit chung
   trước khi đối chiếu các luồng Auth khác. App không tự quyết định hiệu lực mã.
3. Kiểm tra SMTP hiện có gửi tới địa chỉ người dùng thực. Giới hạn và danh sách
   người nhận của dịch vụ email mặc định có thể không đủ cho phát hành ứng dụng.
   Không đưa SMTP password hoặc service role key vào Flutter.
4. Dùng hộp thư kiểm thử do vận hành quản lý: kiểm tra inbox/spam, mã sai/hết hạn,
   gửi lại, mật khẩu mới/cũ, quay lại khi đang gửi và đăng nhập đúng app theo role.
   Kiểm tra lại **Quên PIN ví** sau khi chỉnh mẫu Recovery vì cùng loại email Auth.
5. Luồng hiện tại không có UI CAPTCHA. Nếu bật CAPTCHA cho recovery, cần tích hợp
   lấy và truyền captcha token trước khi phát hành; không tắt kiểm tra để né lỗi.

Ngày 2026-11-07 đã cấu hình Auth hosted của project **DATN**
(`erlpzwfbpjogvaulcxni`) bằng Supabase Management API sau khi chủ dự án xác thực:

| Cấu hình | Giá trị đã đọc lại từ server |
| --- | --- |
| SMTP host / port | `smtp.gmail.com` / `465` (TLS) |
| SMTP username / sender email | `sidat3241@gmail.com` |
| Sender name | `GiaoHang` |
| Email OTP length | `6` (trước đó là `8`) |
| Email OTP expiry | `3600` giây; giữ hạn hiện có, chưa đổi sang khuyến nghị 10 phút |
| Recovery template | Đã áp dụng mẫu dùng chung có `{{ .Token }}` |
| Hạn mức email Auth | `30` thư/giờ cho toàn project (trước đó là `2`) |

Đã kiểm tra TLS và đăng nhập Gmail SMTP thành công bằng mật khẩu ứng dụng do
chủ tài khoản cung cấp. Mật khẩu chỉ được xử lý trong bộ nhớ và lưu vào cấu hình
SMTP phía Supabase; không ghi giá trị vào repo, `.env`, tài liệu hay log.
Send Email hook và CAPTCHA đang tắt tại thời điểm kiểm tra; phiên này không đổi
hai cài đặt đó. Không đổi schema, RLS, Edge Functions hoặc chính sách session.

Kiểm tra SMTP chỉ xác thực kết nối/đăng nhập, **không gửi email**. Chưa kiểm tra
OTP thực tế tới inbox/spam hoặc thao tác đổi mật khẩu bằng tài khoản thật.
Vận hành cần dùng bản app mới thực hiện bước kiểm tra hộp thư ở trên để xác nhận
toàn bộ luồng trên môi trường phát hành. Nếu thay mật khẩu ứng dụng Gmail,
cập nhật lại trường SMTP password trong Supabase rồi kiểm tra lại kết nối.

## Kiểm tra và xử lý sự cố

Chạy trong `packages/giaohang_mobile`:

```powershell
flutter test --no-pub test/password_recovery_service_test.dart test/password_recovery_controller_test.dart test/password_recovery_ui_test.dart test/password_recovery_entry_test.dart test/login_experiment_view_test.dart test/driver_auth_ui_test.dart test/customer_wallet_pin_recovery_service_test.dart
```

Thêm `--dart-define=CAPTURE_PASSWORD_RECOVERY=true` để xuất ảnh bốn bước vào
`artifacts/password_recovery/`. Analyze tập trung các file Auth vừa thay đổi.
Không cần chạy full suite hoặc build cả app cho thay đổi này.

Kết quả trong phiên triển khai: 36 test tập trung trong bảy file trên đã qua;
analyze các file Auth thay đổi không có issue. Đã xem trực tiếp ảnh render bốn
trạng thái ở 390×844; widget tests còn kiểm tra 320×568 và 1200×800, chữ 160%
và bàn phím mở. Chưa chạy full suite, build app hoặc kiểm thử gửi email thực.

- Chỉ thấy liên kết trong thư: mẫu Recovery hosted chưa chứa `{{ .Token }}`.
- Không nhận được thư: xem Auth logs, SMTP, hạn mức gửi và spam; không hỏi người
  dùng cung cấp mật khẩu, OTP hoặc secret để chẩn đoán.
- Mã sai/hết hạn: gửi mã mới sau thời gian chờ; chỉ dùng mã từ thư mới nhất.
- Phiên xác minh hết hạn khi đặt mật khẩu: app trở về bước mã để xác minh lại.
- Email của role khác vẫn có thể khôi phục credential Auth; quyền vào app do
  luồng đăng nhập/kiểm tra role hiện có quyết định, không dựa vào role client gửi.
- Khôi phục an toàn: có thể phát hành lại UI trước đó nếu cần; không thay đổi
  schema hoặc bỏ kiểm tra Auth. Mật khẩu đã đổi không thể khôi phục về giá trị cũ;
  người dùng thực hiện lại quy trình khôi phục nếu cần.

Tài liệu chính thức:

- https://supabase.com/docs/reference/dart/auth-resetpasswordforemail
- https://supabase.com/docs/reference/dart/auth-verifyotp
- https://supabase.com/docs/reference/dart/auth-updateuser
- https://supabase.com/docs/guides/auth/auth-email-templates
- https://supabase.com/docs/guides/auth/auth-smtp
