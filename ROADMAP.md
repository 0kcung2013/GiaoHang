# ROADMAP — DATN Hệ thống Giao Hàng Thông Minh

## ✅ Đã hoàn thành
- [x] Cấu trúc project (1 project, 3 role)
- [x] Supabase database schema (6 bảng + RLS)
- [x] Trigger tự động tạo user khi đăng ký
- [x] Onboarding screen (3 slide premium UI)
- [x] Google OAuth login
- [x] Routing theo role (customer / driver / admin)
- [x] Placeholder home screen cho 3 role

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
1. Thiết kế Customer Home Screen
2. Tích hợp flutter_map cơ bản
3. Màn hình đặt đơn hàng
```

Prompt gợi ý cho bước tiếp:
```
Đọc AGENTS.md và DESIGN.md, tạo Customer Home Screen 
tại lib/features/customer/screens/customer_home_screen.dart
```

---

## 🗂️ File quan trọng cần biết

| File | Mục đích |
|------|----------|
| `AGENTS.md` | Context project cho AI |
| `DESIGN.md` | Design system UI |
| `ROADMAP.md` | File này — theo dõi tiến độ |
| `prompt.md` | Paste prompt dài để AI đọc |
| `lib/core/router.dart` | Routing theo role |
| `lib/core/services/auth_service.dart` | Google OAuth |

---

## 💡 Workflow làm việc với OpenCode

```
1. Mở OpenCode trong thư mục project_app
2. Paste prompt vào prompt.md
3. Gõ: đọc prompt.md và làm theo
4. Kiểm tra kết quả
5. Cập nhật ROADMAP.md tick những việc đã xong
```
