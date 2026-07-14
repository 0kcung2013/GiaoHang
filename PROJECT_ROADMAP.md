# PROJECT ROADMAP — DATN Giao Hàng Thông Minh

> Single source of truth. Cập nhật sau mỗi lần hoàn thành một phần.
> Luôn đọc file này trước khi bắt đầu làm việc.

## Trạng thái hiện tại (2026-07-12)

**Đã hoàn thành:** Bước 1-3, Bước 4.1-4.3, Auto-assign driver

---

## Mục tiêu dự án

Xây dựng ứng dụng giao hàng đa vai trò (khách hàng, tài xế, admin) với bản đồ thực tế, realtime tracking và thuật toán tối ưu route. Đây là đồ án tốt nghiệp, ưu tiên hoàn thành, ổn định, kiến trúc sạch, dễ bảo trì.

---

## Kiến trúc tổng quan

```
Flutter (Dart)
    ↓
Riverpod (State Management)
    ↓
Supabase (Backend: Auth, DB, Realtime, Storage)
    ↓
Flutter Map + OpenStreetMap (Bản đồ)
    ↓
Geolocator (GPS)
    ↓
PostGIS (Tìm tài xế gần nhất)
    ↓
OSRM (Routing API)
```

## Công nghệ sử dụng

| Công nghệ | Mục đích | Ghi chú |
|-----------|----------|---------|
| Flutter 3.35+ | Frontend đa nền tảng | SDK ^3.9.0 |
| Riverpod 2.x | State management | Đã có, giữ nguyên |
| GoRouter 14.x | Navigation + role guard | Đã có, giữ nguyên |
| Supabase | Backend: Auth, DB, Realtime, Storage | Đã có, giữ nguyên |
| Flutter Map 7.x | Bản đồ | Đã có trong pubspec |
| OpenStreetMap | Tile map | Miễn phí, không cần key |
| Geolocator 13.x | GPS: lấy vị trí, theo dõi | Đã thêm |
| PostGIS | Tìm tài xế gần nhất | Đã bật extension |
| OSRM | Routing API | Miễn phí, public |
| http | HTTP client cho OSRM | Đã thêm |

## Database

**Đã có (8 bảng):**

- users — id, email, full_name, phone, role, avatar_url, created_at
- drivers — id, user_id, vehicle_type, license_plate, is_available, current_lat, current_lng, updated_at
- orders — id, customer_id, driver_id, status, pickup_address, pickup_lat, pickup_lng, delivery_address, delivery_lat, delivery_lng, total_price, note, created_at, tracking_code, ...
- order_items — id, order_id, name, quantity, price
- order_status_logs — id, order_id, status, title, description, logged_by, created_at
- notifications — id, user_id, title, body, type, is_read, order_id, created_at
- reviews — id, order_id, reviewer_id, driver_id, rating, comment, created_at
- saved_addresses — id, user_id, label, contact_name, contact_phone, address_line, lat, lng, is_default_pickup, is_default_delivery, created_at, updated_at

**Đã thêm (1 bảng + Extensions):**

- driver_locations — id, driver_id, lat, lng, heading, speed, is_active, created_at
- PostGIS extension (đã bật)
- Spatial index trên drivers (đã tạo)
- RLS policies cho driver_locations (đã tạo)
- RPC: find_nearest_drivers (đã tạo)

---

## Các module

### Authentication
- Trạng thái: ☑ Hoàn thành
- Auth ổn định, không cần sửa.

### Customer
- Trạng thái: 🔄 Đang làm (TrackingScreen map hoàn thành)
- Việc còn lại: CreateOrder map picker, DriverHomeScreen map

### Driver
- Trạng thái: ☑ Hoàn thành (cơ bản)
- Việc còn lại: Thêm map, navigation screen

### Admin
- Trạng thái: ☑ Hoàn thành
- Ổn định, chưa cần sửa.

### Orders
- Trạng thái: ☑ Hoàn thành
- Service hơi lớn (508 lines), refactor sau.

### GPS
- Trạng thái: ☑ Hoàn thành
- Checklist:
    ☑ Thêm package geolocator (13.0.4)
    ☑ Xin quyền GPS (whileInUse)
    ☑ Lấy vị trí hiện tại
    ☑ Theo dõi vị trí (5s + distanceFilter 10m)
    ☑ Update driver_location vào drivers table (UPDATE)
    ☑ Dừng khi không còn giao hàng
    ☑ Riverpod Provider cho location stream
