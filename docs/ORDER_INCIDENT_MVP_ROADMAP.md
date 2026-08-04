# Roadmap MVP — Sự cố đơn hàng và hoàn hàng

> Cập nhật: 2026-08-01
> Trạng thái: Phân tích và phạm vi MVP đã được chấp nhận; chưa triển khai code, chưa tạo migration, chưa thay đổi Supabase remote.
> Mục đích: tài liệu handoff cho phiên Codex mới thực hiện tuần tự từng bước.

## 1. Cách bắt đầu ở phiên mới

Agent mới phải thực hiện theo thứ tự:

1. Đọc toàn bộ `AGENTS.md`.
2. Đọc toàn bộ `DESIGN.md` và `docs/design/visual_first_ui.md` trước khi sửa UI.
3. Đọc toàn bộ file roadmap này.
4. Kiểm tra `git status --short`; working tree hiện có thay đổi lớn từ quá trình tách monorepo, không được hoàn tác hoặc ghi đè thay đổi của người dùng.
5. Dùng skill `supabase` trước mọi công việc liên quan schema, RPC, RLS hoặc Storage.
6. Kiểm tra Supabase CLI bằng `supabase --help`, `supabase migration --help`, `supabase test --help`; không đoán cú pháp CLI.
7. Chỉ thực hiện một bước roadmap tại một thời điểm, chạy kiểm thử tương ứng rồi cập nhật checklist trong file này.
8. Không apply migration lên Supabase remote nếu chưa qua toàn bộ verification gate và chưa có xác nhận riêng của người dùng.

Prompt gợi ý cho phiên mới:

```text
Đọc AGENTS.md, DESIGN.md, docs/design/visual_first_ui.md và
docs/ORDER_INCIDENT_MVP_ROADMAP.md. Bắt đầu từ bước chưa hoàn thành đầu tiên.
Chỉ thực hiện đúng một bước nhỏ, kiểm thử, báo cáo kết quả và cập nhật checklist.
Không apply Supabase migration lên remote.
```

## 2. Kiến trúc hiện tại

Project là monorepo với hai Flutter app dùng chung Supabase và packages:

```text
GiaoHang/
├── apps/
│   ├── delivery_app/       # Customer + Driver, Android/iOS
│   └── operations_web/     # Support + Admin, Flutter Web
├── packages/
│   ├── giaohang_config/
│   ├── giaohang_design/
│   └── giaohang_domain/
└── supabase/
```

Các tài liệu nguồn sự thật:

- `AGENTS.md`: kiến trúc, conventions, giới hạn file size và quyền thay đổi Supabase.
- `DESIGN.md`: design tokens và hướng Clean Utility Premium.
- `docs/design/visual_first_ui.md`: mật độ nội dung, CTA, accessibility và responsive.
- `docs/adr/0001-split-delivery-and-operations-apps.md`: quyết định hai Flutter app.
- `ROADMAP.md`: roadmap tổng thể; có ghi nhận migrations chưa dựng được toàn bộ database từ đầu.

## 3. Phạm vi MVP đã khóa

### 3.1. Có triển khai

1. Driver báo cáo sự cố trong giai đoạn lấy hàng hoặc giao hàng.
2. Báo cáo gồm loại sự cố, mô tả ngắn và ảnh minh chứng khi cần.
3. Support tiếp nhận và bắt đầu review.
4. Support có thể:
   - bắt đầu chờ 15 phút;
   - cho tiếp tục giao;
   - cho phép hoàn;
   - từ chối incident.
5. Driver thực hiện `return_approved → returning → returned`.
6. Customer chỉ xem banner trạng thái incident trên tracking.
7. Countdown hết hạn không tự đổi order hoặc incident.
8. Quyết định tiếp tục/hoàn chỉ qua RPC do Support gọi.
9. Arrival vẫn là milestone riêng, không phải order status.

### 3.2. Không triển khai

- Chat Customer–Driver.
- Incident chat.
- Customer gửi incident.
- Hỗ trợ sau giao hàng.
- Compensation request.
- Chữ ký hoặc OTP người nhận.
- Inspection workflow.
- Audit UI phức tạp.
- Severity hoặc risk scoring.
- Chuyển đổi/xóa module `risk_reports`.
- Refactor diện rộng không trực tiếp phục vụ MVP.
- Cron, trigger hoặc Edge Function tự động hoàn khi countdown hết.

Module `apps/operations_web/lib/features/risk_reports/` và các bảng `risk_reports`, `risk_report_events` phải được giữ nguyên như legacy.

## 4. Quy tắc nghiệp vụ đã chốt

### 4.1. Role

Chỉ có:

```text
customer
driver
support
admin
```

Không tạo role `recipient`. Người nhận chỉ là dữ liệu của `orders`.

Trong MVP:

- Driver tạo incident.
- Support review và ra quyết định.
- Admin có thể đọc để giám sát nhưng không gọi RPC quyết định.
- Customer chỉ đọc trạng thái incident của đơn do mình tạo.

### 4.2. Ý nghĩa order status

