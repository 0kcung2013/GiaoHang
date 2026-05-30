# GiaoHang

Ứng dụng Flutter cho hệ thống giao hàng thông minh DATN, hỗ trợ 3 vai trò người dùng:

- **Customer**: đặt đơn hàng, theo dõi đơn
- **Driver**: nhận đơn, giao hàng, cập nhật vị trí
- **Admin**: quản lý đơn hàng và tài xế

Hiện tại project đang ở giai đoạn nền tảng, đã có onboarding, Google OAuth với Supabase, routing theo role, và các màn hình home placeholder cho từng role.

> Architecture decision: project này là **một Flutter app duy nhất** cho 3 role. Không tách repo thành `customer_app/`, `driver_app/`, `admin_web/`, hoặc `shared/`.

---

## 1. Tech stack thực tế

### Flutter / Dart
- Flutter
- Dart SDK `^3.9.0`

### Packages trong `pubspec.yaml`
#### dependencies
- `flutter`
- `cupertino_icons: ^1.0.8`
- `flutter_map: ^7.0.0`
- `latlong2: ^0.9.0`
- `supabase_flutter: ^2.0.0`
- `riverpod: ^2.0.0`
- `go_router: ^14.0.0`
- `google_sign_in: ^6.2.0`
- `shared_preferences: ^2.3.0`
- `lottie: ^3.1.0`

#### dev_dependencies
- `flutter_test`
- `flutter_lints: ^6.0.0`

---

## 2. Cấu trúc project hiện tại

```txt
.
├── android/
├── ios/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── router.dart
│   │   ├── constants/
│   │   ├── models/
│   │   ├── providers/
│   │   └── services/
│   └── features/
│       ├── admin/
│       │   └── screens/
│       │       └── home/home_screen.dart
│       ├── auth/
│       │   └── screens/
│       │       └── login/login_screen.dart
│       ├── customer/
│       │   └── screens/
│       │       ├── home/home_screen.dart
│       │       ├── dashboard/dashboard_screen.dart
│       │       ├── order/order_screen.dart
│       │       ├── tracking/tracking_screen.dart
│       │       ├── account/account_screen.dart
│       │       └── create_order/create_order_screen.dart
│       ├── driver/
│       │   └── screens/
│       │       └── home/home_screen.dart
│       └── onboarding/
│           └── screens/
│               └── onboarding/onboarding_screen.dart
├── test/
│   └── widget_test.dart
├── web/
├── windows/
├── linux/
├── macos/
├── AGENTS.md
├── CLAUDE.md
├── DESIGN.md
├── ROADMAP.md
├── UI_REFERENCE.md
├── analysis_options.yaml
├── pubspec.yaml
└── README.md
```

---

## 3. Kiến trúc hiện tại

Project hiện tại đang theo hướng **feature-first cơ bản**:

- `lib/features/` chứa từng nhóm tính năng theo domain:
  - `onboarding`
  - `auth`
  - `customer`
  - `driver`
  - `admin`
- `lib/core/` chứa phần dùng chung:
  - `router.dart`
  - `constants/`
  - `models/`
  - `providers/`
  - `services/`

Tuy nhiên kiến trúc vẫn còn ở mức khởi tạo:
- Đã có `models/`, `services/`, và một số Riverpod providers trong `core`
- Một số `widgets/` folder đang trống hoặc chưa dùng
- Chưa có tầng data/domain/presentation rõ ràng
- Một số màn hình vẫn là placeholder hoặc mock data

---

## 4. State management, navigation, backend

### State management
- Package đang khai báo: `riverpod` / `flutter_riverpod`
- Thực tế code hiện tại: **đã dùng Riverpod một phần**
- State đang quản lý chủ yếu bằng:
  - `StatefulWidget`
  - `setState`
  - `FutureProvider.family` cho một số dữ liệu customer

### Navigation
- Dùng `go_router`
- Router nằm trong: `lib/core/router.dart`
- Có `redirect` guard theo:
  - trạng thái đăng nhập
  - role từ bảng `users`
- Có xử lý callback OAuth qua URL (`code`, `access_token`)

### Backend / API
- Dùng **Supabase**
- Khởi tạo ở `lib/main.dart`
- Config lấy từ `lib/core/constants/supabase_constants.dart`
- Đăng nhập Google bằng:
  - `supabase.auth.signInWithOAuth(OAuthProvider.google)`
- Query role từ bảng `users`

