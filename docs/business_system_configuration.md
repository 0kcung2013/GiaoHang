# Cấu hình hệ thống cho Admin

Admin mở **Cấu hình hệ thống** từ menu quản trị, hoặc `/admin-home?section=configuration`.
Mọi thay đổi cần lý do; trang hiển thị giá mẫu, giá trị trước/sau và lịch sử phiên bản.
Nạp phiên bản cũ chỉ tạo bản nháp. Nhấn lưu để tạo một phiên bản mới.

## Phạm vi hiện tại

| Nhóm | Cấu hình mặc định |
|---|---|
| Giá giao | 18.000đ gồm 2 km; toàn bộ phần vượt 2 km thêm 5.000đ/km; làm tròn lên 1.000đ |
| Phí hoàn | 50% cước giao của đơn; đơn vị vận hành chi trả theo luồng hiện có |
| COD | 2.000.000đ; có thể nâng đến trần backend hiện hỗ trợ là 10.000.000đ |
| Hàng hóa | Giá trị hàng tối đa 100.000.000đ; hàng đã thanh toán tối đa 2.000.000đ |
| Nạp ví tài xế | 5.000–10.000.000đ mỗi lần |
| Phân công | Lời mời 45 giây, lượt tìm 15 phút, tự động trong 2 km đường đi, FreePick trên 2 đến 3 km |
| Đơn vị | GiaoHang; email cskh@gmail.com; điện thoại trống đến khi Admin cập nhật |

Giữ COD mặc định 2 triệu theo form đang sử dụng, dù SQL cũ từng cho phép 10 triệu.

Giá cước dùng một đơn giá/km, không có mốc hay đơn giá đường dài trong cấu hình mới.
Các ô tiền tự phân cách hàng nghìn. Mô tả từng trường và công thức tự cập nhật theo bản nháp.
Admin có thể nhập quãng đường bất kỳ (0–2.000 km) để xem phí cơ bản, phần vượt gói,
phần làm tròn và tổng tiền. Chỉnh giá sẽ xuất hiện bảng so sánh trước/sau ở 3/10/20 km
trước phần lý do và nút lưu; tính thử không lưu cấu hình.

Snapshot cũ giữ hai trường `long_distance_threshold_m` và `long_distance_per_km`,
tiếp tục tính theo bậc để bảo toàn hóa đơn và lịch sử. Lịch sử vẫn hiển thị hai trường cũ;
khôi phục phiên bản cũ chỉ nạp các trường còn hỗ trợ vào bản nháp một đơn giá/km,
có thông báo giải thích. Giá mẫu 12 km đổi từ 66.000đ thành 68.000đ với mặc định.

Thông tin đơn vị hiển thị tại Trung tâm trợ giúp của Customer/Driver và liên hệ tài khoản bị vô hiệu hóa.
Logo, tên trên cửa hàng ứng dụng, application ID, đa doanh nghiệp trên cùng instance, khu vực phục vụ,
giờ hoạt động và giá theo loại xe chưa nằm trong phiên bản này.

Chính sách giám sát, giới hạn từ chối/giao muộn, điểm vi phạm, thời gian chờ người nhận,
GPS/R2, bí mật tích hợp và mô hình ETA giữ phạm vi hiện có; không đưa vào biểu mẫu này.

## Lưu trữ và quyền

- Tái sử dụng `system_settings`: `business_settings` chứa cấu hình hiện tại và revision;
  `business_settings_revision:<n>` chứa bản bất biến, giá trị trước/sau, lý do, tác giả và thời gian.
- Không tạo bảng mới. `orders.business_policy` lưu snapshot nghiệp vụ theo vòng đời đơn.
  Không dùng `driver_monitoring` để chứa cấu hình hoặc chuỗi GPS.
- Authenticated đọc cấu hình hiện tại. Admin cập nhật qua RPC có kiểm tra role trong `users`;
  Customer/Driver không được đọc lịch sử; CSKH được đọc nhưng không được sửa.
- Chặn ghi trực tiếp từ authenticated; giữ RLS. RPC liên hệ trước đăng nhập chỉ trả ba trường
  tên đơn vị, số điện thoại và email. Edge Function `business-contact` đọc ba trường này bằng
  service role để màn trước đăng nhập hoạt động qua cơ chế pre-request kiểm tra tài khoản hiện có.
  Không thay đổi hoặc bỏ qua kiểm tra tài khoản của những API nghiệp vụ khác.
  Các giá trị cấu hình không chứa secrets.
- RPC lưu khóa dòng cấu hình, so sánh revision và ghi cấu hình/lịch sử trong cùng giao dịch.
  Nếu có xung đột, giữ bản nháp để Admin tải và đối chiếu phiên bản mới.

## Thời điểm áp dụng

- Lưu có hiệu lực ngay cho nghiệp vụ **mới**. Không cập nhật hàng loạt đơn hay giao dịch cũ.
- Giá cước và các giới hạn được kiểm tra ở backend. Payload app gửi khoảng cách tuyến đã báo giá,
  revision và phí; backend tính lại phí, từ chối sai giá hoặc revision đã cũ và yêu cầu báo giá lại.
  Khoảng cách vẫn đến từ luồng OSRM/haversine hiện tại của Flutter; đây chưa phải chứng thực
  tuyến đường bằng chữ ký server. Không dùng cơ chế này như bằng chứng vị trí.