```text
assigned       Driver đã nhận đơn.
picking_up     Driver đang thực hiện quá trình lấy hàng.
delivering     Driver đã nhận hàng và đang giao.
waiting_support Đơn tạm dừng theo quyết định Support.
return_approved Support đã cho phép hoàn.
returning      Driver đang hoàn hàng.
returned       Hoàn hàng hoàn tất.
```

Không dùng `picking_up` để biểu thị đã đến điểm lấy.

```text
pickup_arrived_at   Mốc đã đến điểm lấy.
delivery_arrived_at Mốc đã đến điểm giao.
```

### 4.3. Blocking incident

- `create_order_incident` tạo incident ở `submitted` và gán `orders.blocking_incident_id`.
- Order vẫn giữ `assigned`, `picking_up` hoặc `delivering` cho đến khi Support quyết định.
- Driver UI khóa CTA tiến trình khi `blocking_incident_id != null`, kể cả trước khi order sang `waiting_support`. Việc này ngăn race giữa Driver và Support.
- Chỉ `support_start_waiting` chuyển order sang `waiting_support`.
- `support_continue_delivery` và `support_reject_incident` giải phóng `blocking_incident_id`.
- `support_approve_return` giữ blocking incident cho đến khi hoàn tất return.

### 4.4. Countdown 15 phút

- Dùng database clock để ghi `wait_started_at` và `wait_deadline_at`.
- Client chỉ tính thời gian còn lại để hiển thị.
- Hết hạn hiển thị:

```text
Đã hết thời gian chờ. Vui lòng chờ CSKH quyết định.
```

- Không có DB trigger, cron, client timer hoặc Edge Function tự chuyển `return_approved`.
- Sau deadline, RPC Support vẫn là đường duy nhất cho tiếp tục hoặc hoàn.

## 5. Danh mục incident Driver

Không có severity. Mã incident là constants dùng chung; UI không hardcode rải rác.

### 5.1. Pickup phase

| Code | Nhãn |
|---|---|
| `pickup_sender_unreachable` | Không liên lạc được người gửi |
| `pickup_wrong_address` | Sai địa chỉ lấy hàng |
| `pickup_location_not_found` | Không tìm thấy điểm lấy |
| `pickup_item_mismatch` | Hàng không đúng mô tả |
| `pickup_oversized_or_overweight` | Hàng quá kích thước hoặc trọng lượng |
| `pickup_prohibited_or_dangerous` | Hàng có dấu hiệu nguy hiểm hoặc bị cấm |
| `pickup_sender_not_ready` | Người gửi chưa chuẩn bị hàng |
| `pickup_damaged_packaging` | Bao bì bị hỏng |
| `pickup_vehicle_issue` | Sự cố phương tiện |
| `pickup_unsafe_location` | Điểm lấy hàng không an toàn |

`assigned` và `picking_up` dùng danh mục pickup.

### 5.2. Delivery phase

| Code | Nhãn |
|---|---|
| `delivery_recipient_unreachable` | Không liên lạc được người nhận |
| `delivery_wrong_address` | Sai địa chỉ giao hàng |
| `delivery_location_not_found` | Không tìm thấy điểm giao |
| `delivery_recipient_absent` | Người nhận không có mặt |
| `delivery_recipient_refused` | Người nhận từ chối nhận hàng |
| `delivery_relocation_requested` | Người nhận yêu cầu giao sang địa điểm khác |
| `delivery_payment_dispute` | Tranh chấp thanh toán |
| `delivery_item_damaged` | Hàng bị hỏng hoặc vỡ |
| `delivery_missing_or_wrong_item` | Thiếu hàng hoặc sai hàng |
| `delivery_accident_or_breakdown` | Tai nạn hoặc hỏng xe |
| `delivery_unsafe_location` | Điểm giao không an toàn |

`delivering` dùng danh mục delivery.

### 5.3. Quy tắc ảnh

Ảnh bắt buộc cho các loại có thể xác minh trực quan, trừ khi việc chụp ảnh làm tăng rủi ro an toàn:

```text
pickup_item_mismatch
pickup_oversized_or_overweight
pickup_damaged_packaging
delivery_item_damaged
delivery_missing_or_wrong_item
```

Ảnh được khuyến nghị nhưng không bắt buộc cho hàng nguy hiểm, tai nạn hoặc địa điểm không an toàn. UI phải nhắc “Chỉ chụp ảnh khi an toàn”.

## 6. State machine MVP

### 6.1. Order

```text
Normal:
assigned → picking_up → delivering → delivered

Support waiting:
assigned | picking_up | delivering
  → waiting_support
  → resume_order_status

Return after waiting:
waiting_support
  → return_approved
  → returning
  → returned

Direct serious-case decision:
assigned | picking_up | delivering
  → return_approved
  → returning
  → returned
```

### 6.2. Incident

```text
submitted → under_review
submitted → rejected

under_review → waiting
under_review → continue_delivery
under_review → return_approved
under_review → rejected

waiting → continue_delivery
waiting → return_approved
waiting → rejected

return_approved → resolved       # khi confirm return thành công
```

Terminal/outcome states:

```text
continue_delivery
resolved
rejected
```

