# GiaoHang

Monorepo Flutter cho hệ thống giao hàng thông minh, gồm ba sản phẩm triển khai độc lập và dùng chung một backend Supabase.

- **Customer App:** khách hàng đặt và theo dõi đơn.
- **Driver App:** tài xế đăng ký KYC, nhận và giao/hoàn đơn.
- **Operations Web:** Support xử lý yêu cầu CSKH; Admin quản lý đơn, tài xế và vận hành.

## Cấu trúc

```text
GiaoHang/
├── apps/
│   ├── customer_app/       # Flutter Android/iOS — Customer
│   ├── driver_app/         # Flutter Android/iOS — Driver
│   └── operations_web/     # Flutter Web — Support + Admin
├── packages/
│   ├── giaohang_mobile/   # Nghiệp vụ, UI, assets dùng chung hai app mobile
│   ├── giaohang_config/    # Supabase runtime config dùng chung
│   ├── giaohang_design/    # AppColors, typography, spacing, radius
│   └── giaohang_domain/    # Domain models dùng chung
├── supabase/
│   ├── migrations/
│   └── functions/
├── docs/
├── AGENTS.md
├── DESIGN.md
├── ROADMAP.md
└── pubspec.yaml            # Dart/Flutter workspace
```

Ba app có entry point riêng. Hai app mobile cố định role và bảng route theo app; Operations Web từ chối mặc định mọi role ngoài `admin` và `support`. Việc tách giao diện không thay thế RLS — Supabase vẫn là nơi quyết định quyền dữ liệu.

## Tech stack

- Flutter / Dart `^3.9.0`
- Supabase: PostgreSQL, Auth, Realtime, Storage, Edge Functions
- Riverpod cho state của Delivery App
- `go_router` cho navigation
- `flutter_map` + OpenStreetMap
- OSRM cho route và ETA

Phân công tự động xếp tài xế theo độ dài tuyến OSRM đến điểm lấy hàng trong 2 km.
FreePick dùng quãng đường trên 2 đến 3 km. Khi routing lỗi, đơn chờ thử lại.
Chi tiết luồng backend và kiểm thử: [Phân công theo quãng đường](supabase/functions/README_ROAD_DISPATCH.md).

## Dữ liệu AI

Pipeline demo mới dùng LightGBM dự đoán ETA toàn tuyến từ dữ liệu mô phỏng trên
đường Việt Nam. Dataset chính nằm ở `output/eta_simulation/simulated_trips.csv`;
model app ở `packages/giaohang_mobile/assets/ml/eta_simulation_model.json`;
mã tạo dữ liệu và huấn luyện ở `experiments/eta_simulation/`.
Đã tích hợp Flutter và triển khai server: `accept-driver-order` v10,
`refresh-order-eta` v8. Hai phía dùng cùng model; profile v2 phân bổ phần chờ
gần giao lộ/chỗ rẽ. ETA đơn đã nhận được giữ nguyên.
Xem [kết quả và phạm vi ETA mô phỏng](docs/ETA_MO_PHONG_LIGHTGBM.md).
UTraffic được giữ để đối chiếu lịch sử.

Xem [bản đồ thư mục dữ liệu và mô hình](experiments/README.md) để tìm đúng file.

## Cài dependencies

Chạy tại repository root:

```bash
flutter pub get
```

Workspace chỉ có một `pubspec.lock` ở root.

Phân loại khách hàng và phí sàn thực thu cho Customer/Driver, cấu hình Admin,
setup backend/callback/secrets và đối soát: [Tài liệu bàn giao phí sàn](docs/handoff/platform_fee_collection.md).

## Customer App và Driver App

```bash
cd apps/customer_app  # hoặc apps/driver_app từ repository root
flutter analyze
flutter test
flutter run
flutter build apk
```

Source chính:

- `packages/giaohang_mobile/lib/features/customer/`
- `packages/giaohang_mobile/lib/features/driver/`
- `packages/giaohang_mobile/lib/core/router.dart`

Mỗi app chỉ cho phép tài khoản đúng vai trò. Không có lựa chọn chuyển vai trò trên trang đăng nhập/đăng ký.

Chạy thử trên trình duyệt bằng `flutter run -d chrome` tại thư mục app tương ứng.
Customer và Driver tự hiển thị bên trong mẫu điện thoại iPhone 13 có thân máy,
tai thỏ và vùng an toàn. Màn hình app luôn là 390×844dp; cả chiếc điện thoại
thu phóng để vừa cửa sổ trình duyệt, kể cả cửa sổ hẹp. Dialog và bottom sheet
cũng nằm trong màn hình điện thoại. Android/iOS dùng kích thước thiết bị thực tế.

Kiểm thử nghiệp vụ dùng chung: `cd packages/giaohang_mobile` rồi `flutter test`.
Chi tiết cấu hình, callback và chạy hai app: [Tách app mobile](docs/mobile_apps.md).

## Operations Web

```bash
cd apps/operations_web
flutter analyze
flutter run -d chrome
flutter build web
```

Source chính:

- `apps/operations_web/lib/features/admin/`
- `apps/operations_web/lib/features/support/`
- `apps/operations_web/lib/router.dart`

Operations Web không cung cấp đăng ký công khai. Tài khoản Support phải được Admin tạo qua luồng backend an toàn.

## Shared packages

- `giaohang_design`: nguồn duy nhất cho design tokens của các app.
- `giaohang_domain`: model dùng ở cả Delivery và Operations; hiện bắt đầu với `DriverModel`.
- `giaohang_config`: runtime Supabase config dùng chung. Chuyển sang `.env` là cleanup riêng trong tương lai.

Chỉ đưa code vào package shared khi thực sự có ít nhất hai nơi sử dụng; không tạo repository/interface chung chỉ để dự đoán nhu cầu tương lai.

## Supabase

Sau đợt gộp ngày 2026-10-09, schema `public` có 24 bảng nghiệp vụ.
`case_messages` lưu hội thoại yêu cầu hỗ trợ, báo cáo rủi ro và ghi chú nội bộ;
`risk_report_evidence` lưu bằng chứng ảnh, vị trí và bản chụp tin nhắn.
Lịch sử GPS cũ trong `driver_locations` đã được loại bỏ; lịch sử mới nằm trên R2.
Chi tiết: [Gộp bảng CSKH và bằng chứng](docs/DATABASE_CONSOLIDATION.md).

Migrations và Edge Functions nằm ở root để các app dùng cùng nguồn dữ liệu:

```text
supabase/migrations/
supabase/functions/
```

Không thay đổi schema, RLS hoặc Edge Functions nếu chưa có phê duyệt riêng. Mọi role guard phía Flutter phải được củng cố bằng RLS/RPC phía Supabase.

## Thiết kế UI

Đọc `DESIGN.md` trước khi sửa UI. Design tokens nằm tại:

```text
packages/giaohang_design/lib/src/app_theme.dart
```

`NavColors` và `OrderColors` cũ vẫn được giữ trong Phase 1; không migrate hàng loạt khi chưa cần.

## Tài liệu

- `AGENTS.md`: kiến trúc và quy tắc làm việc.
- `DESIGN.md`: design system.
- `ROADMAP.md`: thứ tự ưu tiên nghiệp vụ.
- `docs/PROJECT_GUARDRAILS.md`: guardrails dài hạn.
