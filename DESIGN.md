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
- Mọi màn hình phải follow design system bên dưới
- Target: premium mobile app aesthetic — sạch, nhanh, rõ ràng
- Tránh generic Flutter/Material default UI
- Dùng `AppColors`, `AppTextStyles`, `AppSpacing` từ `lib/core/constants/app_theme.dart`

---

## Design System

> **Aesthetic Direction**: _Clean Utility Premium_ — giao diện tối giản nhưng có chiều sâu. Thông tin phải đọc được ngay trong 1 giây. Cảm giác như Grab gặp Linear app.

---

### Color Palette

Tất cả màu định nghĩa trong `lib/core/constants/app_theme.dart`:

```dart
class AppColors {
  // === Brand ===
  static const primary     = Color(0xFF0F1B2D); // Deep Navy — trust, authority
  static const accent      = Color(0xFFFF6B35); // Vibrant Orange — action, energy
  static const accentLight = Color(0xFFFFEDE6); // Orange tint — backgrounds

  // === Semantic ===
  static const success     = Color(0xFF10B981); // Emerald
  static const warning     = Color(0xFFF59E0B); // Amber
  static const error       = Color(0xFFEF4444); // Rose
  static const info        = Color(0xFF3B82F6); // Blue — map, links

  // === Backgrounds ===
  static const bgLight     = Color(0xFFF8FAFC); // Screen background (light)
  static const bgCard      = Color(0xFFFFFFFF); // Card surface
  static const bgDark      = Color(0xFF1E293B); // Dark surface (driver night mode)
  static const bgDarkCard  = Color(0xFF243447); // Dark card

  // === Text ===
  static const textPrimary   = Color(0xFF0F172A); // Headings, body
  static const textSecondary = Color(0xFF475569); // Subtitles, labels
  static const textMuted     = Color(0xFF94A3B8); // Placeholder, hint
  static const textOnDark    = Color(0xFFF1F5F9); // Text trên nền tối
  static const textOnAccent  = Color(0xFFFFFFFF); // Text trên nút orange

  // === Border ===
  static const border        = Color(0xFFE2E8F0); // Divider, input border
  static const borderFocus   = Color(0xFF0F1B2D); // Input focused

  // === Map Markers ===
  static const markerPickup  = Color(0xFF3B82F6); // Điểm lấy hàng — Blue
  static const markerDrop    = Color(0xFFFF6B35); // Điểm giao hàng — Orange
  static const markerDriver  = Color(0xFF10B981); // Vị trí tài xế — Green
  static const routeLine     = Color(0xFF3B82F6); // Route line trên bản đồ
}
```

**Quy tắc dùng màu theo Role:**

| Role | Background | Accent | Tone |
|------|-----------|--------|------|
| Customer | `bgLight` | `accent` (orange) | Sáng, thân thiện |
| Driver | `bgDark` | `info` (blue) + `accent` | Tối, high-contrast |
| Admin | `bgLight` | `primary` (navy) | Professional, data-dense |

---

### Typography

Font duy nhất: **Plus Jakarta Sans** (hỗ trợ đầy đủ tiếng Việt, premium feel).

Thêm vào `pubspec.yaml`:
```yaml
  google_fonts: ^6.1.0
```

Dùng qua `GoogleFonts.plusJakartaSans(...)` hoặc định nghĩa sẵn:

```dart
class AppTextStyles {
  static final _base = GoogleFonts.plusJakartaSans;

  // Display — màn hình onboarding, hero sections
  static final displayLarge  = _base(fontSize: 32, fontWeight: FontWeight.w800, height: 1.2);
  static final displayMedium = _base(fontSize: 26, fontWeight: FontWeight.w700, height: 1.25);

  // Heading — section titles, screen titles
  static final headingLarge  = _base(fontSize: 22, fontWeight: FontWeight.w700, height: 1.3);
  static final headingMedium = _base(fontSize: 18, fontWeight: FontWeight.w600, height: 1.35);
  static final headingSmall  = _base(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4);

  // Body — nội dung chính
  static final bodyLarge     = _base(fontSize: 15, fontWeight: FontWeight.w400, height: 1.6);
  static final bodyMedium    = _base(fontSize: 14, fontWeight: FontWeight.w400, height: 1.6);
  static final bodySmall     = _base(fontSize: 13, fontWeight: FontWeight.w400, height: 1.5);

  // Label — button, badge, chip
  static final labelLarge    = _base(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1);
  static final labelMedium   = _base(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.2);
  static final labelSmall    = _base(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5);

  // Mono — order ID, mã đơn, số liệu
  static final mono = GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w500);
}
```

