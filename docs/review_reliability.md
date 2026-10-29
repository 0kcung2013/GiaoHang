# Kiểm tra và sửa đánh giá — 2026-10-20

## Trạng thái

Đã sửa mã Flutter cho hai chiều khách → tài xế và tài xế → khách.
Người dùng đã duyệt riêng việc sửa backend ngày 2026-10-24. Đã áp dụng
[20261024024001_review_reliability.sql](../supabase/migrations/20261024024001_review_reliability.sql)
lên DATN, giữ bảng/cột/RLS và hợp đồng hai RPC hiện có.

## Lỗi và thay đổi

- Bỏ fallback truy vấn không có `direction` khi đọc lỗi. Mỗi lần đọc xác định
  đúng đơn, chiều và người gửi; không xác nhận bằng đánh giá của người khác.
- Không coi `null`, `{ok: true}` thiếu biên nhận, sai chiều hoặc sai điểm là
  gửi thành công. Xác thực đầu vào 1–5 sao, nhãn đúng chiều, nhận xét tối đa
  500 Unicode code points; trim nhận xét và loại nhãn lặp.
- Khi RPC lỗi hoặc mất phản hồi, chỉ đọc lại đánh giá của chính người gửi.
  Nếu đã lưu, trả điểm gốc với `already_reviewed: true`, không thay điểm cũ.
  Chặn xác nhận thành công sau khi phiên đăng nhập thay đổi.
- Giới hạn chờ mỗi request 15 giây. Phản hồi muộn không đóng biểu mẫu hoặc
  hiện thành công sau khi đã báo chưa xác nhận được.
- Dùng chung biểu mẫu hai chiều; chặn gửi nhiều lần, mở nhiều sheet cùng đơn,
  kéo/đóng bằng nền và quay lại lúc gửi. Kiểm tra `mounted` trước khi đổi state
  hoặc dùng provider; giữ nội dung khi lỗi và hiển thị thông báo an toàn.
- Hai điểm mở đánh giá của tài xế dùng chung phần kiểm tra tồn tại/xử lý lỗi.
  Trạng thái đánh giá của khách có nút thử lại; cache theo đơn tự giải phóng.
- Nút sao có nhãn trợ năng; biểu mẫu cuộn khi bàn phím mở, thích ứng chữ lớn
  và giới hạn chiều rộng trên web; giữ token của giaohang_design.

## Lỗi backend đã tái hiện trước khi sửa

Hai RPC cũ lấy trung bình đã làm tròn để cộng dồn. Chuỗi `[1,1,2,1]`
cho điểm 1,2 trong khi làm tròn trung bình gốc phải là 1,3. Kiểm thử dùng
đúng migration `202607220006_driver_customer_reviews.sql` để tái hiện lỗi.

Bản SQL đề xuất giữ nguyên hai RPC công khai và các bảng/cột/RLS hiện tại:

- Khóa đơn và hàng giữ điểm tổng trước INSERT; gửi lại trả biên nhận gốc.
- Kiểm tra người gửi, role, đơn đã giao, tài xế và dữ liệu nhận xét/nhãn.
- Tính lại trung bình từ điểm gốc đúng chiều; đối soát điểm và số lượt hiện có.
- Thu hồi quyền gọi RPC qua PUBLIC/anon, giữ authenticated và kiểm tra quyền
  nghiệp vụ trong RPC. Không thay quyền SELECT hoặc mở nội dung đánh giá
  về tài xế cho chính tài xế.

Bản triển khai dùng `FOR NO KEY UPDATE` cho hàng giữ điểm tổng. Hai chiều
đánh giá có khóa ngoại tới users/drivers; kiểu khóa này tuần tự hóa cập nhật
điểm nhưng không xung đột với khóa `KEY SHARE` khi kiểm tra khóa ngoại.
Đối soát chỉ UPDATE hồ sơ khi điểm hoặc số lượt thực sự khác dữ liệu gốc.