`continue_delivery` và `rejected` có `resolved_at` dù tên status không phải `resolved`. `resolved` dùng khi return hoàn tất.

## 7. Database MVP

### 7.1. Mở rộng `order_status`

Thêm đúng bốn giá trị:

```text
waiting_support
return_approved
returning
returned
```

Không thêm `risk`, `damaged` hoặc `incident`.

### 7.2. Thêm vào `orders`

```sql
pickup_arrived_at timestamptz null
delivery_arrived_at timestamptz null
blocking_incident_id uuid null
```

`blocking_incident_id` thêm foreign key sau khi bảng `order_incidents` đã tồn tại, `ON DELETE SET NULL`.

### 7.3. `order_incidents`

```text
id uuid primary key
order_id uuid not null references orders(id)
reporter_id uuid not null references users(id)
reporter_role user_role not null
incident_type text not null
incident_status text not null
phase_at_report text not null
order_status_at_report order_status not null
resume_order_status order_status null
description text null
assigned_to uuid null references users(id)
wait_started_at timestamptz null
wait_deadline_at timestamptz null
resolution_action text null
resolution_note text null
created_at timestamptz not null
updated_at timestamptz not null
resolved_at timestamptz null
```

Constraints:

- `reporter_role = 'driver'` trong MVP.
- Description trim, tối đa 1.000 ký tự.
- `phase_at_report IN ('pickup', 'delivery')`.
- Incident status chỉ gồm:

```text
submitted
under_review
waiting
continue_delivery
return_approved
resolved
rejected
```

- Partial unique index: một order chỉ có một blocking incident ở `submitted`, `under_review`, `waiting`, `return_approved`.

### 7.4. `incident_attachments`

```text
id uuid primary key
incident_id uuid not null references order_incidents(id) on delete cascade
uploaded_by uuid not null references users(id)
storage_path text not null unique
mime_type text not null
created_at timestamptz not null
```

### 7.5. `incident_events`

```text
id bigint generated always as identity primary key
incident_id uuid not null references order_incidents(id) on delete cascade
actor_id uuid null references users(id)
event_type text not null
from_incident_status text null
to_incident_status text not null
from_order_status order_status null
to_order_status order_status null
note text null
created_at timestamptz not null
```

Event types MVP:

```text
submitted
review_started
waiting_started
continue_delivery
return_approved
rejected
return_started
returned
```

Client không được insert/update/delete trực tiếp bảng này.

### 7.6. `order_returns`

```text
id uuid primary key
order_id uuid not null unique references orders(id)
incident_id uuid not null unique references order_incidents(id)
status text not null
reason text not null
destination_type text not null
destination_address text not null
approved_by uuid not null references users(id)
approved_at timestamptz not null
started_at timestamptz null
returned_at timestamptz null
created_at timestamptz not null
updated_at timestamptz not null
```

Return status:

```text
approved
returning
returned
```

Destination type:

```text
sender
processing_center
```

### 7.7. Storage

Private bucket:

```text
incident-evidence
```

Path:

```text
{order_id}/{incident_id}/{uploader_id}/{uuid}.{extension}
```

Không dùng public URL. Support dùng signed URL để xem ảnh.

## 8. Migrations cần tạo

Project dùng imperative migrations. Không tự đặt timestamp file. Trước khi tạo phải chạy `supabase migration new --help`, sau đó tạo theo thứ tự:

1. `supabase migration new add_order_incident_mvp_statuses`
   - Chỉ thêm bốn enum values.
   - Không dùng enum values mới trong cùng migration.

2. `supabase migration new create_order_incident_mvp_schema`
   - Thêm columns vào `orders`.
   - Tạo bốn bảng, constraints, foreign keys và indexes.
   - Tạo private bucket và Storage policies.
   - Bật RLS và grants tối thiểu ngay khi tạo bảng.
   - Cập nhật unique active-order index cho driver.

3. `supabase migration new create_order_incident_mvp_workflow`
   - Tạo tám RPC.
   - Revoke function execute khỏi `PUBLIC`.
   - Grant execute đúng role API.
   - Harden order update policies sau khi test compatibility.

Tuyệt đối không dùng Supabase MCP `apply_migration` để thử nghiệm local.

## 9. RPC contract MVP

### 9.1. Danh sách RPC

```text
create_order_incident
support_start_incident_review
support_start_waiting
support_continue_delivery
support_approve_return
support_reject_incident
start_order_return
confirm_order_return
```

### 9.2. Nguyên tắc chung

Mỗi RPC phải:

1. Bắt buộc `auth.uid()` khác null.
2. Đọc role từ `public.users`, không dùng `user_metadata` và không tin role client truyền.
3. Khóa row bằng `SELECT ... FOR UPDATE` theo thứ tự nhất quán: order → incident → return.
4. Kiểm tra actor liên quan đúng order.
5. Kiểm tra state transition hợp lệ.
6. Cập nhật order, incident, return atomically.
7. Insert đúng một `incident_event` cho action.
8. Dùng `clock_timestamp()`/database time cho deadline và timestamps.
9. Set `search_path` an toàn nếu dùng `SECURITY DEFINER`.
10. `REVOKE ALL ... FROM PUBLIC`, sau đó grant có chủ đích.
11. Không có nhánh tự động hoàn theo deadline.

