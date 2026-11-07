# Phụ phí theo cân nặng và kích thước

## Trạng thái ngày 2026-10-31

Đã triển khai phần Dart: policy dùng chung, khai báo số kiện/nhóm kích thước,
tính phí trước thanh toán, gửi khai báo trong payload COD/ví/VNPAY, hiển thị
phụ phí trên xác nhận và thông tin hàng cho tài xế, cấu hình Admin và tính thử.
Người dùng đã phê duyệt riêng backend và triển khai trong phiên làm việc này.
Migration `20261031040120_cargo_size_weight_pricing.sql` đã được triển khai lên
Supabase DATN; cấu hình hiện ở revision 8 và `cargo_pricing_enabled = 0`.
Giữ nguyên giá cơ bản đang vận hành (15.000đ) và các cấu hình trước đó.
Code ứng dụng chưa được build/phát hành; cần cập nhật client trước khi bật thu phí.

App chỉ hiện khai báo mới khi server trả đủ các khóa cargo và bật
`cargo_pricing_enabled`. Khi server chưa hỗ trợ, giữ payload cũ; Admin chỉ sửa
các trường server hiện có, không gửi các khóa chưa được backend hỗ trợ.

## Nghiệp vụ

- Khách nhập tổng cân nặng gồm bao bì (kg, tối đa 3 chữ số thập phân), số kiện
  nguyên từ 1–100 và chọn nhóm kích thước. Không tự chọn ngầm nhóm tiêu chuẩn.
- Với nhiều kiện, kích thước là bao ngoài khi xếp chung toàn bộ kiện. So sánh
  cạnh dài, cạnh vừa, cạnh ngắn theo thứ tự giảm dần. Đây là khai báo của khách,
  không phải thuật toán xếp hàng tự động.
- Lấy bậc cao hơn giữa cân nặng và nhóm kích thước, thu đúng một lần/đơn.
- Tính cước thô theo quãng đường + phụ phí, sau đó làm tròn lên theo
  `rounding_unit`. Phí nền tảng và phí hoàn tiếp tục dùng cước giao đã chốt,
  bao gồm phụ phí; COD không thuộc cơ sở tính phần trăm này.
- Hàng vượt cân nặng tối đa hoặc chọn vượt kích thước không được qua bước
  thanh toán. Thuộc tính dễ vỡ/danh mục hàng vẫn độc lập.
- Báo giá ở bước trước khai báo được ghi là cước theo quãng đường. Sau khai báo,
  thanh toán và xác nhận dùng tổng phí đã gồm phụ phí.
- Giá thay đổi trong lúc tạo đơn: dùng luồng báo giá hết hạn hiện có để khách
  xem lại. Đơn đã tạo và phiên VNPAY đã chốt phải giữ nguyên snapshot.
- Khi hàng thực tế khác khai báo: dùng hồ sơ CSKH hiện có để trao đổi. Phiên
  bản này chưa có luồng điều chỉnh giá, thu thêm hoặc hoàn tiền sau khi tạo đơn;
  tài xế không được tự sửa phí. Nếu không thể vận chuyển thì xử lý qua CSKH.

## Preset cần Admin kiểm tra trước khi bật

| Nhóm | Tổng cân nặng tối đa | Cạnh dài × vừa × ngắn tối đa | Phụ phí |
|---|---:|---|---:|
| Tiêu chuẩn | 5 kg | 30 × 25 × 20 cm | 0đ |
| Lớn | 10 kg | 40 × 35 × 30 cm | 15.000đ |
| Rất lớn | 20 kg | 50 × 40 × 40 cm | 30.000đ |

Đây là preset phần mềm để vận hành xem xét, không phải giới hạn pháp lý hoặc
cam kết tải trọng của phương tiện. Khởi tạo `cargo_pricing_enabled = 0`.
Hiện chưa có chọn dịch vụ/phương tiện và lọc năng lực xe trong luồng đặt đơn,
vì vậy dùng một bộ giới hạn chung cho mọi tài xế có thể được phân công. Không
nâng giới hạn riêng cho ô tô/xe tải trước khi bổ sung luồng chọn và lọc xe.

## Backend đã triển khai

Không tạo bảng, không đổi RLS, Edge Functions, pipeline ảnh/GPS hay secrets.

1. Thêm **một cột nullable `orders.cargo_details jsonb`** cho dữ liệu của chính
   đơn; đơn cũ giữ NULL. Tái sử dụng `orders.item_weight_kg` cho cân nặng và
   `orders.business_policy` cho snapshot bảng giá. Ràng buộc cấu trúc nhóm,
   số kiện 1–100, tier và phụ phí không âm; kết quả tier/phí do server ghi.
2. Mở rộng JSON `system_settings.business_settings.values` bằng các khóa sau:
   `cargo_pricing_enabled` (0/1),
   `cargo_{standard,large,extra_large}_weight_g`,
   `cargo_{standard,large,extra_large}_{length,width,height}_cm`,
   `cargo_large_fee`, `cargo_extra_large_fee`.
   Dùng preset ở trên, tạo revision và audit bằng cơ chế đang có, ban đầu tắt.
   Cân nặng lưu nguyên gram; UI Admin hiển thị kg.