### Tích hợp khác
- `shared_preferences`: lưu trạng thái đã hoàn thành onboarding
- `flutter_map` + `latlong2`: đã có dependency nhưng chưa thấy triển khai màn hình map thực tế
- `lottie`: đã khai báo dependency
- `google_sign_in`: đã khai báo dependency nhưng auth hiện tại đang đi qua Supabase OAuth

---

## 5. Luồng app hiện tại

1. App khởi tạo `Supabase.initialize()`
2. Đọc `SharedPreferences` để kiểm tra `onboarding_done`
3. Kiểm tra `currentUser`
4. Chọn route khởi đầu:
   - chưa onboarding → `/onboarding`
   - đã onboarding nhưng chưa login → `/login`
   - đã login → `/`
5. `GoRouter` redirect tiếp tục điều hướng theo role:
   - `admin` → `/admin-home`
   - `driver` → `/driver-home`
   - mặc định → `/customer-home`

---

## 6. Hiện trạng code

### Đã có
- `main.dart`
- `core/router.dart`
- `core/constants/supabase_constants.dart`
- `core/constants/app_theme.dart`
- `core/constants/colors.dart`
- `core/models/`
- `core/providers/customer_providers.dart`
- `core/services/`
- `features/onboarding/screens/onboarding/onboarding_screen.dart`
- `features/auth/screens/login/login_screen.dart`
- `features/customer/screens/`
- `features/driver/screens/home/home_screen.dart`
- `features/admin/screens/home/home_screen.dart`

### Chưa có hoặc còn thiếu
- Tầng data/domain/presentation rõ ràng theo feature
- Shared widgets ổn định cho UI lặp lại
- Các màn hình nghiệp vụ thực tế:
  - đặt đơn có chọn tọa độ/bản đồ thật
  - theo dõi đơn bằng dữ liệu realtime thật
  - danh sách đơn cho tài xế
  - dashboard admin
- Tests ngoài `widget_test.dart`
- Cấu hình env/secrets an toàn

---

## 7. Các file tài liệu quan trọng

- `AGENTS.md`: context tổng quan project
- `DESIGN.md`: design system và định hướng UI
- `ROADMAP.md`: roadmap và thứ tự ưu tiên tính năng
- `CLAUDE.md`: mô tả kỹ thuật và cấu trúc project thực tế
- `.clinerules`: quy tắc làm việc với project này

---

## 8. Lệnh Flutter thường dùng

```bash
flutter pub get
flutter analyze
flutter test
flutter run
flutter run -d chrome
flutter build apk
flutter build web
```

---

## 9. Những điểm cần chú ý ngay

1. `supabase_constants.dart` đang hardcode Supabase URL và anon key
2. `riverpod` đã được dùng một phần, nhưng chưa nhất quán toàn app
3. `google_sign_in` đã cài nhưng flow login đang phụ thuộc vào Supabase OAuth
4. Nhiều màn hình customer vẫn còn mock data/hardcoded UI
5. `driver_home` và `admin_home` vẫn chỉ là placeholder
6. Design token đang bị chia giữa `AppColors`, `NavColors`, và `OrderColors`
7. Trước khi ghi dữ liệu, cần kiểm tra schema compatibility trong `docs/CLEANUP_PLAN.md`

---

## 10. Gợi ý thứ tự phát triển tiếp theo

### Ưu tiên cao
1. Hoàn thiện `Customer Home Screen`
2. Tích hợp `flutter_map` cơ bản
3. Tạo màn hình đặt đơn hàng

### Ưu tiên tiếp theo
4. Hoàn thiện luồng Google OAuth ổn định cho web/mobile
5. Tạo model + service cho `users`, `orders`, `drivers`
6. Chuẩn hóa state management bằng Riverpod

### Cleanup notes
- Preferred design tokens: `AppColors`, `AppTextStyles`, `AppSpacing`, `AppRadius` từ `lib/core/constants/app_theme.dart`
- Không xóa `NavColors` hoặc `OrderColors` trong Phase 1
- Supabase URL/anon key nên chuyển sang `.env` trong cleanup riêng sau này; hiện chưa đổi runtime config
- Xem thêm: `docs/CLEANUP_PLAN.md`

---

## 11. Ghi chú
- Không tự ý sửa `main.dart` nếu chưa có yêu cầu rõ ràng
- Không đổi `go_router`, `riverpod`, `flutter_map` nếu chưa được yêu cầu
- Mọi UI mới cần bám theo `DESIGN.md`
- Trước khi sửa UI, nên đọc lại `DESIGN.md`
