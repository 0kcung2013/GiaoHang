# DATN — Hệ thống Giao Hàng Thông Minh

## Mô tả Project
Ứng dụng giao hàng gồm 3 giao diện: khách hàng đặt đơn, tài xế nhận & giao hàng, admin quản lý hệ thống. Tích hợp bản đồ thực tế và thuật toán tối ưu route giao hàng.

## Kiến trúc Hệ thống
```
DATN/
├── customer_app/     # Flutter mobile - Khách hàng đặt hàng
├── driver_app/       # Flutter mobile - Tài xế nhận & giao đơn
├── admin_web/        # Flutter web - Quản trị hệ thống
└── shared/           # Shared models, constants, utils dùng chung
```

## Tech Stack
- **Frontend**: Flutter (Dart) — đa nền tảng Android/iOS/Web
- **Backend**: Supabase (PostgreSQL + Realtime + Auth + Storage)
- **Bản đồ**: flutter_map + OpenStreetMap (tiles)
- **Routing API**: OSRM (Open Source Routing Machine) — miễn phí
- **Thuật toán**: VRP (Vehicle Routing Problem) / Nearest Neighbor + 2-opt
- **State Management**: Riverpod hoặc Bloc
- **Realtime**: Supabase Realtime (WebSocket) cho tracking tài xế

## Commands
```bash
flutter run                          # Chạy app
flutter test                         # Chạy tất cả tests
flutter analyze                      # Static analysis
flutter pub get                      # Cài dependencies
flutter build apk                    # Build Android
flutter build web                    # Build web (admin)
```

## Database Schema (Supabase)

### Bảng chính
- **users** — id, email, full_name, phone, role (customer/driver/admin), avatar_url, created_at
- **drivers** — id, user_id, vehicle_type, license_plate, is_available, current_lat, current_lng, updated_at
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

## Conventions
- Đặt tên file: `snake_case.dart`
- Đặt tên class: `PascalCase`
- Mỗi feature có thư mục riêng: `features/orders/`, `features/map/`, `features/auth/`
- Model class có `fromJson` / `toJson`
- Không hardcode string — dùng constants
- Comment bằng tiếng Việt hoặc tiếng Anh đều được

## Lưu ý quan trọng
- SDK constraint: `>=3.0.0 <4.0.0`
- Min Android SDK: 21
- Supabase URL và anon key lưu trong `.env` — không commit lên Git
- RLS phải bật cho tất cả bảng trước khi deploy


Đọc AGENTS.md, sau đó cập nhật file AGENTS.md:
Thêm section mới tên "## UI Design Rules" với nội dung:

- Luôn đọc DESIGN.md trước khi tạo hoặc sửa bất kỳ UI nào
- Mọi màn hình phải follow design system trong DESIGN.md
- Không dùng Material default widget thuần túy
- Áp dụng màu sắc, typography, spacing từ DESIGN.md
- Target: premium mobile app aesthetic