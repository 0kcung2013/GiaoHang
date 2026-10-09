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
│   ├── giaohang_domain/   # Domain models dùng chung
│   └── giaohang_storage/  # R2 client và object reference dùng chung
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
- **case_messages** — hội thoại CSKH/báo cáo rủi ro và ghi chú nội bộ; mỗi dòng thuộc đúng một `ticket_id` hoặc `risk_report_id`, phân quyền theo `visibility`.
- **risk_report_evidence** — bằng chứng báo cáo rủi ro: ảnh (`photo`), vị trí (`location`) hoặc bản chụp tin nhắn đơn hàng (`message`). File ảnh nằm trên R2; bảng giữ tham chiếu và dữ liệu nghiệp vụ.
- `driver_locations` đã được xóa ngày 2026-10-09 sau khi xác nhận toàn bộ GPS cũ quá 14 ngày. Không tạo lại bảng hoặc dùng làm fallback.

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

## Database Change Rules

- Ưu tiên tái sử dụng bảng, cột, RPC, view và luồng dữ liệu hiện có trước khi đề xuất cấu trúc mới.
- Không tạo bảng mới chỉ để phục vụ một màn hình, tab hoặc trạng thái UI.
- Chỉ đề xuất bảng mới khi dữ liệu thực sự có vòng đời, quan hệ, quyền truy cập hoặc yêu cầu audit độc lập mà các bảng hiện có không đáp ứng hợp lý.
- Trước khi tạo bảng mới, phải nêu rõ vì sao không thể mở rộng hoặc tái sử dụng cấu trúc hiện tại.
- Không bổ sung database hoặc dịch vụ lưu trữ thứ hai nếu chưa có số liệu dung lượng/hiệu năng chứng minh là cần thiết và chưa được chấp thuận riêng.

## Delivery Monitoring / Violation Scope

- Điểm vi phạm chỉ có hiệu lực trong 14 ngày (2 tuần) tính từ thời điểm phát sinh.
- Đánh giá xấu tạo điểm chờ xác minh; không tự động kết luận lỗi tài xế hoặc tự động khóa tài khoản từ đánh giá.
- Ngoại lệ giao muộn được người dùng duyệt ngày 2026-10-02: 3 đơn hoàn tất quá hạn trong 2 giờ gần nhất tự khóa nhận đơn mới 30 phút. Dùng hạn do backend cấp, giờ server và nhật ký hiện có; mỗi đơn tính một lần và không dùng lại các đơn đã kích hoạt khóa. Không khóa tài khoản đăng nhập hoặc gián đoạn đơn đang giao. Đây là cửa sổ riêng 2 giờ, không dùng cửa sổ điểm vi phạm 14 ngày.
- Việc xác nhận, miễn hoặc điều chỉnh điểm thuộc quyền CSKH/Admin và phải có audit trail.
- Phạm vi hiện tại không thu thập dữ liệu để huấn luyện lại LightGBM. Việc xây dựng dataset và retrain mô hình là hướng phát triển trong tương lai.
- Trong phạm vi hiện tại, lịch sử GPS chỉ được lưu để phát lại hành trình, đối chiếu sự cố và lập báo cáo khi cần.

### GPS Storage Architecture

- Supabase chỉ giữ dữ liệu nghiệp vụ và vị trí mới nhất trong `drivers`; không ghi thêm lịch sử GPS mới vào PostgreSQL/Supabase Storage.
- Lịch sử GPS chính được đóng gói theo `order_id` và lưu trong Cloudflare R2 ở định dạng nén, với object key xác định được từ mã đơn để không cần thêm bảng metadata chỉ nhằm lưu đường dẫn file.
- Không upload một object cho từng điểm GPS. Phải buffer rồi ghi theo chunk hoặc ghi một file hoàn chỉnh khi kết thúc đơn để giảm số thao tác lưu trữ.
- Object GPS mặc định hết hạn sau 14 ngày bằng lifecycle rule. Không giữ dữ liệu quá hạn chỉ để phục vụ huấn luyện mô hình.
- `driver_locations` đã được loại bỏ; không dùng PostgreSQL làm fallback ghi lịch sử mới khi R2 không khả dụng.
- R2 access key/secret chỉ tồn tại ở server-side worker/function secrets, không đưa xuống Flutter client và không commit vào Git.
- Việc tạo Cloudflare account, bucket, Worker, secrets hoặc thay đổi pipeline GPS cần được hỏi và chấp thuận riêng trước khi thực hiện.

### Image / Media Storage Architecture

