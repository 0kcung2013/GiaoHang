# Hồ sơ một lần và báo cáo doanh nghiệp

Tên hiển thị cho người dùng: **Bảng kê**. File xuất có tiêu đề
**Bảng kê đối soát** để phân biệt với hóa đơn điện tử hay chứng từ khấu trừ thuế.
Giao diện ưu tiên chi phí dịch vụ người gửi chịu, hai chỉ tiêu COD riêng, kỳ đối
soát và một hành động **Tải bảng kê**. Một khối trắng tổng hợp, hai tab **Đơn hàng**
và **Giao dịch tiền**. Hướng dẫn cách đọc mở từ nút thông tin; chi tiết phí/mã giao
dịch mở rộng tại từng dòng. Nút tải mở bảng chọn Excel/PDF kèm khoảng ngày và ghi
chú phạm vi. Hồ sơ tự khai/mã số thuế/thời điểm lấy dữ liệu nằm trong mục mở rộng
**Thông tin trên bảng kê** tại bảng chọn tải. Không còn tab Chứng từ hoặc thẻ hóa đơn chưa có.
Operations dùng cùng giao diện, ghi rõ **Chi phí người gửi chịu**; mobile dùng
**Chi phí bạn chịu**. Màn hình rộng hiển thị danh sách thành các cột căn hàng.

Phạm vi phần mềm hiện tại chỉ hỗ trợ dữ liệu đối chiếu, kế toán và hồ sơ phục vụ
thuế; không tính/kê khai/nộp thay thuế. Đây không phải kết luận đơn vị vận hành
được miễn nghĩa vụ thuế: khi vận hành thật phải xác định theo mô hình pháp lý,
giao dịch và trách nhiệm áp dụng. Không gắn nhãn “hóa đơn hợp lệ”, “chứng từ nộp
thuế” hoặc “đã nộp thuế” cho file bảng kê do ứng dụng tạo.

## Phạm vi đã triển khai

- Customer chọn Cá nhân hoặc Doanh nghiệp sau đăng nhập khi hồ sơ chưa phân loại.
  Tài khoản cũ chưa chọn vẫn đi qua bước này; vẫn truy cập đơn đang có và hỗ trợ.
- Sau lần lưu đầu, `customer_type`, `business_name`, `business_address`,
  `business_tax_code` chỉ đọc. Trigger chặn mọi thay đổi giá trị, kể cả client cũ
  và cập nhật trực tiếp có quyền cao. Họ tên, điện thoại và avatar vẫn sửa qua luồng cũ.
- Lưu lần đầu dùng điều kiện `customer_type IS NULL`. Retry sau mất phản hồi trả
  lại hồ sơ nếu cả bốn giá trị khớp; không ghi đè lựa chọn từ thiết bị khác.
- Customer doanh nghiệp mở **Tài khoản → Hồ sơ kinh doanh** hoặc **Bảng kê**.
  Hồ sơ ghi rõ thông tin tự khai; không tự xác minh doanh nghiệp hoặc mã số thuế.
- Operations → Người dùng lọc Cá nhân/Doanh nghiệp/Chưa phân loại trên server,
  tìm theo tên shop/mã số thuế và mở tab báo cáo trong hồ sơ khách doanh nghiệp.
  Bộ lọc phân loại kết hợp tìm kiếm, trạng thái vô hiệu hóa và phân trang.
- Báo cáo có kỳ mặc định tháng hiện tại, chọn khoảng ngày, ba chỉ tiêu tổng quan,
  chi tiết đơn hàng, giao dịch tiền và xuất `.xlsx`/`.pdf`.

Chưa có quy trình duyệt đính chính, xác minh pháp nhân, phát hành hóa đơn điện tử,
tính/khấu trừ/khai hoặc nộp thuế thay. Nút liên hệ CSKH mở hội thoại hỗ trợ hiện có;
không tự cho nhân viên sửa hồ sơ. Quy trình đính chính có audit cần được chốt riêng.

## Nguồn dữ liệu và công thức

Model dùng chung: `giaohang_domain/src/business_report.dart`.
Package Flutter `giaohang_reporting` sở hữu repository, giao diện và export,
được dùng bởi Customer và Operations; không sao chép cách tính giữa hai app.

RPC `get_customer_business_report(p_customer_id,p_start,p_end)` trả một snapshot
nhất quán gồm hồ sơ hiện tại, giao nhận, giao dịch và `generated_at`.
Customer chỉ đọc của mình; Support/Admin đã đăng nhập được tra cứu; Driver,
khách khác và tài khoản bị vô hiệu hóa bị từ chối. Quyền lấy từ `public.users`
và helper tài khoản hiện có, không dùng user metadata tự sửa được.

