# Hai app mobile độc lập

Quyết định ngày 2026-10-16: Customer và Driver có ứng dụng cài đặt riêng,
đăng nhập/đăng ký riêng; vẫn dùng một monorepo và backend Supabase hiện có.

| | Khách hàng | Tài xế |
|---|---|---|
| App | `apps/customer_app` | `apps/driver_app` |
| Android/iOS ID | `com.datn.giaohang.customer` | `com.datn.giaohang.driver` |
| Đăng ký | Thông tin khách hàng | Hồ sơ tài xế và KYC |
| GPS nền | Không khởi động | Giữ luồng theo dõi giao/hoàn hàng |
| Session local | `giaohang-customer-session` | `giaohang-driver-session` |

`packages/giaohang_mobile` chứa nghiệp vụ, UI, tests và assets được chuyển từ
`apps/delivery_app`. Hai app là entry point/native host riêng, dùng chung package
này. Router chỉ khai báo màn hình thuộc vai trò của app; tài khoản không đúng
vai trò được đưa đến màn hình đăng xuất. Supabase vẫn quyết định quyền dữ liệu.
Operations Web tiếp tục dùng riêng cho CSKH/Admin.

## Chạy

Chạy `flutter pub get` từ root. Sau đó mở hai terminal:

```powershell
cd apps/customer_app
flutter run -d chrome --web-port 8081
```

```powershell
cd apps/driver_app
flutter run -d chrome --web-port 8082
```

Để chạy Android/iOS, dùng `flutter run -d <device-id>` tại mỗi app. Hai application
ID khác nhau cho phép cài cùng lúc. iOS cần macOS/Xcode và signing riêng.
Tài khoản hiện có tiếp tục dùng được trong app đúng vai trò. Người dùng đăng nhập
lại lần đầu vì app mới có vùng lưu phiên riêng; không tự sao chép phiên cũ.

## OAuth

App khách hàng khai báo callback `com.datn.giaohang.customer://login-callback`
trên Android/iOS. Cần thêm URI này vào Supabase Auth Redirect URLs để Google
đăng nhập quay về app; bản web cần origin tương ứng trong allowlist. Không đưa
secret vào app. Thay đổi allowlist trên server chưa được thực hiện trong lần tách
source này. Driver giữ đăng nhập email/mật khẩu và quy trình KYC hiện có.

Đã chuẩn bị `tool/configure_mobile_auth_redirects.py`: đọc cấu hình hiện tại,
bổ sung callback mobile và các origin localhost/127.0.0.1 cổng 8081–8082,
giữ URL cũ và kiểm tra lại sau khi lưu. Script chỉ cập nhật `uri_allow_list`,
không thay Site URL hay cấu hình Google provider. Theo
[Management API](https://supabase.com/docs/reference/api/v1-update-auth-service-config),
token cần quyền cập nhật Auth của project DATN.

```powershell
python tool/configure_mobile_auth_redirects.py --apply --prompt-token
```

Token được nhập ẩn tại terminal, không lưu vào source. Có thể dùng biến môi
trường `SUPABASE_ACCESS_TOKEN` thay cho lời nhắc. Kiểm tra ngày 2026-10-17:
Google provider đã bật, nhưng phiên CLI hiện có không thấy project DATN;
MCP hiện không cung cấp thao tác sửa Auth config. Chưa cập nhật server.

## Kiểm tra

- `packages/giaohang_mobile`: kiểm thử auth, role routing, GPS và nghiệp vụ chung.
- `apps/customer_app`, `apps/driver_app`: kiểm thử entry point, analyze và build.
- Assets phải được đọc bằng prefix `packages/giaohang_mobile/assets/`.
- Không đổi schema, RLS, pipeline GPS/R2 hoặc thuật toán ETA khi tách app.

Native host cũ được giữ trong `.tmp/legacy_delivery_app` để đối chiếu cấu hình
trong workspace, không còn là app thuộc Dart workspace.

## Kiểm chứng lần tách app

- Analyze các file auth, bootstrap và router: không có lỗi.
- 52 kiểm thử tập trung: role routing, đăng ký, đăng nhập, assets, GPS và hoàn hàng.
- Render ba màn hình đăng nhập/đăng ký ở 390 × 844; widget tests kiểm tra thêm
  màn hình nhỏ, bàn phím, chữ lớn và màn hình rộng.
- Hai bản web build thành công; asset model ETA, marker và ảnh đăng nhập đều
  được đóng gói dưới prefix package mới.
- Hai APK debug đã được tạo tại `apps/<customer_app|driver_app>/build/app/outputs/flutter-apk/app-debug.apk`.
  Đã kiểm tra application ID và manifest gộp: chỉ app tài xế giữ quyền GPS nền.
- Chưa kiểm thử đăng nhập Google trên thiết bị thật hoặc build iOS trên macOS.

Lưu ý môi trường: Gradle tiếp tục dùng `flutter.minSdkVersion` như native host
cũ. APK sinh từ SDK hiện có báo minSdk **24**, khác mục tiêu 21 ghi trong
AGENTS.md. Việc hỗ trợ lại Android API 21 cần kiểm tra tương thích SDK/plugin
riêng, không được xác nhận trong lần tách này.
