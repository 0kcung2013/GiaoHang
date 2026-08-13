# Database consolidation

## Mục tiêu

Giảm dữ liệu và cấu trúc trùng lặp trong Supabase mà không làm mất lịch sử,
không làm yếu RLS và không gộp các bảng có vòng đời khác nhau.

Sau thay đổi, số bảng nghiệp vụ giảm từ 23 xuống 20:

- `driver_locations` là nguồn lịch sử GPS duy nhất; xóa `locations`.
- `risk_report_messages` là nguồn trao đổi rủi ro duy nhất; xóa
  `risk_report_notes` và dùng `visibility = 'internal'` cho ghi chú nội bộ.
- `orders` là nguồn mô tả kiện hàng duy nhất; xóa `order_items`.

Không thay đổi `saved_addresses`/`recent_addresses`, `users`/`drivers`, các bảng
audit, evidence, proof hoặc read cursor thành quan hệ gộp.

## Quyết định domain

### Một đơn là một kiện hàng

Mỗi đơn giao hàng có đúng một mô tả kiện hàng trên `orders`:

- `item_name`
- `item_category`
- `item_description`
- `item_image_url`
- `declared_value` mới, nullable, không âm

`declared_value` là giá trị hàng do khách khai báo. Nó không phải
`delivery_fee`, `total_price`, COD hoặc thu nhập tài xế. Thiết kế phí và COD sẽ
dùng trường này trong một thay đổi riêng.

Đơn legacy có nhiều dòng `order_items` được gộp thành một mô tả kiện hàng xác
định theo thứ tự UUID. Tổng `quantity * price` chỉ được chuyển sang
`declared_value` khi khác `delivery_fee`; các dòng do command hiện tại tạo với
`price = delivery_fee` không được hiểu sai thành giá trị hàng.

### Ghi chú rủi ro là message nội bộ

Ghi chú của Support/Admin là một `risk_report_messages` có
`visibility = 'internal'`. Quyền ghi vẫn yêu cầu nhân viên đang phụ trách báo
cáo. Participant không được đọc message hoặc event nội bộ.

RPC `add_risk_report_note` được giữ như adapter tương thích nhưng ghi vào
`risk_report_messages` và trả về row message. UI Operations Web đọc một stream
message thay vì truy vấn `risk_report_notes` riêng.

### Địa chỉ gần đây và đã lưu vẫn tách riêng

`saved_addresses` là dữ liệu do người dùng quản lý; `recent_addresses` là lịch
sử dụng có giới hạn và tự động cập nhật. Không gộp hai bảng.

Trong `saved_addresses`, chỉ xóa sáu cột đã được backfill và trùng hoàn toàn:

- `label`
- `address_line`
- `lat`
- `lng`
- `is_default_pickup`
- `is_default_delivery`

Tạm giữ `contact_name` và `contact_phone`: cloud đang có hai dòng chứa dữ liệu
không tồn tại trong orders, nên xóa lúc này sẽ gây mất dữ liệu. Việc bổ sung hai
trường này vào model hoặc loại bỏ có backup là quyết định sản phẩm riêng.

## Các hướng đã cân nhắc

### A. Consolidation chọn lọc — chọn

Tạo migration mới, migrate dữ liệu có assertion, cập nhật caller và sau đó xóa
ba bảng trùng. Hướng này giảm bảng nhưng giữ nguyên các seam RLS có giá trị.

### B. Giữ compatibility view lâu dài

Đổi ba bảng cũ thành view để client cũ tiếp tục đọc. Triển khai ít gián đoạn hơn
nhưng duy trì interface cũ và khiến nguồn sự thật khó nhận biết. Chỉ dùng adapter
tạm khi cần rollout, không phải trạng thái đích.

### C. Rebuild schema từ đầu

Tạo baseline mới rồi nhập lại dữ liệu. Schema cuối gọn nhất nhưng rủi ro cao vì
repository và migration history cloud hiện đang lệch nhau. Không chọn.

## Migration và triển khai

### 1. Preflight

- Không sửa migration lịch sử `202607240001_drop_unused_locations_and_routes`.
- Tạo migration mới bằng Supabase CLI để cloud ghi nhận đúng version hiện tại.
- Ghi lại count/checksum, newest timestamp và số owner của các bảng sắp xóa.
- Migration phải dừng nếu có `locations` chưa có điểm tương ứng trong
  `driver_locations` theo driver, tọa độ và sai số timestamp tối đa một giây.