- Phiên VNPAY giữ snapshot server trong `order_payment_sessions.order_payload` và dùng snapshot
  đó khi thanh toán hoàn tất. Phiên tồn tại trước rollout dùng bộ giá/giới hạn cũ (revision -1),
  gồm trần COD backend 10 triệu, để không từ chối hóa đơn đã phát hành.
- Đơn mới lưu snapshot giá, phí hoàn và phân công. Phân công lại thông thường giữ snapshot của đơn;
  lượt tìm mới có hạn mới tính từ giờ server. Không rút ngắn lời mời/lượt tìm đã bắt đầu.
- Đơn cũ không backfill snapshot; `NULL` giữ mốc cũ 45 giây/15 phút, phạm vi 2–3 km và phí hoàn 50%.
  Quy tắc thu hồi do giám sát đã duyệt (tìm lại 15 phút) vẫn độc lập với cấu hình tìm đơn thông thường.
- FreePick kiểm tra từng đơn theo snapshot; đơn cũ và mới có thể cùng tồn tại trên bản đồ.
- Nạp ví đọc hạn mức tại lúc tạo giao dịch; callback giao dịch đang chờ dùng số tiền đã lưu.

## Triển khai và kiểm tra

Migration nền: `supabase/migrations/20261026014349_business_system_configuration.sql`.
Migration công thức một đơn giá: `supabase/migrations/20261026023945_simplify_delivery_pricing.sql`.
Các giá trị lịch sử và `orders.business_policy` không bị cập nhật hàng loạt.
Các Edge Function liên quan: `dispatch-road-orders`, `find-nearest-drivers-redis`,
`find-free-pick-road-orders`, `vnpay-create-wallet-topup`, `vnpay-create-order-payment`, `business-contact`.
Deploy SQL trước các function, rồi phát hành Operations Web và hai app mobile.
Khi áp dụng công thức một đơn giá, app tạo đơn phải gửi revision và khoảng cách đã báo giá.
Client dùng công thức cũ hoặc không gửi thông tin báo giá cần cập nhật và báo giá lại.
Phiên VNPAY đã phát hành giữ nguyên snapshot cũ và vẫn hoàn tất bình thường.

Kiểm tra SQL chạy trong BEGIN/ROLLBACK, chỉ dùng fixture tổng hợp:
`business_system_configuration_regression.sql`, `paid_goods_driver_deposit_regression.sql`,
`customer_wallet_prepaid_delivery_regression.sql`, `road_distance_dispatch_regression.sql`.
`single_rate_pricing_regression.sql` kiểm tra giá 12/20 km, các biên tính phí,
đơn cũ và hóa đơn VNPAY đã chốt theo công thức cũ.
Widget/controller test ở `apps/operations_web/test/business_configuration_test.dart` kiểm tra
lưu, xung đột, lỗi tải lịch sử, bố cục 1440/390/320px (320px với text scale 1.6).
Đặt `BUSINESS_SETTINGS_SCREENSHOT=1` để xuất ảnh render vào `.tmp` của Operations Web.
Mobile test tập trung vào giá cước, form tiền, payload, ví, FreePick và liên hệ hỗ trợ.
Không thực hiện thanh toán tiền thật hay build phát hành trong lượt triển khai này.

## Kết quả triển khai 2026-10-26

- Đã áp dụng migration `20261026014349` lên project đang liên kết và đối chiếu nội dung với file local.
- 19 trường cấu hình khởi tạo ở revision 0. Các thử nghiệm đổi giá/giới hạn đều rollback.
- Đã deploy: `dispatch-road-orders` v2, `find-nearest-drivers-redis` v19,
  `find-free-pick-road-orders` v3, hai function tạo giao dịch VNPAY v5, `business-contact` v1.
- Đã qua 17 test Operations Web, 66 test mobile và 20 test JavaScript tập trung;
  analyze các file/feature thay đổi trong Operations Web, mobile và domain không có issue.
- Bốn kịch bản SQL cấu hình/đặt cọc/ví/đường đi đã qua trong transaction rollback;
  bổ sung kiểm tra hạn mức nạp ví và RLS lịch sử trên database sau triển khai.
- Đã xem ảnh render 1440px và 320px; test thêm 390px, hỗ trợ text scale 1.6 ở 320px.
- Kiểm tra HTTP thực tế: liên hệ công khai trả đúng ba trường; yêu cầu chưa đăng nhập
  bị chặn ở API cấu hình vận hành và năm Edge Function nghiệp vụ.
- Frontend mới ở workspace; chưa build phát hành hoặc publish Operations Web/app mobile.

## Đơn giản hóa giá cước đã duyệt 2026-10-26

- Migration `20261026023945` đã chuyển cấu hình hiện hành sang revision 1, còn 17 trường,
  giữ các mức giá chung và tạo lịch sử chuyển đổi từ công thức theo bậc.
