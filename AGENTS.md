# DATN — Hệ thống Giao Hàng Thông Minh

## Architecture Decision

Project là **một monorepo với hai Flutter app** dùng chung Supabase và các package nền tảng:

- `apps/delivery_app`: Customer + Driver, phát hành Android/iOS.
- `apps/operations_web`: Support (CSKH) + Admin, phát hành Web.

Không tách thành nhiều repository và không sao chép models/design tokens giữa hai app.

## Mô tả Project
Ứng dụng giao hàng gồm 4 giao diện: khách hàng đặt đơn, tài xế nhận & giao hàng, Support (CSKH) tra cứu/xử lý yêu cầu, admin quản lý hệ thống. Tích hợp bản đồ thực tế và thuật toán tối ưu route giao hàng.

## Kiến trúc Hệ thống
```
GiaoHang/
├── apps/
│   ├── delivery_app/      # Customer + Driver, Android/iOS
│   └── operations_web/    # Support + Admin, Web
├── packages/
│   ├── giaohang_config/   # Runtime config dùng chung
│   ├── giaohang_design/   # Design tokens dùng chung
│   └── giaohang_domain/   # Domain models dùng chung
├── supabase/              # migrations và Edge Functions dùng chung
├── AGENTS.md
├── DESIGN.md
├── README.md
└── ROADMAP.md
```

## Tech Stack
- **Frontend**: Flutter (Dart) — đa nền tảng Android/iOS/Web
- **Backend**: Supabase (PostgreSQL + Realtime + Auth + Storage)
- **Bản đồ**: flutter_map + OpenStreetMap (tiles)
- **Routing API**: OSRM (Open Source Routing Machine) — miễn phí
- **Thuật toán**: VRP (Vehicle Routing Problem) / Nearest Neighbor + 2-opt
- **State Management**: Riverpod preferred. Không thêm Bloc nếu chưa có lý do rõ ràng.
- **Realtime**: Supabase Realtime (WebSocket) cho tracking tài xế

## Commands
```bash
flutter pub get                                      # Cài dependencies toàn workspace
cd apps/delivery_app                                 # Vào Delivery App
flutter analyze && flutter test && flutter run       # Analyze/test/chạy Customer/Driver
cd ../operations_web                                # Vào Operations Web
flutter analyze && flutter run -d chrome             # Analyze/chạy Support/Admin
flutter build web                                    # Build Operations Web
```

## Database Schema (Supabase)

### Bảng chính
- **users** — id, email, full_name, phone, role (customer/driver/support/admin), avatar_url, created_at
- **drivers** — id, user_id, vehicle_type, license_plate, vehicle_brand_model, vehicle_color, is_available, current_lat, current_lng, rating, total_deliveries, approval_status, verified_at, submitted_at, rejection_reason, KYC fields (id_card_*, driver_license_*, vehicle_photo_url), updated_at
- **orders** — id, customer_id, driver_id, status, pickup_address, pickup_lat, pickup_lng, delivery_address, delivery_lat, delivery_lng, total_price, note, created_at
- **order_items** — id, order_id, name, quantity, price
- **routes** — id, driver_id, date, optimized_path (JSONB), total_distance, total_duration, status
- **locations** — id, driver_id, lat, lng, timestamp (realtime tracking log)

### Enums
- order status: `pending` → `confirmed` → `assigned` → `picking_up` → `delivering` → `delivered` | `cancelled`
- driver status: `available`, `busy`, `offline`

## Tính năng theo Priority

### 🔴 Phase 1 — Core (Tháng 1-2)
- [ ] Auth: đăng ký / đăng nhập theo role
- [ ] Customer: đặt đơn hàng, chọn địa chỉ trên bản đồ
- [ ] Driver: xem danh sách đơn, nhận đơn
- [ ] Admin: xem danh sách đơn, quản lý tài xế
- [ ] flutter_map hiển thị bản đồ cơ bản

### 🟡 Phase 2 — Map & Routing (Tháng 3-4)
- [ ] Hiển thị route trên bản đồ (OSRM)
- [ ] Realtime tracking vị trí tài xế
- [ ] Customer: theo dõi đơn hàng trên bản đồ
- [ ] Driver: navigation từng bước
- [ ] Thuật toán phân công đơn tự động (nearest driver)

### 🟢 Phase 3 — Optimization (Tháng 5-6)
- [ ] Thuật toán VRP tối ưu route nhiều đơn / ngày
- [ ] Admin: dashboard thống kê, báo cáo
- [ ] Notification (đơn mới, trạng thái thay đổi)
- [ ] Rating tài xế
- [ ] Lịch sử đơn hàng
- [ ] Tối ưu hiệu năng, fix bugs, viết báo cáo

