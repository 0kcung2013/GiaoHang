# ROADMAP — DATN Hệ thống Giao Hàng Thông Minh

> Architecture decision: giữ project là **một Flutter app duy nhất** cho 3 role customer, driver, admin. Không split repo thành nhiều app trong roadmap hiện tại.

> Safety rule: không thay đổi Supabase schema, RLS, migrations, Edge Functions, hoặc database fields nếu chưa có approval riêng.

## ✅ Đã hoàn thành
- [x] Cấu trúc project (1 project, 3 role)
- [x] Supabase database schema (6 bảng + RLS)
- [x] Trigger tự động tạo user khi đăng ký
- [x] Onboarding screen (3 slide premium UI)
- [x] Google OAuth login
- [x] Routing theo role (customer / driver / admin)
- [x] Placeholder home screen cho 3 role
- [x] Phase 1 cleanup documentation: single-app alignment, cleanup checklist, schema compatibility checklist

---

## 🧹 Cleanup Track

### Phase 1 — Safe cleanup
- [x] Align `AGENTS.md`, `README.md`, `ROADMAP.md`, and `DESIGN.md` around single-app architecture
- [x] Add `docs/CLEANUP_PLAN.md`
- [x] Mark empty folders and likely unused widget files without deleting
- [x] Document design token consolidation direction
- [x] Document Supabase schema compatibility checklist
- [x] Note future `.env` migration for Supabase URL/anon key without changing runtime config

### Phase 2 — UI/widget refactor
- [ ] Migrate one customer screen at a time toward `AppColors`, `AppTextStyles`, `AppSpacing`, `AppRadius`
- [ ] Extract repeated UI widgets only after checking current screen behavior
- [ ] Keep `NavColors` and `OrderColors` until each dependent screen is migrated and verified

### Phase 3 — State/data layer cleanup
- [ ] Verify live Supabase schema before changing service payloads
- [ ] Move customer-specific providers/services toward feature-owned data folders if needed
- [ ] Add focused tests for model parsing and order payload generation

### Phase 4 — Future feature readiness
- [ ] Add role-guarded feature routes carefully
- [ ] Prepare map/routing/realtime modules after UI/data cleanup

---

## 🔴 Phase 1 — Giao diện chính (Ưu tiên cao)

### Customer App
- [ ] **Customer Home Screen**
  - Thanh tìm kiếm địa chỉ giao hàng
  - Danh sách đơn hàng gần đây
  - Nút "Đặt hàng mới" nổi bật
  - Bottom navigation bar

- [ ] **Đặt đơn hàng**
  - Chọn địa chỉ lấy hàng trên bản đồ (flutter_map)
  - Chọn địa chỉ giao hàng
  - Nhập thông tin hàng hóa (tên, số lượng, giá)
  - Xem tóm tắt đơn + xác nhận

- [ ] **Màn hình theo dõi đơn**
  - Trạng thái đơn hàng (timeline)
  - Thông tin tài xế được assign
  - Bản đồ realtime vị trí tài xế

### Driver App
- [ ] **Driver Home Screen**
  - Toggle online/offline
  - Danh sách đơn hàng mới gần đây
  - Thông tin tổng hợp trong ngày

- [ ] **Nhận đơn hàng**
  - Xem chi tiết đơn (địa chỉ, hàng hóa)
  - Nút nhận/từ chối đơn
  - Xem route trên bản đồ (OSRM)

- [ ] **Navigation màn hình**
  - Bản đồ full screen
  - Chỉ đường từng bước (OSRM)
  - Cập nhật trạng thái đơn (picking_up → delivering → delivered)

### Admin App
- [ ] **Admin Home Screen**
  - Dashboard tổng quan (số đơn, tài xế online, doanh thu)
  - Quick actions

- [ ] **Quản lý đơn hàng**
  - Danh sách tất cả đơn + filter theo status
  - Xem chi tiết đơn
  - Assign tài xế thủ công

- [ ] **Quản lý tài xế**
  - Danh sách tài xế + trạng thái
  - Xem vị trí tài xế trên bản đồ

---

## 🟡 Phase 2 — Map & Realtime (Tháng 3-4)

- [ ] **flutter_map tích hợp hoàn chỉnh**
  - Hiển thị bản đồ OpenStreetMap
  - Marker điểm lấy hàng / giao hàng
  - Vẽ route polyline từ OSRM

- [ ] **Realtime tracking tài xế**
  - Driver gửi vị trí mỗi 5 giây lên Supabase
  - Customer thấy tài xế di chuyển trên bản đồ
  - Dùng Supabase Realtime (WebSocket)

- [ ] **OSRM Routing**
  - Gọi API OSRM tính route tối ưu
  - Parse và vẽ polyline lên bản đồ
  - Hiển thị thời gian + khoảng cách ước tính

- [ ] **Tự động assign tài xế**
  - Khi có đơn mới → tìm tài xế gần nhất (nearest neighbor)
  - Notify tài xế qua Supabase Realtime

---

## 🟢 Phase 3 — Thuật toán & Hoàn thiện (Tháng 5-6)

- [ ] **Thuật toán VRP (Vehicle Routing Problem)**
  - Input: nhiều đơn hàng + nhiều tài xế
  - Nearest Neighbor Heuristic
  - Cải thiện bằng 2-opt
  - Output: phân công tối ưu + thứ tự giao

- [ ] **Admin Dashboard nâng cao**
  - Biểu đồ doanh thu theo ngày/tuần/tháng
  - Bản đồ heat map vùng giao hàng nhiều
  - Thống kê hiệu suất tài xế

- [ ] **Notification**
  - Đơn mới → notify tài xế
  - Trạng thái thay đổi → notify khách hàng

- [ ] **Rating & Review**
  - Khách hàng đánh giá tài xế sau giao hàng
  - Hiển thị rating trên profile tài xế

- [ ] **Lịch sử đơn hàng**
  - Customer: xem lại đơn cũ, đặt lại
  - Driver: xem lịch sử giao hàng + thu nhập

- [ ] **Tối ưu & Hoàn thiện**
  - Fix bugs
  - Tối ưu performance
  - Viết báo cáo DATN

---

## 📋 Làm tiếp theo ngay bây giờ

**Bước tiếp theo được đề xuất:**

```
1. Phase 2 UI cleanup: chọn 1 màn hình customer để migrate token an toàn
2. Sau đó mới tích hợp flutter_map cơ bản
3. Sau đó hoàn thiện màn hình đặt đơn hàng với tọa độ thật
```

Prompt gợi ý cho bước tiếp:
```
Đọc AGENTS.md, DESIGN.md, và docs/CLEANUP_PLAN.md.
Refactor UI một màn hình customer sang AppColors/AppTextStyles/AppSpacing/AppRadius.
Không thay đổi runtime behavior hoặc Supabase schema.
```

---

## 🗂️ File quan trọng cần biết

| File | Mục đích |
|------|----------|
| `AGENTS.md` | Context project cho AI |
| `DESIGN.md` | Design system UI |
| `ROADMAP.md` | File này — theo dõi tiến độ |
| `docs/CLEANUP_PLAN.md` | Checklist cleanup và schema compatibility |
| `lib/core/router.dart` | Routing theo role |
| `lib/core/services/auth_service.dart` | Google OAuth |

---