### 9.3. Chữ ký dự kiến

```text
create_order_incident(
  p_order_id uuid,
  p_incident_type text,
  p_description text default null
)
```

Phase và reporter role do server suy ra:

```text
assigned | picking_up → pickup
delivering            → delivery
```

```text
support_start_incident_review(p_incident_id uuid)
support_start_waiting(p_incident_id uuid)
support_continue_delivery(p_incident_id uuid, p_resolution_note text default null)
support_approve_return(
  p_incident_id uuid,
  p_reason text,
  p_destination_type text,
  p_destination_address text,
  p_resolution_note text default null
)
support_reject_incident(p_incident_id uuid, p_resolution_note text)
start_order_return(p_order_id uuid)
confirm_order_return(p_order_id uuid)
```

### 9.4. Transition chi tiết

| RPC | Actor | From | To |
|---|---|---|---|
| `create_order_incident` | assigned Driver | active order/no blocking incident | incident `submitted`, order unchanged, blocking set |
| `support_start_incident_review` | Support | `submitted` | `under_review`, assigned_to set |
| `support_start_waiting` | assigned Support | incident `under_review`, active order | incident `waiting`, order `waiting_support`, resume/deadline set |
| `support_continue_delivery` | assigned Support | `under_review` hoặc `waiting` | incident `continue_delivery`, order current/resumed, blocking clear |
| `support_approve_return` | assigned Support | `under_review` hoặc `waiting` | incident/order `return_approved`, return row `approved` |
| `support_reject_incident` | Support | `submitted`, `under_review`, `waiting` | incident `rejected`, order current/resumed, blocking clear |
| `start_order_return` | assigned Driver | order `return_approved`, return `approved` | order/return `returning` |
| `confirm_order_return` | assigned Driver | order/return `returning` | order/return `returned`, incident `resolved` |

## 10. RLS và quyền truy cập

### 10.1. `order_incidents`

- Driver SELECT incident của order được phân công.
- Customer SELECT incident của order do mình tạo để render banner.
- Support/Admin SELECT mọi incident.
- Không role client nào UPDATE/DELETE trực tiếp.
- Insert nghiệp vụ chỉ qua `create_order_incident` RPC.

### 10.2. `incident_attachments`

- Driver reporter được insert/select attachment của incident mình tạo.
- Support/Admin được select.
- Customer không được select attachment trong MVP.
- Không update/delete trực tiếp trong MVP.

### 10.3. `incident_events`

- Support/Admin select.
- Có thể cho Driver/Customer select sau nếu UI cần; MVP không cần.
- Không client insert/update/delete.

### 10.4. `order_returns`

- Assigned Driver, order Customer, Support/Admin được select row liên quan.
- Không direct insert/update/delete; chỉ RPC.

### 10.5. `orders`

Live database từng phát hiện policy rộng `orders_update_related`. Bước migration workflow phải:

1. Kiểm tra lại live/local policies.
2. Xác minh code hiện tại dùng RPC cho cancel/progress/return.
3. Bỏ policy rộng nếu không còn dependency.
4. Giữ policy cụ thể cho claim order.
5. Nếu persist arrival bằng direct update, chỉ grant UPDATE hai arrival columns, RLS giới hạn assigned Driver và trigger ngăn sửa/xóa timestamp đã ghi.

Không được bỏ policy rộng trước khi test các flow nhận đơn, hủy đơn và tiến trình giao hiện tại.

## 11. SQL tests

Tạo:

```text
supabase/tests/order_incident_mvp_state_machine_test.sql
supabase/tests/order_incident_mvp_rls_test.sql
supabase/tests/order_incident_mvp_timeout_test.sql
```

Trước khi viết test phải kiểm tra cú pháp CLI hiện tại bằng `supabase test --help`.

### 11.1. State machine tests

- Driver tạo incident cho order của mình ở `assigned`, `picking_up`, `delivering`.
- Phase được server suy ra đúng.
- Invalid incident type/phase bị reject.
- Không tạo incident ở `delivered`, `cancelled`, `returning`, `returned`.
- Không tạo blocking incident thứ hai.
- Start review gán đúng Support.
- Start waiting lưu đúng `resume_order_status` và deadline gần 15 phút.
- Continue từ waiting phục hồi chính xác assigned/picking_up/delivering.
- Continue từ under_review không đổi active order status.
- Reject từ waiting phục hồi status và clear blocking.
- Approve return từ active và waiting tạo đúng `order_returns`.
- Start/confirm return cập nhật ba aggregate atomically.
- Invalid transition không tạo event và rollback toàn bộ.

### 11.2. Authorization/RLS tests

- Unauthenticated không gọi được RPC.
- Customer, Driver khác, Admin không gọi được Support decision RPC.
- Support không tạo incident thay Driver.
- Driver không tạo incident cho order của Driver khác.
- Driver không UPDATE incident status trực tiếp.
- Customer chỉ đọc incident thuộc order của mình.
- Customer không đọc attachment.
- Storage path sai order/incident/uploader bị từ chối.
- `PUBLIC` không có execute privilege ngoài grants chủ đích.

