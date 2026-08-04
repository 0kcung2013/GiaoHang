# GiaoHang

Monorepo Flutter cho hệ thống giao hàng thông minh, gồm hai sản phẩm triển khai độc lập và dùng chung một backend Supabase.

- **Delivery App:** Customer đặt/theo dõi đơn; Driver nhận và giao đơn.
- **Operations Web:** Support xử lý yêu cầu CSKH; Admin quản lý đơn, tài xế và vận hành.

## Cấu trúc

```text
GiaoHang/
├── apps/
│   ├── delivery_app/       # Flutter Android/iOS — Customer + Driver
│   └── operations_web/     # Flutter Web — Support + Admin
├── packages/
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

Hai app có bootstrap và router riêng. Delivery App không chứa màn hình Admin/Support; Operations Web từ chối mặc định mọi role ngoài `admin` và `support`. Việc tách giao diện không thay thế RLS — Supabase vẫn là nơi quyết định quyền dữ liệu.

## Tech stack

- Flutter / Dart `^3.9.0`
- Supabase: PostgreSQL, Auth, Realtime, Storage, Edge Functions
- Riverpod cho state của Delivery App
- `go_router` cho navigation
- `flutter_map` + OpenStreetMap
- OSRM cho route và ETA

## Cài dependencies

Chạy tại repository root:

```bash
flutter pub get
```

Workspace chỉ có một `pubspec.lock` ở root.

## Delivery App

```bash
cd apps/delivery_app
flutter analyze
flutter test
flutter run
flutter build apk
```

Source chính:

- `apps/delivery_app/lib/features/customer/`
- `apps/delivery_app/lib/features/driver/`
- `apps/delivery_app/lib/core/router.dart`

Nếu Admin hoặc Support đăng nhập vào Delivery App, hệ thống chỉ hướng dẫn chuyển sang Operations Web.

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

- `giaohang_design`: nguồn duy nhất cho design tokens của cả hai app.
- `giaohang_domain`: model dùng ở cả Delivery và Operations; hiện bắt đầu với `DriverModel`.
- `giaohang_config`: runtime Supabase config dùng chung. Chuyển sang `.env` là cleanup riêng trong tương lai.

Chỉ đưa code vào package shared khi thực sự có ít nhất hai nơi sử dụng; không tạo repository/interface chung chỉ để dự đoán nhu cầu tương lai.

## Supabase

Migrations và Edge Functions nằm ở root để cả hai app dùng cùng nguồn dữ liệu:

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
