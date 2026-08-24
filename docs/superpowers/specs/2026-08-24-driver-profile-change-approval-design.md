# Driver Profile Change Approval Design

## Goal

Thiết kế lại trang tài khoản tài xế theo hướng hồ sơ chỉ đọc, không hiển thị điểm đánh giá, hiển thị đầy đủ thông tin đã cung cấp khi đăng ký và cho phép tài xế gửi yêu cầu thay đổi để Admin duyệt. CSKH chỉ xử lý vấn đề giao hàng và không tham gia, không nhìn thấy, không có quyền database đối với workflow hồ sơ tài xế.

Mọi thay đổi hồ sơ đều cần Admin duyệt. Dữ liệu đang có tiếp tục là nguồn sự thật cho đến khi yêu cầu được duyệt; không có cập nhật lạc quan hoặc cập nhật một phần.

## Confirmed business rules

- Tài xế không được xem điểm rating tổng hợp của chính mình trên UI hoặc qua API dành cho tài xế.
- Trang tài khoản hiển thị các thông tin cơ bản đã đăng ký dưới dạng chỉ đọc.
- Tài xế không tự cập nhật trực tiếp bất kỳ trường hồ sơ nào.
- Một yêu cầu có thể chứa nhiều trường thay đổi.
- Admin duyệt hoặc từ chối toàn bộ yêu cầu; không duyệt từng trường.
- Tại một thời điểm, mỗi tài xế chỉ có tối đa một yêu cầu đang chờ xử lý.
- Tài xế được hủy yêu cầu khi Admin chưa bắt đầu xử lý.
- Chỉ role `admin` được xem hàng đợi và quyết định yêu cầu.
- Role `support`/CSKH không có route, UI, RLS hoặc RPC cho workflow này.
- Các trường vận hành như GPS và trạng thái sẵn sàng nhận đơn không phải trường hồ sơ và tiếp tục dùng luồng cập nhật hiện tại.
- Đổi mật khẩu vẫn dùng luồng Supabase Auth riêng, không thuộc yêu cầu thay đổi hồ sơ.

## Scope

### In scope

- Redesign trang tài khoản trong `apps/delivery_app`.
- Loại bỏ rating khỏi view data và UI tài khoản tài xế.
- Form gửi, xem trạng thái và hủy yêu cầu thay đổi hồ sơ.
- Hàng đợi duyệt trong mục Tài xế của `apps/operations_web`.
- Bảng yêu cầu riêng, RPC command, RLS, trigger bảo vệ cột hồ sơ và audit metadata.
- Upload file thay thế vào Storage private và signed URL cho Admin.
- Đồng bộ email đăng nhập qua server-side Edge Function khi yêu cầu có đổi email.
- Thu hẹp quyền đọc rating và quyền cập nhật hồ sơ hiện đang quá rộng.

### Out of scope

- Không tái sử dụng hoặc thay đổi workflow `support_tickets`.
- Không cho Support xử lý yêu cầu hồ sơ.
- Không thay đổi công thức rating hoặc cách khách hàng đánh giá tài xế.
- Không migrate hàng loạt toàn bộ file KYC cũ trong bucket public `driver-kyc`; đây là cleanup bảo mật riêng.
- Không thay đổi GPS ingestion, phân công đơn, trạng thái availability hoặc KYC đăng ký ban đầu ngoài những điểm cần tương thích với policy mới.
- Không thêm duyệt từng trường, nhiều cấp duyệt hoặc SLA/escalation trong phiên bản này.

## Options considered

### A. Dedicated profile-change request table — selected

Tạo aggregate riêng cho yêu cầu thay đổi hồ sơ, snapshot dữ liệu cũ và payload đề nghị. Cách này giữ ranh giới nghiệp vụ rõ, hỗ trợ audit và không cấp quyền cho CSKH.

### B. Reuse `support_tickets` — rejected