### 11.3. Timeout tests

- Đặt `wait_deadline_at` trong quá khứ.
- Chờ/query lại order.
- Xác nhận order vẫn `waiting_support`.
- Xác nhận return row chưa được tạo.
- Chỉ RPC Support mới thay đổi trạng thái sau deadline.

Nếu local database không thể dựng từ migrations hiện tại, phải dừng, báo schema drift và xin hướng xử lý. Không dùng remote database để thay cho local SQL tests.

## 12. Shared domain files

### Sửa

```text
packages/giaohang_domain/lib/giaohang_domain.dart
```

### Tạo

```text
packages/giaohang_domain/lib/src/order_status.dart
packages/giaohang_domain/lib/src/incident_status.dart
packages/giaohang_domain/lib/src/incident_catalog.dart
packages/giaohang_domain/lib/src/order_incident_model.dart
packages/giaohang_domain/lib/src/incident_attachment_model.dart
packages/giaohang_domain/lib/src/order_return_model.dart
```

Nguyên tắc:

- Giữ `OrderModel.status` hiện tại là String trong MVP.
- Shared constants chứa database value và tập active/blocking/return statuses.
- Model có `fromJson`/`toJson`.
- Catalog chứa code, label, phase và `requiresEvidence`.
- Package domain không phụ thuộc Flutter.

## 13. Delivery App — data và providers

### Sửa

```text
apps/delivery_app/lib/core/models/order_model.dart
apps/delivery_app/lib/core/services/customer_order_service.dart
apps/delivery_app/lib/core/services/driver_order_service.dart
apps/delivery_app/lib/core/services/order_assignment_service.dart
apps/delivery_app/lib/core/providers/driver_nav_session_provider.dart
```

### Tạo

```text
apps/delivery_app/lib/features/incidents/data/order_incident_service.dart
apps/delivery_app/lib/features/incidents/data/incident_evidence_service.dart
apps/delivery_app/lib/features/incidents/providers/order_incident_providers.dart
apps/delivery_app/lib/features/incidents/utils/incident_ui_policy.dart
```

Providers tối thiểu:

```text
latestOrderIncidentProvider
blockingOrderIncidentProvider
orderIncidentRealtimeProvider
incidentSubmissionController
returnActionController
```

Service phải map lỗi Postgrest/storage thành thông báo có khả năng phục hồi; không để UI tự xây SQL payload phức tạp.

## 14. Driver UI

### Sửa tối thiểu

```text
apps/delivery_app/lib/features/driver/screens/navigation/driver_navigation_screen.dart
apps/delivery_app/lib/features/driver/screens/navigation/driver_navigation_delivery_actions.dart
apps/delivery_app/lib/features/driver/screens/navigation/models/driver_delivery_workflow.dart
apps/delivery_app/lib/features/driver/screens/navigation/widgets/driver_navigation_view.dart
apps/delivery_app/lib/features/driver/screens/navigation/widgets/driver_delivery_workflow_panel.dart
apps/delivery_app/lib/features/driver/screens/home/utils/driver_home_formatters.dart
apps/delivery_app/lib/features/driver/screens/home/widgets/driver_order_card_components.dart
apps/delivery_app/lib/features/driver/screens/orders/utils/driver_order_filter.dart
```

### Tạo

```text
apps/delivery_app/lib/features/incidents/dialogs/report_driver_incident_sheet.dart
apps/delivery_app/lib/features/incidents/widgets/driver_incident_button.dart
apps/delivery_app/lib/features/incidents/widgets/incident_type_selector.dart
apps/delivery_app/lib/features/incidents/widgets/incident_evidence_picker.dart
apps/delivery_app/lib/features/incidents/widgets/driver_incident_banner.dart
apps/delivery_app/lib/features/incidents/widgets/support_waiting_countdown.dart
apps/delivery_app/lib/features/incidents/widgets/driver_return_workflow_panel.dart
```

UI rules:

- CTA giao hàng hiện tại vẫn là primary 52dp.
- `Báo cáo sự cố` là secondary outlined/text, touch target tối thiểu 48dp.
- Form dùng `Form` + validation; không dùng Material `AlertDialog` mặc định.
- Loại sự cố thay đổi theo order phase.
- Description optional nếu lý do rõ, tối đa 1.000 ký tự.
- Ảnh bắt buộc theo catalog; safety issues không ép chụp.
- Button gửi disabled + loading khi RPC/upload đang chạy.
- Có error state và retry upload.
- Blocking incident khóa CTA workflow.
- `waiting_support` hiển thị countdown.
- `return_approved` hiển thị `Bắt đầu hoàn hàng`.
- `returning` hiển thị `Xác nhận đã hoàn hàng`.
- Dùng tokens từ `giaohang_design`; không hardcode màu/spacing.