## Map & Routing Notes
- Dùng `flutter_map` package (không phải google_maps_flutter) — hỗ trợ Web + Android + iOS
- Tile server: `https://tile.openstreetmap.org/{z}/{x}/{y}.png`
- Routing: gọi OSRM public API `https://router.project-osrm.org/route/v1/driving/{coords}`
- Encode polyline từ OSRM response rồi vẽ lên bản đồ bằng `Polyline` layer
- Tài xế gửi vị trí lên Supabase mỗi 5 giây khi đang giao hàng

## Thuật toán VRP
- Input: danh sách đơn hàng (tọa độ), danh sách tài xế (vị trí hiện tại)
- Output: phân công tài xế → đơn hàng + thứ tự giao tối ưu
- Approach: Nearest Neighbor Heuristic → cải thiện bằng 2-opt
- Constraint: mỗi tài xế có capacity giới hạn, thời gian làm việc

## Supabase MCP
Project đã kết nối Supabase MCP — có thể dùng AI để:
- Tạo/sửa bảng trực tiếp
- Viết RLS policies
- Query data kiểm tra
- Tạo Edge Functions nếu cần

Quan trọng: không thay đổi Supabase schema, RLS policies, migrations, Edge Functions, hoặc database fields nếu chưa được hỏi và chấp thuận riêng.

## Conventions
- Đặt tên file: `snake_case.dart`
- Đặt tên class: `PascalCase`
- Mỗi feature có thư mục riêng: `features/orders/`, `features/map/`, `features/auth/`
- Model class có `fromJson` / `toJson`
- Không hardcode string — dùng constants
- Comment bằng tiếng Việt hoặc tiếng Anh đều được

## File Size / God File Rules

- Do not create God files.
- One screen file should mainly own `Scaffold`, top-level layout, navigation entry points, and provider wiring.
- Do not put all UI, state handling, dialogs, cards, formatters, filters, and actions into one screen file.
- Extract reusable UI into `widgets/` folders.
- Extract formatting/date/currency/status helpers into `utils/` folders.
- Extract dialogs into `dialogs/` folders or separate widget files.
- Extract filter/tab state helpers when they grow beyond trivial local state.
- Prefer files under 300-400 lines.
- Any file over 500 lines must be treated as a refactor candidate.
- Any file over 800 lines must not receive new features until it is split.
- Do not add new features into `apps/delivery_app/lib/features/customer/screens/tracking/tracking_screen.dart` or `apps/delivery_app/lib/features/customer/screens/order/order_screen.dart` until they are refactored.
- When implementing features, report if any touched file exceeds 400 lines.
- Before modifying a large file, propose a split plan first.

Recommended customer order structure:

```text
apps/delivery_app/lib/features/customer/screens/order/
├── order_screen.dart
├── widgets/
├── dialogs/
├── utils/
└── models/
```

Recommended customer tracking structure:

```text
apps/delivery_app/lib/features/customer/screens/tracking/
├── tracking_screen.dart
├── widgets/
├── dialogs/
├── utils/
└── models/
```

## Lưu ý quan trọng
- SDK constraint: `^3.9.0` (Dart 3.9.0 / Flutter 3.35.1)
- Min Android SDK: 21
- Supabase URL và anon key lưu trong `.env` — không commit lên Git
- RLS phải bật cho tất cả bảng trước khi deploy

Current runtime note: hai app đọc Supabase URL/anon key từ `packages/giaohang_config/lib/src/supabase_constants.dart`. Việc chuyển sang `.env` là cleanup riêng trong tương lai; không đổi runtime config trong Phase 1.


## UI Design Rules
- Luôn đọc DESIGN.md trước khi tạo hoặc sửa bất kỳ UI nào
- Mọi màn hình phải follow design system trong DESIGN.md
- Không dùng Material default widget thuần túy
- Áp dụng màu sắc, typography, spacing từ DESIGN.md
- Target: premium mobile app aesthetic

## Design Token Direction
- Preferred design system: `AppColors`, `AppTextStyles`, `AppSpacing`, `AppRadius` trong `packages/giaohang_design/lib/src/app_theme.dart`.
- `NavColors` và `OrderColors` đang tồn tại để hỗ trợ UI hiện có; không xóa hoặc migrate hàng loạt trong Phase 1.
- Khi tạo UI mới, ưu tiên token trong `app_theme.dart`.
