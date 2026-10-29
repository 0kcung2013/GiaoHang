# Phân loại khách hàng và tỷ lệ phí sàn

Phí sàn đã được mở rộng thành **thu/khấu trừ thực tế**. Hướng dẫn chính sách,
setup, migration/deploy, secrets, kiểm thử và đối soát hiện hành:
[Bàn giao phí sàn](handoff/platform_fee_collection.md).

Khách hàng chọn Cá nhân hoặc Doanh nghiệp sau khi đăng nhập lần đầu. Tài khoản
cũ chưa phân loại cũng được hỏi khi vào trang chủ hoặc tạo đơn. Các tab đơn hàng,
theo dõi, tài khoản và trợ giúp vẫn truy cập được để không gián đoạn đơn hiện tại.
Khi lưu xong, lần đăng nhập sau vào thẳng trang chủ.

Doanh nghiệp bao gồm doanh nghiệp, hộ kinh doanh và shop. Tên đơn vị và địa chỉ
bắt buộc; mã số thuế tùy chọn. Đây là thông tin tự khai, không phải xác minh doanh
nghiệp hoặc cấp quyền ưu đãi. Khách có thể sửa tại Tài khoản → Loại khách hàng.
Họ tên, số điện thoại, avatar tiếp tục sửa tại Thông tin cá nhân.

## Lưu trữ và quyền

Tái sử dụng `users`: `customer_type` (`individual`/`business` hoặc NULL khi chưa
chọn), `business_name`, `business_address`, `business_tax_code`. Chuyển về cá nhân
xóa thông tin doanh nghiệp trong cùng một lần cập nhật. Không suy đoán loại khách
hàng cũ. Ràng buộc database kiểm tra dữ liệu và role; quyền UPDATE theo cột kết hợp
RLS own-row và account-enabled hiện có. Không thay đổi role hay quyền đọc hồ sơ.

Tái sử dụng `system_settings.business_settings` và các revision hiện có:

| Cấu hình | Đối tượng |
| --- | --- |
| `customer_individual_fee_bps` | Khách cá nhân |
| `customer_business_fee_bps` | Khách doanh nghiệp |
| `driver_platform_fee_bps` | Tài xế |

100 basis points = 1%. Giá trị hợp lệ 0–10000, hiển thị tối đa hai chữ số thập phân.
Giai đoạn hiển thị khởi tạo 0%; rollout thu phí đặt 5%/3%/10% khi chưa cấu hình.
Admin chỉnh tại
Cấu hình nghiệp vụ → Phí sàn, lưu qua RPC hiện có với lý do, kiểm tra revision và
lịch sử trước/sau. CSKH chỉ đọc. Ứng dụng mobile nhận thay đổi qua luồng realtime
cấu hình hiện có; lỗi tải hiển thị thử lại, không tự giả định phí là 0%.

## Thu và khấu trừ

Thẻ Phí sàn tại Tài khoản của customer và driver hiển thị tỷ lệ hiện hành. Đơn mới
cộng phí khách vào khoản dịch vụ và trừ phí tài xế khỏi thực nhận. Phí không tính
trên COD. Customer thấy tổng trước xác nhận; tài xế thấy phí và thực nhận trước
nhận đơn. Đơn/phiên thanh toán cũ giữ snapshot cũ.

Vòng đời hủy/hoàn, thanh toán muộn, số dư âm và bảng bút toán được mô tả đầy đủ
trong tài liệu bàn giao ở trên; dùng tài liệu đó làm nguồn nghiệp vụ hiện hành.

## Kiểm tra tập trung

- `packages/giaohang_mobile/test/customer_classification_test.dart`: định tuyến,
  model, form doanh nghiệp, lỗi lưu, viewport nhỏ/chữ lớn/bàn phím và tỷ lệ realtime.
- `apps/operations_web/test/business_configuration_test.dart`: chỉnh phần trăm,
  kiểm tra giới hạn và các hành vi editor/lịch sử hiện có.
- `supabase/tests/customer_classification_platform_fee_regression.sql`: fixture
  tổng hợp, RLS, validation, quyền Admin/CSKH/customer/driver, audit và chống ghi
  đè revision. Toàn bộ fixture và cập nhật phí của kiểm tra được rollback.