Không refactor toàn bộ navigation. `driver_navigation_screen.dart` hiện trên 500 dòng nên chỉ thêm provider wiring/call site; logic mới phải nằm trong files feature riêng. Báo cáo lại line count của file sau khi sửa.

## 15. Operations Web — Support Incident Queue

### Sửa

```text
apps/operations_web/lib/router.dart
apps/operations_web/lib/features/support/screens/support_home_screen.dart
```

### Tạo

```text
apps/operations_web/lib/features/incidents/data/support_incident_repository.dart
apps/operations_web/lib/features/incidents/models/support_incident_detail.dart
apps/operations_web/lib/features/incidents/screens/support_incidents_screen.dart
apps/operations_web/lib/features/incidents/widgets/support_incident_filters.dart
apps/operations_web/lib/features/incidents/widgets/support_incident_list.dart
apps/operations_web/lib/features/incidents/widgets/support_incident_card.dart
apps/operations_web/lib/features/incidents/widgets/support_incident_detail.dart
apps/operations_web/lib/features/incidents/widgets/support_incident_evidence.dart
apps/operations_web/lib/features/incidents/widgets/support_incident_actions.dart
apps/operations_web/lib/features/incidents/widgets/support_incident_states.dart
apps/operations_web/lib/features/incidents/widgets/support_waiting_countdown.dart
apps/operations_web/lib/features/incidents/dialogs/approve_return_dialog.dart
apps/operations_web/lib/features/incidents/dialogs/reject_incident_dialog.dart
```

Route mới:

```text
/support-incidents
```

Không thêm state-management dependency mới vào Operations Web. Giữ repository + StatefulWidget/controller cục bộ theo kiến trúc hiện tại.

Màn Support MVP cần:

- filter theo incident status;
- loading, error có retry và empty state;
- card danh sách ngắn gọn;
- trang/dialog chi tiết responsive;
- order, Customer, Driver và Recipient;
- incident type, description và evidence signed URLs;
- countdown;
- chỉ render actions hợp lệ với transition hiện tại;
- disable action trong lúc RPC chạy;
- confirm dialog cho approve return và reject.

Không tạo master-detail framework phức tạp. Không sửa module legacy risk.

## 16. Customer Tracking

Customer không tạo incident trong MVP.

### Sửa tối thiểu

```text
apps/delivery_app/lib/features/customer/screens/tracking/tracking_widgets.dart
apps/delivery_app/lib/features/customer/screens/tracking/tracking_helpers.dart
apps/delivery_app/lib/features/customer/screens/tracking/utils/tracking_map_phase.dart
apps/delivery_app/lib/features/customer/screens/order/order_helpers.dart
```

### Tạo

```text
apps/delivery_app/lib/features/incidents/widgets/customer_incident_status_banner.dart
```

Không sửa `tracking_screen.dart` nếu có thể, vì AGENTS.md yêu cầu refactor trước khi thêm feature trực tiếp vào file đó.

Banner mapping:

| Incident/order state | Nội dung |
|---|---|
| `submitted` | Đã tiếp nhận sự cố |
| `under_review` | CSKH đang xử lý |
| `waiting` | Đang chờ xử lý |
| `continue_delivery` | CSKH đã cho tiếp tục giao |
| `return_approved` | CSKH đã cho phép hoàn hàng |
| `resolved` + order `returned` | Đơn hàng đã được hoàn |
| `rejected` | Báo cáo không được chấp nhận |

Customer không được xem description, evidence hoặc Support actions trên UI MVP.

## 17. Flutter tests

### Shared package

```text
packages/giaohang_domain/test/incident_catalog_test.dart
packages/giaohang_domain/test/order_status_policy_test.dart
```

### Delivery App

```text
apps/delivery_app/test/order_incident_service_test.dart
apps/delivery_app/test/driver_incident_form_test.dart
apps/delivery_app/test/driver_incident_workflow_test.dart
apps/delivery_app/test/driver_waiting_support_test.dart
apps/delivery_app/test/driver_return_workflow_test.dart
apps/delivery_app/test/customer_incident_banner_test.dart
```

### Operations Web

```text
apps/operations_web/test/support_incident_queue_test.dart
apps/operations_web/test/support_incident_actions_test.dart
apps/operations_web/test/support_waiting_countdown_test.dart
```

Widget tests phải có ít nhất:

- loading;
- empty;
- error/retry;
- disabled action;
- countdown active/expired;
- invalid transition error;
- evidence required validation;
- correct phase incident list;
- text scale không overflow ở các component mới.

## 18. Lộ trình thực hiện và gate từng bước

### Bước 0 — Preflight schema/local environment

- [x] Kiểm tra `git status --short` và ghi nhận dirty files.
  - Snapshot 2026-08-04: 425 entry (`10 M`, `405 D`, `10 ??`).
  - Modified: `.gitignore`, `AGENTS.md`, `DESIGN.md`, `README.md`, `ROADMAP.md`,
    `docs/CLEANUP_PLAN.md`, `docs/PROJECT_GUARDRAILS.md`, `pubspec.lock`,
    `pubspec.yaml`, `supabase/functions/find-nearest-drivers-redis/index.ts`.
  - Deleted: chủ yếu là cây Flutter app cũ ở root (`android/`, `ios/`, `lib/`,
    `test/`, `web/`, các desktop runner và assets) trong quá trình tách monorepo.
  - Untracked: `apps/`, `packages/`, roadmap này, `docs/adr/` và sáu migration
    hiện có từ `202608010001_add_support_role.sql` đến
    `20260803053933_harden_driver_assignment_ranking.sql`.
  - Các thay đổi trên được xem là dữ liệu người dùng; không reset, restore hoặc
    ghi đè trong các bước tiếp theo.
