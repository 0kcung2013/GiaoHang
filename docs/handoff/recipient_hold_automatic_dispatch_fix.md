# Giữ đơn vẫn không nhận lời mời tự động — 2026-10-30

## Nguyên nhân và phạm vi

Điều phối thực tế chạy `road_dispatch_candidates` →
`private.road_driver_candidates` → `commit_road_driver_offer`.
Migration giữ đơn trước đã cập nhật nhận đơn/FreePick và
`road_lookup_candidates`, nhưng bỏ sót truy vấn private dùng alias `a`.
Truy vấn đó vẫn loại tài xế có bất kỳ đơn `delivering`, kể cả đang giữ hợp lệ.

Migration `20261030065628_recipient_hold_automatic_dispatch.sql` sửa đúng bộ chọn
private này. Một đơn đang giữ, chưa tới giờ hẹn và chưa chờ CSKH hoàn được miễn
khỏi kiểm tra nhiệm vụ đang thực hiện. Vẫn chặn nếu giữ đã đến giờ, thiếu giờ
hẹn, có yêu cầu hoàn, có đơn đang thực hiện khác hoặc lời mời khác còn hạn.
Các kiểm tra online, phê duyệt, tài khoản, số dư, GPS mới, thanh toán và khoảng
cách đường bộ được giữ nguyên. Không thêm bảng, field, dependency, secret,
environment variable hoặc thay đổi pipeline GPS/R2.

## Đối soát đơn được báo lỗi

GH-10478 được giữ lúc 13:49:13 nhưng luồng tiếp tục giao chuyển thành `resumed`
lúc 13:49:23. Với trạng thái đó, chặn nhận đơn mới là đúng. Theo yêu cầu đang
chờ giao của người dùng, đã khôi phục phần giữ còn lại khi tài xế vẫn ở điểm
giao và không có nhiệm vụ khác. Giữ đúng giờ hẹn cũ 14:04:13, không tạo lượt giữ
15 phút mới. Phần thời gian ở `resumed` không được miễn vào hạn giao.

Nhật ký `Khôi phục giữ đơn sau sửa điều phối` giữ snapshot trước sửa, lý do,
giờ khôi phục và giờ hẹn cũ. `delivery_hold` bổ sung dữ liệu đối soát trong JSON
hiện có. Đây là sửa dữ liệu một lần cho đơn được báo lỗi, không phải chức năng
cho phép tài xế tự gia hạn hoặc giữ nhiều lần.

Nút **Giao lại** đổi thành **Bắt đầu giao lại** để thể hiện rõ thao tác kết thúc
giữ và chuyển sang thực hiện đơn. Không tự bắt đầu giao lại khi xem trang chủ.

## Kiểm chứng

- `recipient_hold_automatic_dispatch.sql` tái hiện lỗi trước sửa bằng
  `HOLD_AUTO_DISPATCH_MISSING`.
- Sau sửa, cùng test đi qua chọn ứng viên → tạo lời mời/thông báo → nhận đơn
  thứ hai. Chặn giữ quá giờ, hai lời mời đồng thời và lời mời đơn thứ ba.
- Đã chạy lại `driver_recipient_hold.sql` và
  `road_distance_dispatch_regression.sql`; cả ba kịch bản đạt trên Supabase,
  toàn bộ fixture và giao dịch ví rollback.
- 12 test Flutter tập trung về giữ đơn/GPS online đạt; layout 320×568,
  390×844 và chữ 160% vẫn qua sau đổi nhãn nút.
- Server thật ghi nhận GH-10478 còn `holding` đến đúng giờ hẹn và GH-10379
  được gửi lời mời cho cùng tài xế lúc khoảng 13:57. Chưa thao tác nhận lời mời
  thay người dùng hoặc xác nhận giao/thu tiền trên đơn thật.
- Supabase Advisor chạy sau migration, không báo riêng hàm vừa sửa.

## Deploy và vận hành

Migration đã áp dụng lên DATN qua MCP; không chạy lại cùng migration.
Sửa backend có hiệu lực ngay, nhãn nút Flutter cần hot restart/bản app mới.
Không cần reset tài khoản, ví hoặc tạo lại đơn để áp dụng thay đổi điều phối.

Khi kiểm tra lỗi tương tự, đối chiếu `delivery_hold.state` thực tế trước:
`holding` mới giải phóng chỗ cho đơn khác; `resumed` là đang thực hiện.
Kiểm thử cả bộ chọn lời mời tự động, không chỉ gọi trực tiếp `accept_order`.
Không sửa `delivering` thành trạng thái hoàn tất/hủy để giải phóng tài xế.
Nếu cần rollback, phải giữ ngoại lệ nhiệm vụ đang giữ trong bộ chọn, tránh
khôi phục nguyên hàm cũ khiến đơn giữ chặn lời mời trở lại.

## Đối soát GH-10379 / GH-10312 lúc 14:45 ngày 2026-10-30

GH-10379 đang `holding` đến 14:50:42; tài xế online, đã duyệt, không bị khóa nhận
đơn, không có nhiệm vụ đang thực hiện hay lời mời khác. Số dư khả dụng đủ ứng
50.000đ của GH-10312. GPS vẫn cập nhật khoảng 15 giây/lần tại
`11.035441, 106.619023`; không có dấu hiệu bị dừng GPS khi giữ đơn trong phiên này.

Điểm lấy GH-10312 tại `10.9856068030991, 106.673910357355` cách GPS tài xế khoảng
8.147 m đường chim bay. Bán kính mời tự động của đơn là 2.000 m; bộ lọc địa lý
trước khi gọi OSRM cho phép thêm 200 m để bù snapping. Đơn này vẫn nằm ngoài
cả hai giới hạn, nên bộ chọn không trả tài xế đó. Cron/Edge trả HTTP 200,
`offered: 0, waiting: 1`; đơn còn trong thời gian tìm tài xế tại lúc đối soát.
Giữ đơn chỉ giải phóng một chỗ nhận việc, không miễn giới hạn khoảng cách.

Đã bổ sung tọa độ tương ứng vào `recipient_hold_automatic_dispatch.sql`:
điểm lấy xa bị loại; chỉ đổi điểm lấy sang gần GPS thì cùng tài xế đang giữ đơn
được tạo lời mời/thông báo và nhận đơn thứ hai. Kiểm tra thêm trường hợp điểm lấy
gần nhưng báo giá tuyến đường vượt 2 km vẫn bị chặn. Các kiểm tra giữ đến hạn,
hai lời mời cùng lúc và đơn thứ ba tiếp tục đạt.

SQL regression chạy qua MCP thành công, toàn bộ fixture và giao dịch ví rollback.
Không thay đổi cấu hình bán kính, GPS, dữ liệu đơn thật, schema hay Edge Function
trong lần đối soát này. Không chạy Flutter analyze/test hoặc E2E vì không sửa Dart.
Để kiểm tra lời mời trên giao diện, dùng đơn có điểm lấy trong bán kính đường bộ
2 km từ GPS hiện tại, đồng thời còn thời gian giữ đơn; không sửa GPS hoặc gia hạn
đơn thật để ép điều phối.