3. Mở rộng `private.validate_business_settings` để kiểm tra các khóa mới:
   ngưỡng cân nặng tăng nghiêm ngặt; kích thước từng cạnh không giảm qua các
   nhóm, dài ≥ vừa ≥ ngắn; phí nhóm lớn ≤ rất lớn; giá không âm. Giới hạn input
   đồng nhất với Dart: cân nặng tối đa 100.000g, mỗi cạnh tối đa 200cm,
   phụ phí tối đa 1.000.000đ. Không thay mặc định legacy của phiên thanh toán cũ.
4. Thêm helper nội bộ tính phụ phí từ khai báo và snapshot; mở rộng
   `private.validate_business_order_quote` kiểm tra tổng cước gồm phụ phí và
   yêu cầu khai báo khi policy bật. Dùng tại cả tạo đơn COD và tạo phiên VNPAY;
   từ chối payload thiếu khai báo, sai nhóm/số kiện, quá cân hoặc tự giảm phí.
5. Mở rộng `private.create_customer_order_with_policy` để ghi `cargo_details`
   từ kết quả tính server; giữ policy đã chốt cho phiên VNPAY khi hoàn tất sau
   khi Admin đổi giá. Không tin `tier`, `surcharge`, `_business_policy` khách gửi.
   Không đổi service_type thành fragile để biểu diễn cồng kềnh.
6. Đã bổ sung cột vào truy vấn chọn trường và model
   thông tin đơn CSKH/Admin để đọc số kiện, kích thước và phụ phí đã chốt.

Payload từ client (chỉ khai báo):

```json
{"item_weight_kg":12,"cargo_details":{"size_group":"large","package_count":2}}
```

Snapshot server lưu tại `orders.cargo_details`:

```json
{"size_group":"large","package_count":2,"tier":"extra_large","surcharge":30000}
```

## Setup, triển khai và khôi phục

- Không thêm dependencies, biến môi trường, secret hoặc dịch vụ lưu trữ.
- Migration đã tạo bằng CLI, triển khai riêng qua Supabase MCP và đồng bộ tên
  file với version migration trên server. Không triển khai các migration khác
  đang có trong working tree. Các helper có search_path cố định, thu hồi quyền
  gọi trực tiếp khỏi PUBLIC/anon/authenticated/service_role; RPC public tiếp tục
  dùng kiểm tra vai trò và quyền đang có.
- Trigger chuẩn hóa snapshot cargo khi INSERT và chặn thay đổi snapshot/cân
  nặng của đơn đã chốt; không thêm quyền sửa tài chính từ client.
- Triển khai backend trước, ba app sau. Giữ thu phí tắt đến khi ứng dụng khách
  được cập nhật; bản client cũ không khai báo sẽ bị từ chối khi bật policy.
- Admin kiểm tra preset, dùng tính thử, ghi lý do và bật qua cơ chế lưu revision.
- Khôi phục: tắt thu phí bằng một revision mới. Giữ cột và snapshot trên đơn/
  phiên thanh toán để tiếp tục đối soát; không xóa dữ liệu hoặc viết lại phí cũ.
- Nếu Admin không thấy trường mới: server chưa có đủ khóa cargo; không tự thêm
  khóa trực tiếp từ client. Nếu bị báo giá hết hạn: quay lại bước báo giá.
- Khôi phục revision trước tính năng: phần cấu hình cargo hiện tại được giữ lại
  trong bản nháp thay vì tự suy đoán giá trị chưa từng có ở revision cũ.

## Kiểm tra

Test tập trung:

```text
packages/giaohang_domain: dart test test/cargo_pricing_test.dart
packages/giaohang_mobile: flutter test test/cargo_pricing_flow_test.dart test/order_cargo_weight_test.dart test/business_settings_test.dart test/create_order_payment_step_test.dart test/create_order_required_fields_test.dart
apps/operations_web: flutter test test/business_configuration_test.dart
```

Đã qua analyze tập trung, 6 test domain, 14 test mobile liên quan, 26 test
Admin/thông tin đơn CSKH; thêm render cho mobile 320/390/1000dp, chữ 160% ở
320dp, Admin 390/1440dp. PNG kiểm tra ở `artifacts/cargo_pricing_20261031/`.

Đã chạy trên Supabase và rollback toàn bộ fixture sau mỗi lượt:
`supabase/tests/cargo_pricing_regression.sql` và
`supabase/tests/single_rate_pricing_regression.sql`. Kiểm tra bậc cân nặng/
kích thước, làm tròn, khai báo sai, chống tự giảm phí, COD, ví (trừ đúng một
lần), phiên VNPAY giữ giá cũ, phí sàn gồm phụ phí, quyền Admin và audit.

Docker local không chạy nên SQL được kiểm tra bằng fixture trong transaction
rollback trên Supabase; migration có assertion thuần trước khi commit rollout.
Chưa chạy giao dịch qua cổng VNPAY thật, full suite, build phát hành hoặc E2E.
Security Advisor không phát sinh finding mới cho phần cargo; các finding cũ
ngoài phạm vi được giữ nguyên.