---

### Spacing & Layout

Base unit: **4px**. Dùng bội số của 4.

```dart
class AppSpacing {
  static const xs   =  4.0;
  static const sm   =  8.0;
  static const md   = 12.0;
  static const lg   = 16.0;
  static const xl   = 20.0;
  static const xl2  = 24.0;
  static const xl3  = 32.0;
  static const xl4  = 40.0;
  static const xl5  = 48.0;

  // Screen padding horizontal
  static const screenH = 20.0;

  // Bottom nav safe area
  static const bottomNavHeight = 72.0;
}
```

**Border Radius:**
```dart
class AppRadius {
  static const xs   = BorderRadius.all(Radius.circular(6));
  static const sm   = BorderRadius.all(Radius.circular(8));
  static const md   = BorderRadius.all(Radius.circular(12));
  static const lg   = BorderRadius.all(Radius.circular(16));
  static const xl   = BorderRadius.all(Radius.circular(20));
  static const xl2  = BorderRadius.all(Radius.circular(24));
  static const full = BorderRadius.all(Radius.circular(999));
}
```

**Shadows:**
```dart
class AppShadow {
  static const subtle = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const card = [
    BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4)),
  ];
  static const elevated = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 8)),
  ];
  static const accentGlow = [
    BoxShadow(color: Color(0x40FF6B35), blurRadius: 20, offset: Offset(0, 6)),
  ];
}
```

---

### Component Patterns

#### Button — Primary (CTA)
```dart
// Dùng cho: Đặt hàng, Nhận đơn, Xác nhận
Container(
  height: 52,
  decoration: BoxDecoration(
    color: AppColors.accent,
    borderRadius: AppRadius.full,
    boxShadow: AppShadow.accentGlow,
  ),
  child: Center(child: Text('Đặt hàng ngay', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textOnAccent))),
)
```

#### Button — Secondary
```dart
// Dùng cho: Hủy, Xem thêm, Back
Container(
  height: 52,
  decoration: BoxDecoration(
    color: AppColors.bgLight,
    borderRadius: AppRadius.full,
    border: Border.all(color: AppColors.border),
  ),
)
```

#### Card
```dart
Container(
  padding: const EdgeInsets.all(AppSpacing.lg),
  decoration: BoxDecoration(
    color: AppColors.bgCard,
    borderRadius: AppRadius.lg,
    boxShadow: AppShadow.card,
  ),
)
```

#### Status Badge — Order Status
```dart
// Màu theo trạng thái đơn hàng
Color badgeColor(OrderStatus status) => switch (status) {
  OrderStatus.pending     => AppColors.warning,
  OrderStatus.confirmed   => AppColors.info,
  OrderStatus.assigned    => AppColors.info,
  OrderStatus.pickingUp   => AppColors.accent,
  OrderStatus.delivering  => AppColors.accent,
  OrderStatus.delivered   => AppColors.success,
  OrderStatus.cancelled   => AppColors.error,
};
```

#### Input Field
```dart
TextField(
  decoration: InputDecoration(
    filled: true,
    fillColor: AppColors.bgLight,
    border: OutlineInputBorder(
      borderRadius: AppRadius.md,
      borderSide: BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: AppRadius.md,
      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
    hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
  ),
)
```

---

### Animation & Motion

```dart
class AppDuration {
  static const fast   = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow   = Duration(milliseconds: 400);
  static const page   = Duration(milliseconds: 300);
}

class AppCurve {
  static const standard  = Curves.easeInOut;
  static const decelerate = Curves.easeOut;   // Elements vào màn hình
  static const accelerate = Curves.easeIn;    // Elements rời màn hình
  static const spring     = Curves.elasticOut; // Chỉ dùng cho playful moments
}
```