- Với mặc định, 12 km là 68.000đ và 20 km là 108.000đ. Snapshot cũ vẫn là 66.000đ/98.000đ.
- Không đổi `business_policy` trên đơn cũ hoặc payload phiên VNPAY đang chờ.
- Bổ sung mô tả trường, công thức cập nhật theo bản nháp, tính thử quãng đường và
  bảng so sánh giá trước/sau ở 3/10/20 km. Dấu phân cách tiền vẫn giữ nguyên.
- 9 test cấu hình Admin và 23 test báo giá/xác nhận đơn tập trung đã qua;
  năm kịch bản SQL cấu hình, giá một đơn giá, đặt cọc, ví và đường đi đã qua trong rollback.
- Đã kiểm tra render 1440/390/320px; 320px dùng text scale 1.6.
- Cần chạy/phát hành app từ mã mới để tạo báo giá bằng công thức hiện tại.
  Chưa thực hiện build phát hành hoặc giao dịch thanh toán thật.

## Đồng bộ realtime cấu hình 2026-10-26

- Migration `20261026030800_realtime_business_settings.sql` đã được áp dụng.
  Trigger trên dòng `system_settings.business_settings` phát Broadcast khi giá trị đổi,
  sau khi transaction commit. No-op không phát tín hiệu; không cần thêm bảng hay publication.
- Topic công khai `business-settings`, event `settings_changed` chỉ có revision nghiệp vụ
  và ID do Realtime tự gắn. Giá trị, người sửa và lý do vẫn đọc qua API có kiểm tra quyền.
  Client bỏ qua dữ liệu trong tín hiệu và tải lại RPC hoặc `business-contact`.
- `BusinessSettingsLive` trong `giaohang_config` chia sẻ một channel cho mỗi Supabase client,
  gộp tín hiệu, tuần tự hóa request và hủy listener khi màn hình đóng. Tải lại sau join/reconnect,
  đổi phiên đăng nhập và resume; có kiểm tra dự phòng mỗi 60 giây khi còn listener.
- Khách đang tạo/xác nhận đơn thấy “Xem giá mới” khi revision thay đổi; giữ dữ liệu form
  và yêu cầu xem lại giá/hạn mức trước khi gửi. Kiểm tra API thêm một lần trước yêu cầu mới.
  Đơn, phiên VNPAY đã phát hành và lần thanh toán ví chưa rõ kết quả giữ snapshot cũ.
  Chỉ bỏ snapshot chưa thanh toán sau lỗi cấu hình đã được server xác nhận dứt khoát.
- Hạn mức nạp ví, phạm vi tìm đơn FreePick và liên hệ hỗ trợ cập nhật khi màn hình đang mở.
  Nạp ví giữ số tiền đã nhập, khóa tiếp tục nếu vượt hạn mức mới. FreePick vẫn tôn trọng
  snapshot phạm vi tìm kiếm của từng đơn cũ.
- Trang Admin tự cập nhật bản sạch và lịch sử. Nếu có bản nháp, giữ cả giá trị/lý do,
  báo có phiên bản mới và chặn lưu đến khi tải lại; chống response cũ ghi đè phiên bản mới.
- Đã kiểm tra SQL bằng `business_settings_realtime_regression.sql` trong rollback,
  nhận Broadcast thực tế bằng WebSocket chưa đăng nhập và xác nhận cấu hình vẫn ở revision 1.
  Test SDK với WebSocket cục bộ kiểm tra dùng chung channel, tải API tin cậy, resume và reconnect.
- Test tập trung: 13 test Admin và 52 test mobile về realtime, báo giá, thanh toán, liên hệ;
  analyze các file/feature thay đổi sạch. Đã xem render thông báo 320px, text scale 1.6,
  và kiểm tra thêm 390px. Không chạy full suite, build phát hành hay thanh toán thật.
- Backend đã bật realtime; cần chạy/phát hành ba app từ mã mới để giao diện nhận tín hiệu.

## Chia mục quản trị cấu hình

- Tab Thiết lập có 5 mục: Giá cước & hoàn hàng, Hàng hóa & COD, Nạp ví tài xế,
  Phân công đơn, Thông tin đơn vị. Mỗi lần chỉ hiển thị trường của mục đang chọn.
- Màn hình rộng dùng danh mục bên trái; màn hình nhỏ dùng bộ chọn nhóm.
  Mỗi mục có số thay đổi chưa lưu; thanh thao tác cuối trang hiển thị tổng số.
- Bản nháp và lý do được giữ khi chuyển mục. Kiểm tra & lưu gom các thay đổi theo nhóm,
  giữ so sánh giá, yêu cầu lý do và lưu một lần qua hợp đồng hiện có.
- Lỗi nhập liệu trong mục đang đóng được liệt kê ở phần kiểm tra, có hành động mở đúng mục.
  Lịch sử, bảo vệ xung đột phiên bản và realtime tiếp tục dùng luồng hiện có.
- Đã qua 14 test cấu hình tập trung và analyze. Đã xem render 1440px và 320px
  (320px với text scale 1.6), kiểm tra thêm 390px. Chưa build hoặc phát hành web.