- Files:
    - `lib/core/services/location_service.dart`
    - `lib/core/providers/location_providers.dart`
    - `lib/core/services/driver_service.dart` (đã thêm updateLocation, insertHistoryPoint, getLastLocation)
    - `lib/core/services/realtime_service.dart` (đã thêm subscribeToDriverLocation)

### Maps
- Trạng thái: 🔄 Đang làm (4.1 hoàn thành)
- Checklist:
    ☑ OSRM service + polyline decoder
    ☑ TrackingScreen map (FlutterMap + markers + polyline + realtime)
    ☑ Refactor: tách map code riêng (tracking_map.dart, marker_icon.dart)
    ☑ CreateOrder map picker (MapPickerSheet + Nominatim reverse geocoding)
    ☐ DriverHomeScreen map
- Files:
    - `lib/core/services/osrm_service.dart`
    - `lib/core/utils/polyline_decoder.dart`
    - `lib/features/customer/screens/tracking/widgets/tracking_map.dart` [MỚI]
    - `lib/features/customer/screens/tracking/widgets/marker_icon.dart` [MỚI]

### Realtime
- Trạng thái: 🔄 Đang làm
- Checklist:
    ☑ Driver location Realtime channel (Postgres Changes: drivers UPDATE)
    ☐ Tích hợp channel vào TrackingScreen (customer)
    ☐ Tích hợp channel vào DriverHomeScreen
- Ghi chú: RealtimeService đã có subscribeToDriverLocation method.

### Routing (OSRM)
- Trạng thái: ☑ Hoàn thành
- Checklist:
    ☑ Tạo OSRM service
    ☑ Decode polyline
    ☑ Tính khoảng cách + thời gian ước tính
    ☐ Vẽ polyline lên Flutter Map (cần map widget trong screen)

### Tìm tài xế gần nhất
- Trạng thái: ☑ Hoàn thành
- Checklist:
    ☑ Bật PostGIS extension
    ☑ Spatial index cho drivers
    ☑ RPC: find_nearest_drivers (ST_DWithin + ST_Distance + ORDER BY + LIMIT)
    ☐ Gọi RPC khi customer tạo đơn (tích hợp vào create_order flow)

### Notification
- Trạng thái: ☑ Hoàn thành

---

## Lộ trình triển khai

### Phase 1 — Core (Đã hoàn thành)
- [x] Onboarding + Auth + Customer/Driver/Admin screens
- [x] Order CRUD + status machine + RLS policies
- [x] Design system

### Phase 2 — GPS & Map (Đang thực hiện)
- [x] GPS: permission + location + tracking + update Supabase
- [x] OSRM: routing service + polyline decoder
- [x] PostGIS: extension + spatial index + find_nearest_drivers RPC
- [x] Realtime: driver location subscription
- [x] TrackingScreen: FlutterMap + marker driver/pickup/delivery + polyline route
- [x] CreateOrder map picker
- [ ] DriverHomeScreen map
- [x] Gọi find_nearest_drivers trong flow create order

### Phase 3 — Optimization (Sau này)
- [ ] Thuật toán VRP
- [ ] Admin dashboard nâng cao
- [ ] Push notification
- [ ] Rating tài xế
- [ ] Lịch sử đơn hàng

---

## File structure (thay đổi trong Phase 2)

```
lib/core/
├── models/
│   └── driver_location_model.dart        [MỚI]
├── services/
│   ├── driver_service.dart               [SỬA: +updateLocation, +insertHistoryPoint, +getLastLocation]
│   ├── location_service.dart             [MỚI]
│   ├── osrm_service.dart                 [MỚI]
│   └── realtime_service.dart             [SỬA: +subscribeToDriverLocation]
├── providers/
│   ├── customer_providers.dart            [KHÔNG SỬA]
│   └── location_providers.dart           [MỚI]
└── utils/
    └── polyline_decoder.dart             [MỚI]

supabase/migrations/
├── enable_postgis_extension              [MỚI]
├── add_drivers_spatial_index             [MỚI]
├── create_driver_locations_table         [MỚI]
├── create_find_nearest_drivers_rpc       [MỚI]
└── add_driver_locations_rls_policies     [MỚI]

pubspec.yaml                               [SỬA: +geolocator, +http]
```

## Quy tắc làm việc

1. Luôn đọc PROJECT_ROADMAP.md trước khi bắt đầu.
2. Cập nhật file này sau mỗi lần hoàn thành một phần.
3. Nếu thay đổi ảnh hưởng >10 file hoặc database schema → dừng và hỏi.
4. Ưu tiên refactor, không viết lại từ đầu.
5. Giữ nguyên kiến trúc hiện tại (Riverpod, GoRouter, Supabase).