- [x] Kiểm tra Supabase CLI/version/help.
  - Snapshot 2026-08-04: Supabase CLI `2.109.1`; `supabase --help`,
    `supabase migration --help` và `supabase test --help` đều exit code 0.
  - Migration CLI có các subcommand `list`, `new`, `repair`, `squash`, `up`,
    `down`, `fetch`; test CLI có `db` và `new`.
- [x] Kiểm tra `supabase/config.toml`, migration workflow và migration ledger local.
  - Snapshot 2026-08-04: `config.toml` tồn tại và hiện chỉ cấu hình
    `verify_jwt` cho ba Edge Functions; không có `schema_paths` hoặc cấu hình
    declarative migrations.
  - Không có `supabase/schemas/`; project dùng imperative migrations với 25 file
    SQL trong `supabase/migrations/`, từ `202606010001` đến `20260803053933`.
  - CLI `2.109.1` xác nhận ledger local dùng `supabase migration list --local`.
    Lệnh read-only này trả `LegacyDbConnectError` vì PostgreSQL local chưa chạy,
    nên local migration ledger hiện chưa đọc được. Không dùng `--linked` và không
    truy cập remote để thay thế.
- [x] Đối chiếu read-only schema/RLS live qua Supabase MCP; không mutate.
  - Snapshot 2026-08-04: `order_status` live vẫn chỉ có `pending`, `confirmed`,
    `assigned`, `picking_up`, `delivering`, `delivered`, `cancelled`; `user_role`
    có `customer`, `driver`, `admin`, `support`.
  - Chưa có bảng incident/return/chat, ba cột incident trên `orders`, tám RPC MVP
    hoặc private bucket `incident-evidence`.
  - Policy UPDATE rộng `orders_update_related` vẫn tồn tại với điều kiện
    Customer hoặc assigned Driver; phải audit/harden ở Bước 3 sau compatibility tests.
  - Cả 15 bảng ứng dụng trong `public` đều bật RLS. MCP đồng thời cảnh báo critical
    rằng bảng PostGIS `public.spatial_ref_sys` chưa bật RLS; chỉ ghi nhận, không tự
    áp remediation vì cần đánh giá tương thích PostGIS và quyền Data API riêng.
  - Chỉ dùng `list_tables` và các câu `SELECT`; không gọi `apply_migration` và không
    mutate schema/dữ liệu remote.
- [ ] Xác nhận local database có thể dựng từ migrations.
- [ ] Nếu schema drift chặn local test, dừng và báo người dùng.

Gate: chưa tạo feature files trước khi biết local SQL test có chạy được hay không.

### Bước 1 — Migration enum

- [ ] Tạo migration `add_order_incident_mvp_statuses` bằng CLI.
- [ ] Thêm đúng bốn order statuses.
- [ ] Reset/migrate local thành công.
- [ ] Không thay đổi remote.

Gate: local DB nhận enum values và migration ledger sạch.

### Bước 2 — Schema, RLS và Storage

- [ ] Tạo migration `create_order_incident_mvp_schema`.
- [ ] Thêm order columns.
- [ ] Tạo bốn bảng, indexes và constraints.
- [ ] Tạo private bucket/policies.
- [ ] Bật RLS và grants tối thiểu.
- [ ] Cập nhật active-order index.
- [ ] Chạy advisors/local checks phù hợp.

Gate: schema migrate từ đầu, RLS bật và không có table mới public ngoài ý muốn.

### Bước 3 — RPC workflow

- [ ] Tạo migration `create_order_incident_mvp_workflow`.
- [ ] Tạo đúng tám RPC.
- [ ] Revoke `PUBLIC` execute.
- [ ] Ghi events atomically.
- [ ] Harden policy rộng sau compatibility checks.

Gate: không có direct incident/order return mutation ngoài RPC.

### Bước 4 — SQL tests

- [ ] Tạo state-machine tests.
- [ ] Tạo RLS/authorization tests.
- [ ] Tạo timeout-no-auto-return tests.
- [ ] Chạy toàn bộ SQL tests local.

Gate: tất cả SQL tests PASS. Không tiếp tục Flutter feature nếu DB contract chưa ổn định.

### Bước 5 — Shared domain/constants

- [ ] Tạo constants/models/catalog.
- [ ] Export từ `giaohang_domain.dart`.
- [ ] Viết package tests.
- [ ] Chạy format/analyze/test package.

Gate: hai app dùng cùng database values và incident catalog.

### Bước 6 — Delivery service/providers

