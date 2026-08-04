# DATN — Hệ thống Giao Hàng Thông Minh

## Phase 1 Documentation Note

- Project hiện là **một monorepo với hai Flutter app**: Delivery App cho customer/driver và Operations Web cho support/admin.
- Không split repo thành `customer_app/`, `driver_app/`, `admin_web/`, hoặc `shared/`.
- Preferred design tokens cho UI mới/refactor: `AppColors`, `AppTextStyles`, `AppSpacing`, `AppRadius` trong `packages/giaohang_design/lib/src/app_theme.dart`.
- `NavColors` và `OrderColors` đang hỗ trợ UI hiện có. Không xóa hoặc migrate hàng loạt trong Phase 1.
- Phase 1 chỉ align tài liệu và checklist; không đổi runtime UI.

## Mô tả Project

Hệ thống có hai Flutter app: Delivery App dành cho Customer/Driver và Operations Web dành cho Support/Admin. Mỗi app có bootstrap, router và giao diện riêng nhưng cùng dùng design tokens và Supabase.

## Cấu trúc Project

```text
GiaoHang/
├── apps/
│   ├── delivery_app/       # Customer + Driver
│   └── operations_web/     # Support + Admin
├── packages/
│   ├── giaohang_config/
│   ├── giaohang_design/
│   └── giaohang_domain/
└── supabase/
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
flutter pub get                # Chạy tại root workspace
cd apps/delivery_app           # Customer + Driver
flutter analyze
flutter test
flutter build apk
cd ../operations_web           # Support + Admin
flutter analyze
flutter test
flutter build web
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
- **user_role**: customer, driver, support, admin
- **order_status**: pending, confirmed, assigned, picking_up, delivering, delivered, cancelled

### Bảng chính
- **users** — id (UUID), email (UNIQUE), full_name, phone, role (user_role), avatar_url, created_at
- **drivers** — id, user_id → users, vehicle_type, license_plate, vehicle_brand_model, vehicle_color, is_available, current_lat, current_lng, rating, total_deliveries, approval_status, verified_at, Phase B KYC columns, updated_at
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
- Dùng `AppColors`, `AppTextStyles`, `AppSpacing` từ `packages/giaohang_design/lib/src/app_theme.dart`
- Bắt buộc đọc `docs/design/visual_first_ui.md` cho quy tắc mật độ nội dung,
  hình minh họa, icon và yêu cầu riêng theo từng màn hình

---

## Design System

> **Aesthetic Direction**: _Clean Utility Premium_ — giao diện tối giản nhưng có chiều sâu. Thông tin phải đọc được ngay trong 1 giây. Cảm giác như Grab gặp Linear app.

---

### Color Palette

Tất cả màu định nghĩa trong `packages/giaohang_design/lib/src/app_theme.dart`:

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
  static const bgWarm      = Color(0xFFFFF7F1); // Chibi/visual header surface
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

### Visual hierarchy, icons và screen rules

Xem tài liệu bắt buộc:
[`docs/design/visual_first_ui.md`](docs/design/visual_first_ui.md).

### Customer Orders — Visual Order Hub

Màn Đơn hàng của khách hàng dùng pattern **visual order hub** để giảm chữ nhưng vẫn giữ
thông tin nghiệp vụ rõ ràng:

- Không lặp tiêu đề “Đơn hàng” và câu mô tả dài khi bottom navigation đã cho biết vị trí
  hiện tại. Dùng một visual header chibi không chứa text/logo; visual phải có
  `semanticLabel` và kích thước cố định để tránh layout shift.
- Trên mobile, visual chibi và control surface nằm **chung một hàng** trong toolbar cao
  128dp. Visual rộng 80–96dp theo available width; control surface dùng phần chiều rộng
  còn lại. Không xếp hai khối full-width theo chiều dọc vì sẽ đẩy danh sách đơn xuống thấp.
- Header chỉ có một hành động chính: nút icon tạo đơn tối thiểu 48×48dp, có tooltip,
  semantics và phản hồi nhấn. Không raster hoá CTA vào ảnh.
- Search và bộ lọc phải nằm trong một `bgCard` control surface riêng trên nền `bgLight`,
  có `AppColors.border`, `AppRadius.xl` và `AppShadow.subtle`. Input bên trong dùng nền
  `bgLight` để tạo ba lớp dễ đọc: screen → control surface → input.
- Toolbar compact dùng bốn filter icon-only 48dp; mọi mục bắt buộc có tooltip và
  semantic label. Trạng thái chọn dùng `accent`, không trộn thêm màu nhấn không cần thiết.
- Card đơn hàng luôn dùng `bgCard`, viền nhìn thấy rõ và shadow theo token. Không đặt
  card trắng không viền trên nền gần trắng.
- Mỗi card có status rail, status icon và nhãn ngắn; không dùng màu làm tín hiệu duy
  nhất. Route panel và recipient panel dùng `bgLight` + border để tách khỏi card.
- Điểm lấy dùng `markerPickup`, điểm giao dùng `markerDrop`. Địa chỉ được phép tối đa
  hai dòng; không rút gọn thông tin nghiệp vụ bắt buộc chỉ để giảm chữ.
- Giữ text cho mã đơn, trạng thái, địa chỉ, giá và người nhận. Loại các nhãn dư như
  “Chi tiết” khi toàn bộ card đã tappable; thay bằng chevron và semantic action.
- Hình chibi cho màn này dùng nền `bgWarm` (`#FFF7F1`), tông cam–trắng–be, không text,
  không logo, không mô phỏng control tương tác bên trong raster.

## Conventions
- File: snake_case.dart
- Class: PascalCase
- Mỗi feature có thư mục riêng trong features/
- Model có fromJson / toJson
- Không hardcode string
- Supabase URL và anon key trong supabase_constants.dart
- RLS bật cho tất cả bảng
- Không insert thủ công vào bảng users (trigger tự xử lý)