| Nội dung | Quy tắc |
| --- | --- |
| Biên thời gian | Ngày Việt Nam UTC+7 chuyển thành UTC; đầu bao gồm, cuối loại trừ |
| Ngày giao nhận | `actual_delivered_at`, `order_returns.returned_at`, `cancelled_at` theo trạng thái kết thúc |
| Dòng tiền ví | Bút toán `status=completed`, theo `completed_at`, giữ dấu `available_delta` |
| Dòng tiền VNPAY | Theo `paid_at`; lấy cả paid/refunded/refund_required đã thực thu, số tiền âm |
| COD đơn giao thành công | Tổng `cod_collection_amount` của đơn delivered trong kỳ |
| COD ghi có ví | Chỉ `delivery_credit` trong kỳ; bồi hoàn/rủi ro/điều chỉnh hiển thị riêng, không cộng vào COD này |
| Chi phí người gửi | Delivered người gửi trả: D+Fc. Returned người gửi trả: D. Cộng phí hoàn đã settled do khách chịu |
| Cước/phí người nhận | Chỉ delivered người nhận trả: D+Fc; không ghi cước chưa thu của đơn hoàn thành chi phí người nhận |
| Đơn hủy | Chi phí dịch vụ bằng 0; tiền thanh toán/hoàn vẫn hiện riêng theo ngày giao dịch |
| Phí hoàn | Lấy `customer_return_charge` khi `fee_status=settled`; không tính từ cấu hình hiện tại |
| Hoàn phí | `delivery_fee_refund` là ghi có ví, không phải hoàn về ngân hàng |

`D` và `Fc` lấy từ snapshot `delivery_fee` và `customer_platform_fee_amount`
trên đơn. Cột phí sàn theo đơn giữ mức gốc; chi phí đơn hoàn đã loại phí sàn.
Không tính lại tỷ lệ đang cấu hình. COD có thể được ứng/ghi có trước khi giao xong,
nên hai chỉ tiêu COD có kỳ ghi nhận khác nhau và không được cộng thành doanh thu.

Giới hạn thực tế:

- Chỉ các đơn đã giao/hoàn/hủy có mốc thời gian kết thúc hợp lệ được phân vào kỳ.
  Đơn đang xử lý không thuộc bảng giao nhận; bút toán liên quan vẫn xuất hiện trong dòng tiền.
  Dữ liệu cũ thiếu mốc kết thúc không được đoán ngày từ `updated_at`.
- Báo cáo là dữ liệu trong GiaoHang; không bao quát bán hàng, công nợ và tiền thu ngoài hệ thống.
  Không dùng `total_price` làm doanh thu hoặc chi phí vì có thể chứa COD.
- Số dư ví không phải số tiền đã rút về ngân hàng; báo cáo không chứng nhận đã thu COD
  từ người nhận độc lập với trạng thái giao hàng.
- Hồ sơ đầu báo cáo là hồ sơ hiện tại, không phải snapshot bên mua tại ngày giao dịch.
  Mã số thuế có thể chưa cung cấp; file là bảng kê, không phải hóa đơn/tờ khai thuế.
- Tối đa 366 ngày và 5.000 dòng cho mỗi phần giao nhận/dòng tiền. Vượt giới hạn
  thì báo lỗi để chia kỳ, không cắt bớt số liệu hoặc export một phần.
- Dữ liệu là snapshot; tải lại để lấy thay đổi. Khi đổi kỳ, xóa dữ liệu kỳ cũ và
  khóa export trong lúc tải/lỗi; phản hồi cũ không thay thế kỳ mới.

## Dependencies và xuất file

`flutter pub get` tại root nhận package workspace mới và lockfile đã cập nhật.
Dependencies trực tiếp: `archive 4.0.9`, `xml 6.6.1`, `pdf 3.12.0`,
`share_plus 11.1.0`; giữ SDK Dart `^3.9.0` và cấu hình runtime Supabase hiện có.
Không thêm biến môi trường, secret, bucket, Worker, lịch chạy hoặc nhà cung cấp hóa đơn.

- Excel là SpreadsheetML `.xlsx` gồm Tổng quan, Giao nhận, Dòng tiền; số tiền
  dạng số, mã/tên/mã số thuế dạng text, không macro/formula từ dữ liệu người dùng.
  ZIP/XML dùng các thư viện tương thích với `image 4.8.0` đã có trong workspace.
- PDF nhúng Roboto Regular/Bold và license Apache 2.0 trong package, hỗ trợ
  tiếng Việt và tạo offline sau khi tải dữ liệu. Có tiêu đề cột lặp, số trang và đơn vị VND.
- Android/iOS mở bảng chia sẻ hệ điều hành để người dùng lưu/chia sẻ.
  Web dùng Web Share khi hỗ trợ hoặc fallback tải file của `share_plus`.
  Việc tạo file không tự gửi email/tin nhắn cho bên thứ ba.
- `share_plus 11.1.0`: Flutter >=3.22, Dart >=3.4, iOS >=12,
  Java 17, Android compileSDK >=34, AGP >=8.3/Gradle >=8.4.
  Cấu hình Android hiện tại đáp ứng; chưa nghiệm thu chia sẻ file trên thiết bị thật.

## Migration và triển khai