`support_tickets` hiện thuộc nghiệp vụ CSKH và có policy cho Support. Tái sử dụng sẽ trộn quyền, trạng thái và UI giữa hỗ trợ giao hàng với quản trị danh tính tài xế.

### C. Version every driver profile — rejected for now

Lưu toàn bộ phiên bản hồ sơ là mô hình mạnh nhưng tăng đáng kể độ phức tạp query, đồng bộ và migration. Snapshot bất biến trên yêu cầu đã đủ cho phạm vi hiện tại.

## Driver account UX

### Screen structure

Trang dùng `AppColors`, `AppTextStyles`, `AppSpacing`, `AppRadius`, `AppShadow`, mobile-first ở 375dp và tuân thủ `DESIGN.md` cùng `docs/design/visual_first_ui.md`.

1. Hero gọn gồm avatar, họ tên và trạng thái xác minh hồ sơ.
2. Không có metric, label, icon hoặc placeholder rating.
3. Card `Thông tin cá nhân`: họ tên, email, số điện thoại.
4. Card `Phương tiện`: loại xe, hãng/mẫu, màu xe, biển số.
5. Card `Hồ sơ xác minh`: trạng thái CCCD, GPLX, ảnh phương tiện; số giấy tờ được mask và không render lại ảnh nhạy cảm cho tài xế.
6. Các card có affordance khóa/ngắn gọn cho biết thay đổi cần Admin duyệt.
7. Một CTA primary ở cuối phần hồ sơ: `Yêu cầu chỉnh sửa hồ sơ`.
8. Đăng xuất tiếp tục là action phụ, không cạnh tranh với CTA chính.

Khi có yêu cầu `pending` hoặc `applying`, CTA đổi thành `Xem yêu cầu đang chờ` và không cho tạo yêu cầu thứ hai. Card trạng thái hiển thị mã ngắn, thời gian gửi và trạng thái. Khi bị từ chối, card hiển thị lý do Admin; khi `conflicted`, card yêu cầu kiểm tra hồ sơ mới và gửi lại.

### Request flow

Luồng dùng full-height bottom sheet hoặc màn hình con, không dùng `AlertDialog` mặc định:

1. Server tạo hoặc trả lại một draft duy nhất của tài xế.
2. Chọn một hoặc nhiều trường cần đổi.
3. Nhập giá trị mới hoặc upload file mới vào path của draft.
4. Nhập lý do thay đổi bắt buộc.
5. Review dạng `Hiện tại → Đề nghị`, chỉ hiển thị các trường thực sự thay đổi.
6. Submit một lần; chỉ báo thành công sau khi server chuyển draft sang `pending`.

Giá trị mới phải khác giá trị hiện tại sau khi normalize. Email chuẩn hóa lowercase; số điện thoại, biển số và số giấy tờ được trim/validate theo rule dùng trong wizard đăng ký. File phải đúng MIME và giới hạn 5 MB.

## Admin UX

Trong mục `Tài xế`, thêm sub-tab `Yêu cầu thay đổi` với badge số yêu cầu chờ. Không đưa tab này vào Support workspace.

Danh sách ưu tiên `pending` cũ nhất trước, mỗi card hiển thị tài xế, số trường thay đổi, thời gian gửi và trạng thái. Detail sheet/panel gồm:

- hồ sơ hiện tại;
- từng diff cũ–mới;
- lý do tài xế;
- ảnh/giấy tờ mới qua signed URL;
- cảnh báo nếu snapshot không còn khớp;
- action secondary `Từ chối` và primary `Duyệt và áp dụng`.

Từ chối bắt buộc nhập lý do. Duyệt có confirmation tóm tắt số trường sẽ thay đổi. Khi command đang chạy, cả hai action bị khóa để tránh double submit.

## Data model

Tạo bảng `public.driver_profile_change_requests`:

- `id uuid primary key default gen_random_uuid()`
- `driver_id uuid not null references public.drivers(id)`
- `requested_by uuid not null references public.users(id)`
- `current_snapshot jsonb`
- `requested_changes jsonb`
- `reason text`
- `status text not null default 'draft'`
- `decided_by uuid references public.users(id)`
- `decided_at timestamptz`
- `decision_reason text`
- `created_at timestamptz not null default now()`
- `updated_at timestamptz not null default now()`

Public lifecycle values là `pending`, `approved`, `rejected`, `cancelled`, `conflicted`. Trạng thái nội bộ `draft` dùng khi form chưa submit; `applying` chỉ dùng khi yêu cầu có side effect Auth/Storage. UI hiển thị `applying` như đang xử lý và không cho thao tác lặp.

Partial unique index trên `driver_id` với status trong `draft`, `pending`, `applying` bảo đảm một draft/active request. Draft không xuất hiện trong hàng đợi Admin. Check constraint yêu cầu snapshot, changes và reason khác rỗng khi status rời `draft`. Index khác phục vụ hàng đợi Admin theo `(status, created_at)` và lịch sử tài xế theo `(requested_by, created_at desc)`.

`requested_changes` chỉ chứa allowlist:

- `full_name`, `email`, `phone`, `avatar_path`
- `vehicle_type`, `vehicle_brand_model`, `vehicle_color`, `license_plate`
- `id_card_number`, `id_card_front_path`, `id_card_back_path`
- `driver_license_number`, `driver_license_path`, `vehicle_photo_path`

`current_snapshot` dùng các key đích hiện hữu (`avatar_url`, `id_card_front_url`, `id_card_back_url`, `driver_license_url`, `vehicle_photo_url`) cho các file và cùng key với changes cho các scalar field. Server giữ mapping path đề nghị → cột đích; client không được chọn tên cột database.

Không nhận `role`, `rating`, `total_deliveries`, `approval_status`, `is_available`, tọa độ, wallet hoặc bất kỳ field hệ thống nào từ client. Server tự tạo snapshot từ bảng hiện tại; client không được cung cấp snapshot tùy ý.

Requester bất biến sau insert. Snapshot, changes và reason chỉ được command ghi khi chuyển `draft → pending`, sau đó trở thành bất biến. Chỉ command được phép chuyển status và ghi decision metadata.

## Commands and state transitions

Các public command:

- `create_driver_profile_change_draft()`
- `submit_driver_profile_change_request(p_request_id uuid, p_changes jsonb, p_reason text)`
- `cancel_driver_profile_change_request(p_request_id uuid)`
- `approve_driver_profile_change_request(p_request_id uuid)` cho yêu cầu không đổi email hoặc avatar
- `reject_driver_profile_change_request(p_request_id uuid, p_reason text)`

Mỗi SECURITY DEFINER function phải có `SET search_path = ''`, dùng tên schema đầy đủ, revoke execute khỏi `PUBLIC`/`anon`, grant có chủ đích cho `authenticated`, kiểm tra `auth.uid()` và role từ `public.users`. Không dùng `user_metadata` cho authorization.

### Draft and submit

1. Xác thực caller là driver và tìm `drivers.id` theo `auth.uid()`.
2. `create...draft` trả draft hiện có hoặc tạo một row `draft` mới; từ chối nếu đã có `pending`/`applying`.
3. Client upload file vào path của draft.
4. `submit...` khóa draft và profile, validate allowlist, type, độ dài, format, quyền sở hữu file và ít nhất một thay đổi thật.
5. Server tự tạo snapshot tương ứng với keys trong changes; client không gửi snapshot.
6. Command ghi snapshot/changes/reason, chuyển `draft → pending` và trả row an toàn cho UI.

### Cancel

Chỉ requester được hủy. Với `draft`, command xóa draft chưa submit và cleanup file best-effort. Với `pending`, command chuyển sang `cancelled`. Request `applying` hoặc đã quyết định không thể hủy.

### Reject

Chỉ Admin được gọi. Lý do bắt buộc, request phải `pending`, và command ghi `rejected`, `decided_by`, `decided_at`, `decision_reason` trong một transaction.