- [ ] Cập nhật `OrderModel`.
- [ ] Cập nhật active-status queries/session.
- [ ] Tạo incident/evidence service.
- [ ] Tạo providers/realtime subscription.
- [ ] Viết service/provider tests.

Gate: Driver có thể tạo incident và nhận realtime outcome bằng test, chưa cần UI hoàn chỉnh.

### Bước 7 — Driver Incident UI

- [ ] Thêm secondary incident action.
- [ ] Tạo contextual bottom sheet.
- [ ] Validation description/evidence.
- [ ] Banner submitted/review/waiting/outcomes.
- [ ] Lock workflow CTA khi blocking.
- [ ] Countdown active/expired.
- [ ] Widget tests.

Gate: Driver report flow hoạt động, CTA chính không bị cạnh tranh thị giác.

### Bước 8 — Support Incident Queue

- [ ] Thêm route và entry point.
- [ ] Repository query joined detail.
- [ ] Filter/list/detail/evidence/countdown.
- [ ] Review/wait/continue/approve/reject actions.
- [ ] Loading/error/empty/disabled states.
- [ ] Widget/repository tests.

Gate: mọi quyết định Support đi qua RPC và UI không gửi lặp.

### Bước 9 — Return workflow

- [ ] Driver panel `return_approved`.
- [ ] Start return RPC/action.
- [ ] Confirm return RPC/action.
- [ ] Update active order/session/home/filter labels.
- [ ] Return workflow tests.

Gate: `return_approved → returning → returned` hoàn chỉnh và incident thành `resolved`.

### Bước 10 — Customer banner

- [ ] Tạo banner component.
- [ ] Tích hợp tracking mà không thêm form.
- [ ] Map đủ incident outcomes.
- [ ] Điều chỉnh tracking map/status helpers cho support/return statuses.
- [ ] Widget tests.

Gate: Customer chỉ xem trạng thái, không thấy evidence/action.

### Bước 11 — Full verification và handoff

- [ ] `dart format` cho files thay đổi.
- [ ] Analyze workspace/apps.
- [ ] Chạy package tests.
- [ ] Chạy Delivery App tests.
- [ ] Chạy Operations Web tests.
- [ ] Chạy SQL tests từ local clean state.
- [ ] Báo danh sách files tạo/sửa.
- [ ] Báo file nào sau thay đổi vượt 400 dòng.
- [ ] Báo migration/RPC/RLS summary.
- [ ] Xác nhận chưa apply remote.

Gate: chỉ sau bước này mới được hỏi người dùng xác nhận apply remote.

## 19. Verification gate trước remote apply

Tất cả phải PASS:

```text
Local database rebuild/migrations
SQL state-machine tests
SQL RLS tests
SQL timeout/no-auto-return tests
Shared package analyze/tests
Delivery App flutter analyze/tests
Operations Web flutter analyze/tests
Formatting check
Security/grants review
Changed-files report
```

Sau khi người dùng xác nhận riêng:

1. Re-check live schema/migration ledger.
2. Apply migrations theo đúng thứ tự.
3. Chạy read-only verification queries.
4. Chạy Supabase advisors.
5. Smoke test bằng tài khoản Driver và Support.
6. Không sửa dữ liệu production để tạo test case nếu chưa được cho phép.

## 20. Những điều không được làm

- Không apply remote trong khi đang phát triển local.
- Không dùng `apply_migration` MCP để thử SQL.
- Không thêm chat/compensation/post-delivery support.
- Không đổi `risk_reports` legacy.
- Không thêm role `recipient`.
- Không dùng incident type làm order status.
- Không tự động hoàn sau 15 phút.
- Không cho Driver hoặc Customer gọi Support-decision RPC.
- Không tin role/status/phase do client tự khai báo.
- Không dùng service-role key trong Flutter client.
- Không reset/revert dirty working tree của người dùng.
- Không refactor toàn bộ large files nếu không trực tiếp cần cho MVP.

## 21. Suggested skills cho phiên mới

- `supabase`: bắt buộc cho schema, migrations, RPC, RLS, Storage và advisors.
- `tdd`: nên dùng cho SQL state machine và Flutter service/widget tests theo red–green–refactor.
- `ui-ux-pro-max`: dùng ở bước Driver UI, Support Queue và Customer banner.
- `diagnose`: chỉ dùng nếu local Supabase, tests hoặc existing workflow phát sinh lỗi khó xác định.

## 22. Trạng thái handoff hiện tại

- [x] Đã đọc và phân tích project liên quan Orders, Driver Navigation, Customer Tracking, Support và legacy Risk Reports.
- [x] Đã đối chiếu read-only schema live qua Supabase MCP.
- [x] Đã phát hiện enum order hiện vẫn chỉ có bảy trạng thái cũ.
- [x] Đã phát hiện chưa có bảng incident/return/chat.
- [x] Đã phát hiện policy live `orders_update_related` cần audit/hardening.
- [x] Đã thống nhất scope MVP trong tài liệu này.
- [ ] Chưa tạo migration MVP.
- [ ] Chưa viết SQL tests.
- [ ] Chưa sửa Flutter code.
- [ ] Chưa apply Supabase remote.