- Migration phải dừng nếu backfill kiện hàng còn order không thể biểu diễn bằng
  mô hình một kiện.

### 2. GPS legacy

- Xóa policy/dependency cùng `locations` bằng `DROP TABLE ... CASCADE` sau
  assertion.
- Không thay đổi `driver_locations`, pipeline Redis hoặc vị trí nóng trên
  `drivers`.

### 3. Risk notes

- Copy mọi row notes hiện có sang `risk_report_messages` với cùng UUID,
  `visibility = 'internal'` và role snapshot lấy từ `users`.
- Chuyển event `note_added` sang `message_added`, đổi `note_id` thành
  `message_id` và thêm `visibility = 'internal'`.
- Thay RPC `add_risk_report_note` bằng adapter ghi message nội bộ.
- RLS select của messages chỉ cho participant xem `public`.
- RLS event không cho participant xem event có visibility nội bộ.
- Cập nhật Operations Web rồi xóa `risk_report_notes`.

### 4. Order items

- Thêm `orders.declared_value numeric` với constraint nullable hoặc `>= 0`.
- Backfill `item_name`/`item_description` cho order thiếu inline item từ child
  rows theo quy tắc xác định.
- Chỉ backfill `declared_value` khi tổng child value khác `delivery_fee`.
- Cập nhật `create_customer_order` để không tạo child row và không coi phí giao
  là giá trị hàng.
- Bỏ query/provider/model/UI phụ thuộc `order_items`; UI đọc trực tiếp item
  fields của `OrderModel`.
- Xóa policy, index và bảng `order_items` sau khi không còn caller.

### 5. Saved address columns

- Assertion xác nhận canonical address/coordinate đã được backfill và không
  xung đột.
- Xóa sáu cột trùng đã liệt kê.
- Giữ `contact_name`, `contact_phone` và không log giá trị PII.

### 6. Rollout

- Đây là thay đổi phối hợp database và hai Flutter app; áp dụng trong maintenance
  window của môi trường demo.
- Apply migration một lần sau khi test tĩnh và test Flutter liên quan đã pass.
- Ngay sau apply, chạy query kiểm chứng schema, row counts, RLS và các RPC tạo
  đơn/ghi chú.
- Không sửa trực tiếp migration cũ hoặc tự chèn version vào migration history.

## Xử lý lỗi và khả năng phục hồi

- Toàn bộ DDL/DML consolidation nằm trong transaction migration.
- Mọi assertion chạy trước `DROP TABLE`/`DROP COLUMN`; thất bại phải rollback toàn
  migration.
- Không xuất `contact_name`/`contact_phone` vào log hoặc artifact.
- Nếu verification sau apply thất bại, dừng rollout app và phục hồi từ backup
  Supabase thay vì tạo migration vá dữ liệu phỏng đoán.

## Kiểm thử

### RED

- Thêm migration contract test yêu cầu migration mới có assertion, backfill,
  constraint `declared_value`, adapter note và ba `DROP TABLE` mục tiêu.
- Thêm test cho `OrderModel` đọc/ghi `declared_value`.
- Thêm test Operations Web xác nhận internal note đi qua case messages và không
  còn repository query `risk_report_notes`.
- Chạy từng test và xác nhận fail vì behavior chưa được triển khai.

### GREEN

- Viết migration và thay đổi Dart tối thiểu để các test trên pass.
- Chạy `dart format` cho file Dart đã sửa.
- Chạy `flutter test` tập trung tại từng app và `flutter analyze` chỉ trên file
  liên quan theo AGENTS.md.

### Supabase verification

- Xác nhận không còn relation kind table cho `locations`, `risk_report_notes`,
  `order_items`.
- Xác nhận `orders.declared_value` tồn tại và không âm.
- Xác nhận không còn order thiếu inline cargo sau backfill.
- Gọi RPC tạo đơn và note trong transaction test có rollback khi khả dụng.
- Chạy Security/Performance Advisors và phân biệt warning có trước với regression
  do migration.

## Ngoài phạm vi

- Công thức phí giao hàng, phụ phí hỏa tốc, COD, hoa hồng và thu nhập tài xế.
- Gộp support ticket với risk report.
- Xử lý toàn bộ backlog Security Advisor hiện có.
- Bật RLS hoặc di chuyển PostGIS `spatial_ref_sys`.
- Xóa `contact_name`/`contact_phone` trước khi có quyết định lưu trữ hoặc backup.
