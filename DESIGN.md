# DATN — Hệ thống Giao Hàng Thông Minh

## Mô tả Project
Ứng dụng giao hàng 1 Flutter project duy nhất, hỗ trợ 3 loại người dùng: khách hàng đặt đơn, tài xế nhận & giao hàng, admin quản lý hệ thống. Sau khi đăng nhập, app tự động điều hướng đến giao diện đúng theo role.

## Cấu trúc Project (1 project duy nhất)
```
project_app/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── constants/
│   │   │   └── supabase_constants.dart
│   │   ├── models/
│   │   │   ├── user_model.dart
│   │   │   ├── order_model.dart
│   │   │   ├── driver_model.dart
│   │   │   └── route_model.dart
│   │   ├── services/
│   │   │   ├── auth_service.dart
│   │   │   ├── order_service.dart
│   │   │   └── location_service.dart
│   │   └── router.dart
│   ├── features/
│   │   ├── onboarding/
│   │   │   └── screens/onboarding_screen.dart
│   │   ├── auth/
│   │   │   └── screens/login_screen.dart
│   │   ├── customer/
│   │   │   ├── screens/
│   │   │   │   ├── customer_home_screen.dart
│   │   │   │   ├── place_order_screen.dart
│   │   │   │   ├── order_tracking_screen.dart
│   │   │   │   └── order_history_screen.dart
│   │   │   └── widgets/
│   │   ├── driver/
│   │   │   ├── screens/
│   │   │   │   ├── driver_home_screen.dart
│   │   │   │   ├── order_list_screen.dart
│   │   │   │   ├── navigation_screen.dart
│   │   │   │   └── driver_history_screen.dart
│   │   │   └── widgets/
│   │   └── admin/
│   │       ├── screens/
│   │       │   ├── admin_home_screen.dart
│   │       │   ├── manage_orders_screen.dart
│   │       │   ├── manage_drivers_screen.dart
│   │       │   └── dashboard_screen.dart
│   │       └── widgets/
└── pubspec.yaml
```

## Tech Stack
- **Frontend**: Flutter (Dart) — Android/iOS/Web từ 1 codebase
- **Backend**: Supabase (PostgreSQL + Realtime + Auth + Storage)
- **Bản đồ**: flutter_map + OpenStreetMap (tiles)
- **Routing API**: OSRM (Open Source Routing Machine) — miễn phí
- **Thuật toán**: VRP (Vehicle Routing Problem) / Nearest Neighbor + 2-opt
- **State Management**: Riverpod
- **Navigation**: GoRouter với route guard theo role
- **Realtime**: Supabase Realtime cho tracking tài xế

## Commands
```bash
flutter run                    # Chạy app
flutter run -d chrome          # Chạy trên web
flutter test                   # Chạy tests
flutter analyze                # Static analysis
flutter pub get                # Cài dependencies
flutter build apk              # Build Android
flutter build web              # Build web
```

## Dependencies (pubspec.yaml)
```yaml
dependencies:
  flutter_map: ^7.0.0
  latlong2: ^0.9.0
  supabase_flutter: ^2.0.0
  flutter_riverpod: ^2.0.0
  go_router: ^14.0.0
  lottie: ^3.1.0
  google_sign_in: ^6.2.0
```

## Database Schema (Supabase)

### Enum Types
- **user_role**: customer, driver, admin
- **order_status**: pending, confirmed, assigned, picking_up, delivering, delivered, cancelled

### Bảng chính
- **users** — id (UUID), email (UNIQUE), full_name, phone, role (user_role), avatar_url, created_at
- **drivers** — id, user_id → users, vehicle_type, license_plate, is_available, current_lat, current_lng, updated_at
- **orders** — id, customer_id → users, driver_id → users, status (order_status), pickup_address, pickup_lat, pickup_lng, delivery_address, delivery_lat, delivery_lng, total_price, note, created_at
- **order_items** — id, order_id → orders (CASCADE), name, quantity, price
- **routes** — id, driver_id → drivers (CASCADE), date, optimized_path (JSONB), total_distance, total_duration, status
- **locations** — id, driver_id → drivers (CASCADE), lat, lng, timestamp

### Trigger
- **on_auth_user_created**: Tự động insert vào bảng users khi có user mới đăng ký qua Supabase Auth
- Function: handle_new_user() — SECURITY DEFINER

## Routing theo Role
```
/ (root)
├── /onboarding       → OnboardingScreen (lần đầu mở app)
├── /login            → LoginScreen (chỉ Google OAuth)
├── /customer         → CustomerHomeScreen (role: customer)
│   ├── /customer/place-order
│   ├── /customer/tracking/:orderId
│   └── /customer/history
├── /driver           → DriverHomeScreen (role: driver)
│   ├── /driver/orders
│   ├── /driver/navigation/:orderId
│   └── /driver/history
└── /admin            → AdminHomeScreen (role: admin)
    ├── /admin/orders
    ├── /admin/drivers
    └── /admin/dashboard
```

## Auth Flow
1. Mở app → check SharedPreferences → onboarding (lần đầu) hoặc login
2. Login bằng Google OAuth (Supabase)
3. Sau login → check role từ bảng users
4. Navigate đến đúng home screen theo role:
   - customer → /customer
   - driver → /driver
   - admin → /admin
5. GoRouter redirect guard: chưa login → về /login

## Tính năng theo Priority

### 🔴 Phase 1 — Core (Tháng 1-2)
- [x] Onboarding screen
- [x] Auth: đăng nhập Google theo role
- [ ] Customer home screen
- [ ] Driver home screen
- [ ] Admin home screen
- [ ] Routing theo role hoàn chỉnh

### 🟡 Phase 2 — Map & Ordering (Tháng 3-4)
- [ ] Customer: đặt đơn + chọn địa chỉ trên bản đồ
- [ ] Driver: nhận đơn + xem route
- [ ] Realtime tracking vị trí tài xế
- [ ] Customer: theo dõi đơn trên bản đồ
- [ ] Driver: navigation từng bước (OSRM)

### 🟢 Phase 3 — Optimization (Tháng 5-6)
- [ ] Thuật toán VRP tối ưu route nhiều đơn
- [ ] Admin: dashboard thống kê
- [ ] Notification
- [ ] Rating tài xế
- [ ] Lịch sử đơn hàng

## Map & Routing Notes
- Dùng flutter_map (không phải google_maps_flutter) — hỗ trợ Web + Android + iOS
- Tile server: https://tile.openstreetmap.org/{z}/{x}/{y}.png
- Routing: OSRM API https://router.project-osrm.org/route/v1/driving/{coords}
- Tài xế gửi vị trí lên Supabase mỗi 5 giây khi đang giao hàng

## UI Design Rules
- Luôn đọc DESIGN.md trước khi tạo hoặc sửa bất kỳ UI nào
- Mọi màn hình phải follow design system trong DESIGN.md
- Target: premium mobile app aesthetic
- Tránh generic Flutter/Material default UI
- Dùng custom colors, typography, spacing từ DESIGN.md

## Conventions
- File: snake_case.dart
- Class: PascalCase
- Mỗi feature có thư mục riêng trong features/
- Model có fromJson / toJson
- Không hardcode string
- Supabase URL và anon key trong supabase_constants.dart
- RLS bật cho tất cả bảng
- Không insert thủ công vào bảng users (trigger tự xử lý)