### Approve

1. Xác thực role Admin.
2. `SELECT ... FOR UPDATE` request và profile liên quan.
3. Từ chối double decision.
4. So sánh current profile với snapshot cho đúng các field được đề nghị.
5. Nếu lệch, chuyển `conflicted`; không ghi đè dữ liệu mới hơn.
6. Nếu khớp, cập nhật `users` và `drivers` trong cùng transaction.
7. Ghi `approved`, actor và timestamp.

Không có partial approval. Một lỗi validation hoặc update làm rollback toàn bộ database transaction.

### Email change

Email đăng nhập thuộc Supabase Auth nên không được cập nhật bằng service role trong Flutter. Request có đổi email được Operations Web gửi tới Edge Function `approve-driver-profile-change-request` với JWT Admin:

1. Xác thực JWT và role Admin phía server.
2. Gọi command prepare để lock logic và chuyển request sang `applying` nếu snapshot còn hợp lệ.
3. Dùng server-side admin API đổi Auth email.
4. Gọi command finalize để cập nhật `public.users.email`, các field còn lại và status `approved`.
5. Nếu finalize thất bại, function cố gắng khôi phục Auth email cũ và đưa request về `pending`; nếu compensation không thành công, chuyển `conflicted` và trả lỗi rõ cho Admin.

Các bước phải idempotent theo request id. Service-role chỉ tồn tại trong Supabase secrets/runtime, không nằm trong source Flutter, log hoặc response.

Các command nội bộ `prepare_driver_profile_change_approval`, `finalize_driver_profile_change_approval` và `rollback_driver_profile_change_approval` chỉ cấp execute cho service role của Edge Function. Request có avatar mới cũng đi qua Edge Function: avatar được copy từ private draft path sang bucket public `driver-avatars` trước khi finalize. Nếu copy/finalize lỗi, profile cũ vẫn là nguồn sự thật; object mồ côi được cleanup best-effort.

## Authorization and database hardening

Live database audit ngày 2026-08-24 cho thấy:

- `drivers_select_all` cho mọi authenticated user đọc toàn bộ dòng `drivers`, gồm rating;
- `drivers_update_own` cho tài xế cập nhật dòng của mình;
- grants trên `drivers`, `users` và một số bảng cũ đang rộng hơn policy thực tế.

Feature này phải đóng các đường bypass sau:

### Rating privacy

- Revoke table-level `SELECT` trên `drivers` khỏi `anon` và `authenticated`.
- Grant column-level SELECT cho authenticated trên allowlist cần thiết, loại trừ `rating`.
- Mọi `.select()` trực tiếp vào `drivers` trong hai app phải đổi thành explicit column lists, không dùng `select()`/`*`.
- `get_my_driver_account_profile` trả profile self không có rating.
- `get_public_driver_for_order` chỉ trả rating cho customer của order hoặc Admin; nếu caller là assigned driver thì rating là null/omitted.
- `admin_list_drivers` tiếp tục trả rating sau khi tự kiểm tra role Admin.
- Policy `reviews_select_driver_own` được thu hẹp để tài xế chỉ đọc review do chính họ tạo theo chiều `driver_to_customer`; tài xế không đọc điểm `customer_to_driver` dành cho mình.

### Profile write protection

- Revoke table-level UPDATE trên `drivers` khỏi authenticated.
- Grant UPDATE chỉ cho các cột vận hành thực sự cần từ client, ví dụ `current_lat`, `current_lng`, `location_updated_at`, `updated_at`; availability tiếp tục qua RPC hiện có.
- Profile fields chỉ được update trong Admin approval command.
- Thu hẹp grants trên `users` để không cho client tự thay `role`; trigger/policy chặn driver tự thay các field hồ sơ, trong khi các role khác giữ hành vi hiện hữu nếu nằm ngoài scope.
- Registration insert-own tiếp tục hoạt động và được test riêng.