**Quy tắc animation:**
- Transition giữa màn hình: `FadeTransition` + `SlideTransition` 300ms `easeOut`
- Button press: scale xuống 0.97 trong 100ms
- Card appear: `FadeTransition` + slide lên 8px, stagger 50ms mỗi card
- Loading: dùng `Lottie` (đã có trong pubspec) — không dùng `CircularProgressIndicator` mặc định
- Map marker: `ScaleTransition` khi appear

---

### Screen-Specific Design Notes

#### Onboarding
- Full-screen gradient: `primary` → `Color(0xFF1A3A5C)` (navy lighter)
- Text màu `textOnDark`, illustration dùng Lottie
- Page indicator: pill shape, màu `accent`

#### Login
- Background: `bgLight`
- Google button: trắng, border `border`, shadow `subtle`
- Logo/brand centered, clean whitespace

#### Customer Home
- AppBar trong suốt với greeting text
- Search bar nổi bật (rounded, shadow `card`)
- Quick action chips: màu `accentLight` + `accent` icon
- Order card: status badge + timeline indicator

#### Driver Home (Dark Mode)
- Background: `bgDark`
- Status toggle (Available/Busy): pill, màu `success`/`error`
- Đơn chờ nhận: card nền `bgDarkCard`, border trái 3px màu `accent`
- Map chiếm 60% màn hình, controls overlay

#### Order Tracking
- Map full-screen với bottom sheet
- Route line màu `routeLine` (blue), dashed
- Marker pickup: blue pin, marker drop: orange pin
- Driver marker: green dot với pulse animation
- Bottom sheet: `bgCard`, drag handle, thông tin ETA + tên tài xế

#### Admin Dashboard
- Grid 2 cột: metric cards với icon + số lớn
- Chart: dùng `fl_chart` package (thêm khi cần Phase 3)
- Table: alternating row màu `bgLight`/`bgCard`
- Sidebar (web): `primary` background, icon + label

---

### Icons

Dùng `Icons.*` từ Material — **không dùng emoji làm icon**.

Icon mapping chuẩn cho project:
```dart
// Navigation
Icons.home_rounded         // Home
Icons.list_alt_rounded     // Danh sách đơn
Icons.map_rounded          // Bản đồ
Icons.history_rounded      // Lịch sử
Icons.person_rounded       // Profile

// Order actions
Icons.add_location_alt_rounded  // Thêm địa chỉ
Icons.local_shipping_rounded    // Giao hàng
Icons.check_circle_rounded      // Đã giao
Icons.cancel_rounded            // Hủy
Icons.access_time_rounded       // Thời gian

// Driver
Icons.directions_car_rounded    // Xe
Icons.navigation_rounded        // Dẫn đường
Icons.radio_button_on_rounded   // Trạng thái online

// Admin
Icons.dashboard_rounded         // Dashboard
Icons.people_alt_rounded        // Quản lý tài xế
Icons.inventory_2_rounded       // Quản lý đơn
```

**Icon size chuẩn:** 20px (inline), 24px (standalone), 28px (header action).

---

### Anti-Patterns — KHÔNG làm

| ❌ Sai | ✅ Đúng |
|--------|---------|
| `Colors.blue`, `Colors.orange` mặc định | Dùng `AppColors.*` |
| `TextStyle(fontSize: 16)` hardcode | Dùng `AppTextStyles.*` |
| `EdgeInsets.all(16)` random | Dùng `AppSpacing.*` |
| `CircularProgressIndicator()` thuần | Lottie hoặc shimmer skeleton |
| `Container` màu trắng thuần không shadow | Card với `AppShadow.card` |
| Emoji icon (🚀 📦 🗺️) | `Icons.*` hoặc SVG |
| `BorderRadius.circular(4)` — quá vuông | Tối thiểu `AppRadius.sm` (8px) |
| `showDialog` mặc định với AlertDialog | Custom bottom sheet hoặc custom dialog |
| Text overflow không handle | `overflow: TextOverflow.ellipsis` |
| Không có `SafeArea` | Luôn wrap screen với `SafeArea` |

## Conventions
- File: snake_case.dart
- Class: PascalCase
- Mỗi feature có thư mục riêng trong features/
- Model có fromJson / toJson
- Không hardcode string
- Supabase URL và anon key trong supabase_constants.dart
- RLS bật cho tất cả bảng
- Không insert thủ công vào bảng users (trigger tự xử lý)