Migration chuẩn: `supabase/migrations/20261107052347_customer_business_reporting.sql`.
SQL đã được người dùng duyệt riêng và áp dụng lên backend DATN ngày 2026-11-07.
Không chạy lại trên backend đã có migration này.

Môi trường khác cần baseline hiện hành (users, Auth, account controls, đơn/hoàn,
hai sổ ví, payment sessions và snapshot phí sàn). Theo quy trình bàn giao backend
hiện có; repo chưa có bootstrap database trắng đầy đủ.

1. Đối chiếu migration history/backup, review đúng migration trên.
2. Áp dụng backend trước client. Không thêm bảng/cột/RLS/Edge Function hoặc đổi tiền.
3. RPC cũ `list_staff_accounts` vẫn giữ cho client cũ; client mới dùng `list_staff_accounts_v2`.
4. Chạy regression SQL bên dưới; fixture và tiền thử được rollback.
5. Deploy/release Customer và Operations source mới. Không cần phát hành Driver vì nghiệp vụ này.

## Kiểm tra và xử lý sự cố

Các lệnh Flutter chạy riêng trong từng thư mục:

```powershell
# packages/giaohang_reporting
flutter test --no-pub test/business_report_test.dart
# packages/giaohang_mobile
flutter test --no-pub test/customer_classification_test.dart test/customer_account_ui_test.dart
# apps/operations_web
flutter test --no-pub test/account_controls_test.dart test/account_control_repository_test.dart test/customer_dossier_test.dart
```

SQL Editor/MCP:

- `supabase/tests/customer_business_reporting_regression.sql`: first write, bất biến,
  RLS owner, vai trò, disabled/anon, ngày biên, hoàn ví, bộ lọc và giới hạn 5.000 dòng.
- `supabase/tests/customer_classification_platform_fee_regression.sql`.
- `supabase/tests/platform_fee_collection_regression.sql`.

| Triệu chứng | Xử lý |
| --- | --- |
| `CUSTOMER_CLASSIFICATION_LOCKED` | Đọc lại hồ sơ; không retry bằng cách bỏ khóa, không xóa phân loại |
| `PGRST202` / chưa thiết lập | Kiểm tra đúng backend và migration; tải lại schema cache nếu cần bằng quy trình vận hành hiện có |
| `BUSINESS_PROFILE_REQUIRED` / forbidden | Kiểm tra người gọi, role, chủ hồ sơ và customer_type; không sửa role từ client |
| `BUSINESS_REPORT_TOO_LARGE` | Chia nhỏ khoảng ngày |
| Chênh COD giữa hai tổng | Đối chiếu mã đơn và ngày ghi có ví so với ngày giao, xem riêng bồi hoàn/rủi ro |
| File không hiện bảng lưu | Kiểm tra hỗ trợ chia sẻ/tải của trình duyệt/hệ điều hành; mở lại từ thao tác trực tiếp |

Khôi phục an toàn: có thể tạm ngừng giao diện báo cáo hoặc thu hồi quyền gọi hai
RPC mới bằng thay đổi được duyệt; giữ khóa phân loại và toàn bộ snapshot/ledger.
Không restore database cũ, sửa/xóa bút toán hoặc tắt trigger để xử lý báo cáo lỗi.

Mốc xác minh 2026-11-07: 40 kiểm tra Flutter tập trung đạt; analyze phạm vi sửa đạt;
ba regression SQL đạt với rollback, trong đó regression tính năng đã chạy lại sau deploy.
Đã xem render report 320/390/1100px ở chữ 160%, mở lại XLSX bằng openpyxl,
kiểm tra PDF tiếng Việt 5 trang/90 đơn và xem trang đầu/cuối.
Chưa build phát hành toàn app, chưa kiểm thử chia sẻ trên Android/iOS thật hoặc
Web Share/tải file trong trình duyệt thật. Chưa tích hợp hóa đơn/thuế.

Lượt rút gọn giao diện Bảng kê: kiểm tra tập trung trong package reporting gồm
viewport 320/390/1100px, cỡ chữ 100%/160%, mở bảng tải và hồ sơ, chọn định dạng,
hướng dẫn đọc số liệu, kỳ rỗng, lỗi tải và phản hồi cũ. Khi đang tải/lỗi không có
nút xuất kỳ cũ; thay đổi hồ sơ/kỳ khi bảng tải đang mở sẽ hủy lựa chọn snapshot cũ.
Không đổi SQL, quyền, cách tính hay dữ liệu. File Excel/PDF vẫn là bảng kê hỗ trợ đối chiếu.

Xác minh lượt rút gọn: 12 test reporting, 9 test tài khoản Customer và 4 test hồ sơ
Operations đạt; analyze reporting và màn hình hồ sơ Operations đạt. Đã xem ảnh
render mobile 390px, web 1100px và bảng tải trên 320px/chữ 160%. Ảnh QA nằm trong
`.tmp/business_report_compact/` (không commit). Chưa chạy build phát hành hoặc
kiểm thử lưu/chia sẻ trên thiết bị thật trong lượt sửa giao diện này.