RLS request cho driver đọc draft/lịch sử của chính mình; Admin chỉ đọc request đã submit (`status <> 'draft'`). RLS được tách theo SELECT/INSERT/UPDATE; UPDATE có cả USING và WITH CHECK. Grants và RLS nằm cùng migration. Thiết kế tuân thủ hướng dẫn Supabase hiện hành về grants, RLS, SECURITY DEFINER và Data API exposure:

- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/changelog?types=breaking-change

## Storage design

Tạo bucket private `driver-profile-request-files`, giới hạn 5 MB và chỉ nhận JPEG/PNG/WebP. Tạo thêm bucket public `driver-avatars` chỉ cho avatar đã được approval flow publish. Object draft có dạng:

`<user_id>/<request_id>/<file_type>.<extension>`

Storage policies cho bucket private:

- Driver insert/select/delete object thuộc user id của mình và request còn `draft`.
- Admin select object của request đã submit; không đọc file trong draft chưa gửi.
- Support và anon không có quyền trên `driver-profile-request-files`.
- Khi request chuyển `pending`, driver không còn update/delete file; Admin luôn review đúng file đã submit.
- Không cho overwrite object của request đã quyết định.

KYC mới tiếp tục ở private path và Admin đọc bằng signed URL ngắn hạn. Tài xế chỉ thấy trạng thái có/thiếu. Avatar mới nằm private khi draft/pending; Edge Function chỉ copy sang `driver-avatars` và cập nhật URL chính thức khi approval thành công. `driver-avatars` cho phép public SELECT vì avatar được hiển thị cho khách hàng, nhưng không cấp INSERT/UPDATE/DELETE cho client; chỉ approval Edge Function được ghi.

Migration không chuyển hàng loạt URL cũ từ public bucket `driver-kyc`. Repository/media helper phải hỗ trợ cả legacy HTTP URL và private object path để rollout không làm hỏng hồ sơ hiện có. Cleanup/migration bucket cũ cần spec riêng.

File upload hoàn tất khi request còn `draft`. Nếu upload lỗi, draft vẫn giữ để retry nhưng không xuất hiện trong hàng đợi Admin. Reject/cancel thực hiện delete best-effort; object mồ côi không bao giờ được tham chiếu làm hồ sơ chính thức và có thể được cleanup riêng.

## Realtime and refresh

Khối lượng workflow thấp nên Postgres Changes là đủ cho Admin queue và trạng thái request của tài xế. Subscription vẫn chịu RLS; driver chỉ nhận row của mình, Admin nhận queue, Support không nhận event. UI luôn hỗ trợ pull-to-refresh/fetch lại như fallback.

Không sửa schema `realtime`. Bảng mới chỉ được thêm vào publication nếu verification xác nhận project chưa tự publish và realtime thực sự được dùng.

## Error handling

- Upload lỗi: giữ draft/form và cho retry, không chuyển sang `pending`.
- Submit validation lỗi: hiển thị lỗi cạnh field; không optimistic success.
- Duplicate active request: mở request đang chờ thay vì tạo row thứ hai.
- Snapshot mismatch: status `conflicted`, không áp dụng thay đổi.
- Reject thiếu lý do: command từ chối.
- Double approve/reject: command idempotent hoặc trả domain error không thay dữ liệu.
- Auth email side effect lỗi: request không được báo approved; thực hiện compensation như mô tả.
- Realtime mất kết nối: refresh/fetch lại từ server.
- Signed URL hết hạn: tạo lại URL, không biến thành lỗi hồ sơ.

## Models and code boundaries

### Shared domain package

Thêm model dùng chung cho hai app:

- `DriverProfileChangeRequest`
- `DriverProfileChangeStatus`
- typed field/diff representation hoặc validated JSON adapter

Model có `fromJson`/`toJson` và không chứa service-role hoặc raw signed URL lâu dài.

### Delivery App