Không tạo bảng, điểm phạt hay tự khóa tài xế từ số sao. Kiểm tra live ngày
2026-10-21 xác nhận hai RPC đang dùng phép cộng dồn trung bình đã làm tròn.
Có 15 đánh giá khách → tài xế và 7 đánh giá tài xế → khách; hiện chưa có sai
lệch giữa điểm/số lượt lưu và tổng hợp dữ liệu gốc. Điều này không loại bỏ lỗi
làm tròn đã tái hiện với chuỗi khác hoặc vấn đề khi gửi đồng thời.
Bộ kiểm tra SQL dùng fixture tối thiểu, không thay thế kiểm tra concurrency
thực tế; chưa chạy RPC ghi đánh giá trên dự án thật.

## Khoảng trống cần chốt

Chưa thấy luồng đánh giá xấu → điểm chờ CSKH/Admin xác minh trong mã được kiểm tra.
AGENTS.md yêu cầu điểm chờ xác minh, thời hạn 14 ngày và audit trail nhưng chưa
quy định ngưỡng sao/mức điểm. Đã hỏi người dùng để chốt trước khi thiết kế phần
backend này; không tự thêm nơi lưu hoặc quy đổi thành lỗi tài xế. Vì vậy chưa
thể kết luận toàn bộ nghiệp vụ đánh giá/giám sát đã hoàn thiện trên hệ thống chạy.

## Kiểm chứng

- `flutter test --no-pub test/review_service_test.dart test/review_flow_test.dart`
  tại `packages/giaohang_mobile`: 24 kiểm thử về gửi/đọc, retry, đổi phiên,
  timeout, lifecycle, truy cập, chữ 160%, bàn phím và viewport.
- Đã chạy 24 kiểm thử liên quan ở `driver_orders_ui_test.dart`,
  `driver_order_presentation_test.dart`, `customer_order_detail_sheet_test.dart`
  và `customer_tracking_ui_test.dart`.
- Analyze tập trung service, provider, widgets đánh giá, hai thẻ đơn tài xế
  và hai file test mới. Không chạy full suite hoặc build phát hành.
- Render và xem ảnh tại 390×844, 320×568/chữ 160% và 1280×800;
  script/ảnh tạm nằm trong `.tmp/review_preview_test.dart` và `.tmp/review-*.png`.
- `tool/review_reliability_test.mjs`: 30 kiểm tra SQL trong PostgreSQL tạm bằng
  PGlite 0.5.10; không kết nối hoặc ghi production. Chạy từ repo root:

  ```powershell
  node tool/review_reliability_test.mjs <path-to-pglite>/dist/index.js
  ```

  PGlite là công cụ kiểm thử riêng, không được thêm vào dependency ứng dụng.

## Kiểm tra sau triển khai ngày 2026-10-24

- 30 kiểm tra SQL cô lập chạy với chính migration đã áp dụng: đạt.
- 24 kiểm thử Flutter review_service_test/review_flow_test chạy lại: đạt.
- [account_dispatch_review_regression.sql](../supabase/tests/account_dispatch_review_regression.sql)
  đã đạt trên Supabase: gọi lại một đánh giá hiện có ở mỗi chiều dưới role
  authenticated, xác nhận biên nhận gốc và không thêm đánh giá; rollback toàn
  bộ cập nhật của kiểm tra. Không tạo đơn hoặc đánh giá thử trên dữ liệu thật.
- Trước/sau triển khai có 16 đánh giá khách → tài xế và 7 đánh giá tài xế →
  khách; không có hồ sơ lệch điểm hoặc số lượt. Hai RPC đều có phép AVG từ
  dữ liệu gốc và không còn EXECUTE cho anon/PUBLIC.
- Advisor không có cảnh báo mới do hai bản sửa; hai cảnh báo anon EXECUTE
  của RPC đánh giá đã hết. Cảnh báo authenticated SECURITY DEFINER vẫn là
  quyền RPC có chủ đích, được kiểm tra role/chủ đơn trong hàm.
- Chưa kiểm thử hai phiên PostgreSQL thật chạy đồng thời hoặc end-to-end trên
  thiết bị; Docker local hiện không chạy. Không chạy full suite/build phát hành.
