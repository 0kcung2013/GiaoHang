# CLAUDE.md — DATN GiaoHang (Flutter)

## 1) Mô tả project
Dự án hiện tại là **1 Flutter app duy nhất** (tên package: `customer_app`) cho hệ thống giao hàng thông minh DATN.  
App hỗ trợ luồng onboarding, đăng nhập Google OAuth qua Supabase, và điều hướng theo role người dùng (`customer`, `driver`, `admin`).

## 2) Tech stack thực tế (đọc từ pubspec.yaml)

### SDK
- Dart SDK: `^3.9.0`

### Dependencies
- `flutter` (SDK)
- `cupertino_icons: ^1.0.8`
- `flutter_map: ^7.0.0`
- `latlong2: ^0.9.0`
- `supabase_flutter: ^2.0.0`
- `riverpod: ^2.0.0`
- `go_router: ^14.0.0`
- `google_sign_in: ^6.2.0`
- `shared_preferences: ^2.3.0`
- `lottie: ^3.1.0`

### Dev dependencies
- `flutter_test` (SDK)
- `flutter_lints: ^6.0.0`

## 3) Cấu trúc thư mục thực tế (khảo sát hiện tại)

```txt
.
├── android/
├── ios/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── router.dart
│   │   ├── constants/
│   │   │   └── supabase_constants.dart
│   │   └── services/
│   │       └── auth_service.dart
│   └── features/
│       ├── onboarding/
│       │   └── screens/
│       │       └── onboarding_screen.dart
│       ├── auth/
│       │   └── screens/
│       │       └── login_screen.dart
│       ├── customer/
│       │   └── screens/
│       │       └── customer_home_screen.dart
│       ├── driver/
│       │   └── screens/
│       │       └── driver_home_screen.dart
│       └── admin/
│           └── screens/
│               └── admin_home_screen.dart
├── web/
├── windows/
├── linux/
├── macos/
├── test/
│   └── widget_test.dart
├── pubspec.yaml
├── pubspec.lock
├── DESIGN.md
├── ROADMAP.md
├── UI_REFERENCE.md
├── AGENTS.md
└── README.md
```

## 4) Kiến trúc & conventions đang dùng (thực tế trong code)

### Kiến trúc
- `lib/features/*` theo domain (`auth`, `customer`, `driver`, `admin`, `onboarding`)
- Có thư mục `core` cho router/constants/services
- Hiện trạng nghiêng về **feature-first ở mức cơ bản** (chưa đầy đủ data/domain/presentation layers)

### Navigation
- Dùng `go_router`
- Router khai báo trong `lib/core/router.dart`
- Có `redirect` guard dựa trên trạng thái đăng nhập và role trong bảng `users`
- Có xử lý OAuth callback URL (`code`, `access_token`) ở redirect

### State management
- Package `riverpod` đã có trong `pubspec.yaml` nhưng **chưa thấy sử dụng trong code hiện tại**
- Hiện tại chủ yếu dùng `StatefulWidget + setState`

### Backend/API
- Supabase qua `supabase_flutter`
- Khởi tạo ở `main.dart` với hằng số trong `core/constants/supabase_constants.dart`
- Auth: Google OAuth (`signInWithOAuth`)
- Data role: query bảng `users` để điều hướng theo role

### Naming convention hiện thấy
- File Dart: `snake_case.dart`
- Class: `PascalCase`
- Route path: kebab-case (vd: `/customer-home`, `/driver-home`)

## 5) Lệnh Flutter thường dùng

```bash
flutter pub get
flutter analyze
flutter test
flutter run
flutter run -d chrome
flutter build apk
flutter build web
```

## 6) Lưu ý quan trọng
- `supabase_constants.dart` hiện đang chứa trực tiếp URL và anon key.
- Theo best practice nên chuyển sang `.env`/secret config, tránh hardcode credentials trong source.
- UI custom đã có ở onboarding/login, nhưng nhiều màn hình khác vẫn đang placeholder.


## 7) Supabase Schema hiện tại
- Bảng `users`: id, email, role (customer/driver/admin)
- [Bổ sung thêm khi có bảng orders, drivers...]

## 8) Những việc AI KHÔNG được tự làm
- KHÔNG sửa `lib/core/router.dart` khi chưa hỏi
- KHÔNG thay đổi Supabase schema
- KHÔNG xóa bất kỳ file nào
- KHÔNG thêm package mới vào pubspec.yaml khi chưa confirm

## 9) Thứ tự làm việc ưu tiên
1. Customer flow trước
2. Driver flow sau
3. Admin flow cuối