- `driver_account_screen.dart` chỉ giữ scaffold/layout/provider wiring.
- Profile cards ở `widgets/`.
- Request form/sheet ở `dialogs/` hoặc màn hình riêng.
- Repository/provider cho request tách khỏi `DriverService` nếu service bắt đầu pha nhiều trách nhiệm.
- Format/mask/field labels ở `utils/`.
- `DriverAccountViewData` loại bỏ `rating` hoàn toàn.

### Operations Web

- Admin request queue, filter và detail nằm dưới `features/admin/screens/drivers/` hoặc feature con chuyên biệt.
- Repository gọi command tách khỏi widget.
- Không thêm code vào `features/support/`.

Không tạo file production mới quá 400 dòng. File trên 400 dòng được báo khi bàn giao; file trên 500 dòng phải có split plan trước khi mở rộng.

## Verification strategy

Thực hiện TDD và verification tập trung theo `AGENTS.md`.

### Database and authorization

- Driver tạo/xem/hủy request của mình.
- Driver không đọc request hoặc file của driver khác.
- Support không select/insert/update request và không execute decision command.
- Admin xem và quyết định request.
- Anon không có quyền.
- Không tạo hai active request cho một driver.
- Snapshot do server tạo và payload ngoài allowlist bị từ chối.
- Duyệt atomic; validation failure rollback toàn bộ.
- Snapshot conflict không ghi đè.
- Driver không select được `drivers.rating` hoặc review `customer_to_driver` của mình.
- GPS/location và availability command vẫn hoạt động.
- Wizard đăng ký tài xế vẫn insert profile ban đầu.

Verification phải dùng local Supabase hoặc development branch trước khi áp dụng production, sau đó chạy security/performance advisors và test query xác nhận grants/policies. Không áp dụng migration vào remote project nếu chưa có chấp thuận Supabase riêng của người dùng.

### Flutter/domain tests

- Domain model JSON/status/diff tests.
- Repository tests cho submit/cancel/approve/reject mapping và domain errors.
- Widget test không tìm thấy rating label/value/icon trên driver account.
- Widget test hiển thị thông tin đăng ký, CTA và pending/rejected/conflicted state.
- Request review hiển thị đúng cũ–mới và không submit khi không có diff.
- Admin detail bắt buộc lý do từ chối và khóa double submit.
- Layout 375dp, text scale 1.6 và touch target tối thiểu 48dp.

Chỉ chạy `flutter test` cho các test file liên quan và `flutter analyze` tập trung trên package/feature vừa sửa. Không chạy full suite, full build hoặc E2E nếu người dùng không yêu cầu hay thay đổi không ảnh hưởng xuyên toàn hệ thống.

## Rollout order

1. Viết migration, policy/RPC contract tests và kiểm chứng trên môi trường không phải production.
2. Thêm shared domain model/repository API.
3. Cập nhật driver read paths thành explicit column lists và endpoint self không rating.
4. Thêm Storage private/public avatar và Edge Function approval cho email/avatar.
5. Triển khai Delivery App account/request UI.
6. Triển khai Admin queue/detail/decision UI.
7. Chạy focused verification, advisors và audit grants cuối.
8. Chỉ sau chấp thuận riêng mới áp dụng migration/Edge Function lên Supabase project thật.

## Acceptance criteria

- Tài xế không thấy hoặc truy vấn được rating tổng hợp của mình qua các API được cấp cho driver.
- Trang tài khoản hiển thị thông tin đã đăng ký, không dùng Material default thô và không có rating.
- Mọi profile change tạo request; profile thật không đổi trước approval.
- Admin duyệt/từ chối nguyên request và có audit actor/time/reason.
- CSKH không có UI hoặc database access vào workflow.
- Một driver chỉ có một active request.
- Conflict không ghi đè dữ liệu mới hơn.
- KYC mới ở private Storage; Admin dùng signed URL.
- GPS, availability, registration và customer tracking không bị regression.
- Focused tests/analyze đã chạy và phần chưa chạy được báo rõ.