- Ảnh upload mới (ảnh hàng hóa, bằng chứng giao/nhận/trả hàng, bằng chứng báo cáo rủi ro, avatar, KYC và hồ sơ thay đổi tài xế) ưu tiên lưu trên Cloudflare R2 thay vì Supabase Storage.
- Dùng bucket private; không bật public `r2.dev` cho ảnh nghiệp vụ hoặc KYC. Client chỉ upload/download bằng presigned URL có thời hạn ngắn do server-side Worker cấp sau khi kiểm tra Supabase JWT và quyền trên đối tượng nghiệp vụ.
- Tái sử dụng các cột URL/path hiện có bằng cách lưu object key hoặc URI ổn định dạng `r2://bucket/key`; không lưu presigned URL hết hạn vào database và không tạo bảng metadata mới nếu chưa thực sự cần.
- Phân tách prefix theo loại dữ liệu và chủ sở hữu, ví dụ `orders/{order_id}/cargo/`, `orders/{order_id}/proofs/`, `risk-reports/{report_id}/`, `drivers/{driver_id}/kyc/` và `users/{user_id}/avatars/`.
- Giới hạn MIME type, dung lượng và số lượng ảnh theo từng loại; ưu tiên chuyển ảnh thông thường sang WebP trước khi upload nhưng không làm giảm chất lượng tài liệu KYC đến mức khó xác minh.
- Ảnh cũ trong Supabase Storage vẫn phải đọc được trong giai đoạn chuyển đổi. Không xóa hoặc di chuyển hàng loạt khi chưa có migration plan, kiểm tra đối soát và chấp thuận riêng.
- Retention 14 ngày chỉ áp dụng cho GPS. Thời hạn lưu ảnh KYC, bằng chứng giao hàng và bằng chứng khiếu nại phải được xác định riêng theo nghiệp vụ; không tự động xóa theo lifecycle của GPS.
- Việc tạo R2 media bucket, Worker cấp presigned URL, secrets hoặc migration file ảnh cần được hỏi và chấp thuận riêng trước khi thực hiện.

## Conventions
- Đặt tên file: `snake_case.dart`
- Đặt tên class: `PascalCase`
- Mỗi feature có thư mục riêng: `features/orders/`, `features/map/`, `features/auth/`
- Model class có `fromJson` / `toJson`
- Không hardcode string — dùng constants
- Comment bằng tiếng Việt hoặc tiếng Anh đều được

## File Responsibility / God File Rules

- Do not create God files.
- One screen file should mainly own `Scaffold`, top-level layout, navigation entry points, and provider wiring.
- Do not put all UI, state handling, dialogs, cards, formatters, filters, and actions into one screen file.
- Extract reusable UI into `widgets/` folders.
- Extract formatting/date/currency/status helpers into `utils/` folders.
- Extract dialogs into `dialogs/` folders or separate widget files.
- Extract filter/tab state helpers when they grow beyond trivial local state.
- Không để một file chứa quá nhiều phần độc lập như UI, state orchestration, dialogs, data access, formatters và business rules không liên quan chặt chẽ.
- Chỉ đề xuất tách file khi thay đổi làm xuất hiện thêm trách nhiệm độc lập, làm giảm tính kết dính hoặc khiến việc kiểm thử/bảo trì khó khăn.
- Trước khi mở rộng một file, kiểm tra trách nhiệm hiện có; nếu cần tách thì chọn ranh giới nghiệp vụ hoặc component có ý nghĩa.

## Verification / Test Scope

- Chỉ chạy test và analyze tập trung cho feature, package hoặc file vừa sửa.
- Không chạy toàn bộ test suite, build toàn app, hoặc kiểm tra end-to-end sau mỗi thay đổi nhỏ.
- Gộp các thay đổi liên quan rồi mới chạy một lượt kiểm tra tập trung để tránh lặp lại thời gian khởi động Flutter.
- Chỉ chạy full test suite hoặc build phát hành khi người dùng yêu cầu rõ, hoặc khi thay đổi có ảnh hưởng xuyên toàn hệ thống; nếu cần, báo trước lý do.
- Khi báo cáo kết quả, nêu rõ những test đã chạy và phần nào chưa chạy.

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
- For every UI audit, design, prototype, review, or implementation in either
  Flutter app, use the project skill
  .agents/skills/giaohang-flutter-ui/SKILL.md.
- Luôn đọc DESIGN.md trước khi tạo hoặc sửa bất kỳ UI nào
- Mọi màn hình phải follow design system trong DESIGN.md
- Không dùng Material default widget thuần túy
- Áp dụng màu sắc, typography, spacing từ DESIGN.md
- Target: premium mobile app aesthetic
- giaohang-flutter-ui defines the required workflow. DESIGN.md and the compiled
  tokens in packages/giaohang_design/lib/src/app_theme.dart remain the design
  source of truth.
- Khi thiết kế lại một màn hình, kiểm tra luồng và trạng thái thực tế trong code; giữ nguyên hành vi, validation, điều hướng và hợp đồng dữ liệu trừ khi người dùng yêu cầu đổi.
- Đánh giá UI theo vai trò và thiết bị đích: nội dung dễ hiểu, trạng thái đầy đủ, hỗ trợ accessibility, bố cục thích ứng và motion có mục đích. Kiểm tra màn hình được render khi môi trường cho phép.
- ui-ux-pro-max is optional research support, not a source of project rules.
  Do not route ordinary Flutter work through the web-specific ui-styling
  workflow.

## Design Token Direction
- Preferred design system: `AppColors`, `AppTextStyles`, `AppSpacing`, `AppRadius` trong `packages/giaohang_design/lib/src/app_theme.dart`.
- `NavColors` và `OrderColors` đang tồn tại để hỗ trợ UI hiện có; không xóa hoặc migrate hàng loạt trong Phase 1.
- Khi tạo UI mới, ưu tiên token trong `app_theme.dart`.
