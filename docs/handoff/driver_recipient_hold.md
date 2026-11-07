# Giữ đơn theo yêu cầu người nhận

> GPS và polyline hiện tại: [GPS chung, chuyển B → giao lại A và kiểm thử](driver_shared_gps_routing.md).

> Bản sửa điều phối tự động ngày 2026-10-30:
> [nguyên nhân, migration và kiểm chứng lời mời](recipient_hold_automatic_dispatch_fix.md).
> Bản sửa trạng thái đến nơi khi đổi tab:
> [khôi phục nút giao hàng từ GPS hợp lệ](driver_arrival_tab_restore_fix.md).

Triển khai ngày 2026-10-29. Backend đã áp dụng vào DATN qua Supabase MCP,
migration `20261029155710_driver_recipient_hold.sql`. Flutter nằm trong package
`giaohang_mobile`; cần chạy lại hoặc phát hành bản app có thay đổi này.

## Nghiệp vụ và cấu hình mặc định

- Tài xế đang `delivering`, có vị trí mới trong bán kính 100 m của điểm giao,
  phải gạt **Đã đến điểm giao** và được server xác nhận thành công. Sau đó mới
  hiển thị **Giữ đơn** để chọn 15 / 30 / 60 phút hoặc nhập 1–60 phút.
  Vào vùng GPS không tự ghi nhận thao tác đến nơi. Giữ đơn không phải chờ đủ
  10 phút; mốc chờ đó chỉ áp dụng cho báo cáo không liên lạc được người nhận.
- Mỗi đơn được giữ một lần. Gọi lại khi đang giữ trả lại lịch hẹn cũ, không gia hạn.
- Trạng thái đơn vẫn `delivering`; `orders.delivery_hold` là dữ liệu server quản lý,
  gồm trạng thái giữ, giờ bắt đầu/hẹn, hạn gốc và thông tin yêu cầu hoàn nếu có.
  Không tạo bảng hoặc enum mới, không thay RLS.
- Tối đa hai đơn: một đơn thường và một đơn có lịch sử giữ, kể cả đã bắt đầu giao lại.
  Chưa nhận đơn mới nếu khóa nhận
  đơn còn hiệu lực, tài xế offline, chưa được duyệt, hoặc đơn giữ đã đến giờ hẹn.
  Các điều kiện thanh toán, số dư và quyền nhận lời mời hiện có vẫn áp dụng.
- Giữ nguyên người giữ hàng, tiền hàng và khoản giữ COD. Phí đợi do tài xế và
  người nhận thỏa thuận; hệ thống không báo giá, thu tiền, ghi doanh thu hoặc
  cộng khoản này vào COD. Không bổ sung cấu hình phí chờ cho Admin.
- Nút **Bắt đầu giao lại** dùng được trước giờ hẹn, kể cả khi còn đơn khác đang
  thực hiện. Đơn giao lại trở thành ưu tiên; trạng thái và hạn của đơn kia vẫn chạy.
  Trong khi chờ server, nút tạm khóa để tránh gửi lặp. Can thiệp CSKH/yêu cầu hoàn
  đang xử lý vẫn áp dụng các giới hạn nghiệp vụ hiện có.
- Sau giờ hẹn + 5 phút, có thể yêu cầu hoàn khi không còn đơn đang thực hiện
  khác và đã quay lại điểm giao bằng GPS mới. RPC tạo báo cáo `contact_issue`,
  can thiệp CSKH và audit trong các bảng hiện có. Không yêu cầu ảnh ba cuộc gọi
  cho đúng báo cáo được RPC này tạo. CSKH vẫn phải duyệt hoàn; không tự hoàn.
- Màn hình chính hiển thị thẻ đơn đang giao nổi bật và thẻ đơn giữ gọn ở dưới.
  Đồng hồ dựa trên giờ server từ luồng trạng thái nhận đơn. Màn hình khách hàng
  thay ETA thông thường bằng giờ hẹn khi đơn đang giữ.

## Hạn giao

Khi giữ, server lưu hạn gốc và dự phòng khoảng giữ + 5 phút vào hạn giao.
Khi tiếp tục giao sớm hoặc hoàn tất, server tính lại phần được miễn đúng bằng
`min(thời điểm kết thúc chờ, giờ hẹn + 5 phút) - giờ bắt đầu giữ`.
Không xóa phần trễ trước khi giữ, không miễn thêm thời gian vì giao đơn mới quá lâu.
Hết giờ không tự chuyển sang giao lại: tài xế chủ động chọn đơn cần tiếp tục.

## GPS và nguồn vị trí

- Trên thiết bị ở chế độ `deviceGps`, tọa độ từ Geolocator là vị trí thực;
  không khôi phục tọa độ của một đơn từ phiên điều hướng cũ, không snap tọa độ
  thực lên polyline của đơn đó. Tuyến đường chỉ cung cấp đích và chỉ dẫn.
- Shell chọn đơn đang mở bản đồ, sau đó đến đơn tài xế chọn ưu tiên. Sau khởi
  động lại, mặc định ưu tiên đơn đã bắt đầu giao lại nếu còn hiệu lực. Nếu đơn
  ưu tiên hoàn tất, chọn đơn còn lại; nếu chỉ còn đơn giữ thì tiếp tục theo dõi
  vị trí thiết bị. Không khôi phục tọa độ riêng để chuyển nhiệm vụ.
- Một mẫu vật lý hợp lệ được server dùng để cập nhật giám sát cả hai đơn
  `assigned`/`picking_up`/`delivering`, kể cả khi đơn giữ đã chuyển `resumed`.
  `drivers` vẫn chỉ có một vị trí mới nhất của tài xế.
- Hai đăng ký Realtime cùng tài xế dùng tên channel riêng theo `order_id`;
  đóng một đơn không gỡ channel của đơn còn lại. Đơn giữ nhận vị trí mới qua
  `drivers`; broadcast điều hướng nhanh vẫn gắn đơn đang thực hiện.
- Bộ lọc client loại fix cũ quá 90 giây, tương lai quá 15 giây. GPS cho đơn đang
  thực hiện và bằng chứng đến nơi giữ ngưỡng sai số tối đa 50 m. Từ 2026-10-30,
  luồng báo vị trí online khi chờ đơn cho phép sai số tối đa 200 m để hỗ trợ
  GPS trình duyệt/network; luồng này chỉ cập nhật vị trí phục vụ tìm tài xế,
  không tạo bằng chứng giao hàng hoặc lịch sử của đơn. Xem
  [sửa lỗi mất lời mời](driver_online_gps_discovery_fix.md). Bộ giám sát server còn kiểm tra mẫu trùng,
  thứ tự và bước nhảy không hợp lý theo chính sách GPS hiện có.
- Chế độ demo và traffic scenario vẫn là mô phỏng có chủ đích, không phải GPS
  thực. Khi có lịch sử giữ đơn, không phát lại vị trí riêng của đơn cũ; dùng vị
  trí dùng chung hoặc latest của tài xế. Heartbeat không phát tọa độ phiên cũ
  khi một màn điều hướng khác đang sở hữu nguồn vị trí.
- Không đổi Worker, secrets, bucket hoặc định dạng/chunk/lifecycle R2. Lịch sử
  R2 tiếp tục gắn nhiệm vụ đang phát GPS; không nhân bản hành trình đơn mới vào
  file đơn giữ. Không dùng PostgreSQL làm fallback lịch sử GPS.

## Setup và vận hành

Bổ sung được duyệt ngày 2026-10-30: migration
`20261030154521_allow_early_recipient_redelivery.sql` đã áp dụng qua MCP. Hai unique
index hiện có chia chỗ theo `delivery_hold IS NULL` và `IS NOT NULL` trên các trạng
thái đang thực hiện. Vì vậy chuyển `holding` → `resumed` không tranh chỗ với đơn
thường; database vẫn bảo đảm tối đa hai đơn, mỗi loại một đơn. Không thêm bảng,
cột, RLS, Edge Function, dependencies, secrets hoặc biến môi trường.

RPC `set_driver_recipient_hold(order_id, null)` bỏ điều kiện chờ hoàn tất đơn kia,
giữ kiểm tra chủ đơn, trạng thái, can thiệp CSKH và tính đúng phần thời gian chờ.
RPC GPS dùng lại bộ kiểm tra mẫu hiện có, tuần tự hóa theo tài xế và cập nhật
giám sát cho đơn còn lại. Không thay pipeline lịch sử R2.

Flutter cần hot restart hoặc phát hành bản có thay đổi để bỏ trạng thái khóa nút.
Lựa chọn ưu tiên chỉ tồn tại trong phiên đăng nhập; sau khởi động lại chọn đơn
đang giao lại, tài xế có thể chọn đơn khác bằng **Tiếp tục đơn hàng**. Backend
không tự giao lại hoặc thao tác trên đơn thật khi triển khai migration.

Không rollback về index một đơn đang thực hiện khi vẫn có tài xế đang giao hai
đơn. Nếu phải dừng tính năng, chặn thao tác giao lại mới trên client và để tài xế
hoàn tất các đơn đang nhận; giữ nguyên dữ liệu và lịch sử. Chỉ khôi phục ràng buộc
cũ sau khi kiểm tra không còn cặp đơn vi phạm ràng buộc đó.

Kiểm tra bản giao lại sớm: `driver_recipient_hold.sql`,
`recipient_hold_automatic_dispatch.sql`, `road_distance_dispatch_regression.sql`
đều đạt sau migration trên server, với toàn bộ fixture/giao dịch ví rollback.
39 test Flutter trong 6 file đạt; analyze 9 mục vừa sửa không có vấn đề.
Test bao gồm giao lại trước hẹn khi còn đơn khác, hạn đơn kia giữ nguyên, retry
không cộng thời gian, một mẫu GPS cập nhật hai chiều cho hai đơn, chặn mẫu cũ,
trùng, sai số lớn và nhảy vị trí, chặn nhận/mời đơn thứ ba.

Flutter kiểm tra chuyển đơn ưu tiên/mở map/đóng map/hoàn tất một đơn vẫn giữ
nguyên tọa độ vật lý; hiển thị hai thẻ ở 320/390/900 px và chữ 160%, nút giao lại
khả dụng khi đang có đơn khác, trạng thái chờ server/lỗi. Ảnh render:
`artifacts/driver_early_redelivery_390.png`. Đây là kiểm thử tự động; chưa chạy
GPS ngoài thực địa hoặc E2E với hai tài khoản thật, không chạy full suite/build.

Không có dependency, secret hoặc biến môi trường mới. Áp dụng migration trước
khi phát hành Flutter. Không áp dụng lặp file đã có trong lịch sử migration.
MCP đã kiểm tra bằng truy vấn trước thay đổi; migration và SQL regression được
kiểm tra transaction rollback trước áp dụng, rồi chạy lại regression sau áp dụng.

RPC mới:

- `set_driver_recipient_hold(order_id, minutes)`: giữ; `minutes = null`: tiếp tục.
- `request_recipient_hold_return(order_id)`: yêu cầu hoàn, gọi lặp không tạo trùng.

Các RPC kiểm tra người được phân công, giờ server và tình trạng hàng. Chỉ
`authenticated` có quyền gọi; `anon` không được gọi. Client không được sửa
`delivery_hold` trực tiếp. SQL helper dùng `search_path` rỗng và không mở quyền
trực tiếp cho helper cập nhật một đơn giám sát.

Từ migration `20261030073940_require_delivery_arrival_before_recipient_hold`,
RPC tạo giữ đơn còn yêu cầu nhật ký server **Tài xế đã đến điểm giao** của đúng
tài xế và đơn. Thiếu nhật ký trả `DELIVERY_ARRIVAL_REQUIRED`; không thể bỏ qua
bước gạt bằng cách gọi thẳng RPC. Flutter đọc lại snapshot trước khi mở bảng
chọn thời gian, đồng thời giữ kiểm tra GPS mới khi gửi yêu cầu giữ.

Kiểm chứng điều kiện này: 22 test Flutter trong 3 file đạt, gồm gạt thực sự,
chờ server xác nhận, lỗi xác nhận, mở lại màn và rời vùng giao; hai kịch bản SQL
giữ đơn/điều phối tự động đạt sau migration và rollback toàn bộ fixture.

Supabase Advisor đã chạy sau migration. Có cảnh báo RPC SECURITY DEFINER cho
authenticated, là quyền chủ đích của các RPC có kiểm tra actor; tham khảo
[hướng dẫn Advisor](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).
Các phát hiện ở đối tượng không sửa trong thay đổi này (PostGIS, các RPC cũ,
Auth password protection…) chưa được xử lý trong phạm vi giữ đơn.

## Xử lý sự cố và khôi phục

- Không giữ được: kiểm tra đang ở chặng giao, GPS <60 giây, trong 100 m,
  chưa giữ lần nào, chưa có chỉ dẫn CSKH và không giữ đơn khác.
- Không nhận được đơn: kiểm tra online, khóa nhận đơn, số dư, giờ hẹn và đơn
  đang thực hiện. Không sửa `is_available` hoặc xóa ràng buộc để bỏ qua kiểm tra.
- Không giao lại được: hoàn tất đơn đang thực hiện hoặc xử lý cùng CSKH.
- Không yêu cầu hoàn được: kiểm tra giờ hẹn + 5 phút, GPS mới và đã quay lại.
- Khi mất mạng, thao tác chỉ thành công sau xác nhận RPC; không tự mở nhận đơn.
- Nếu cần dừng rollout, thu hồi quyền EXECUTE của RPC **tạo giữ đơn mới** sau
  khi tách đường resume phù hợp hoặc phát hành bản ẩn nút Giữ đơn. Giữ nguyên
  dữ liệu, người giữ hàng và hỗ trợ giải quyết đơn đang giữ. Không khôi phục
  unique index cũ khi vẫn còn tài xế có hai đơn; không xóa cột để rollback nhanh.

## Kiểm chứng ngày 2026-10-29

- 84 test Flutter tập trung trong 16 file (lượt chính 78, thêm 6 kiểm tra presence/vòng đời): workload, ingest, nguồn vị trí,
  GPS mode, cadence, freshness, điều hướng, Realtime và widget giữ đơn.
- Analyze các file Dart thay đổi và mới: không có lỗi/cảnh báo.
- `supabase/tests/driver_recipient_hold.sql`: đạt trước và sau migration;
  fixture, thông báo, hồ sơ và giao dịch ví đều rollback.
- Widget render 320×568, 390×844, chữ 160%; form nhập thời gian tùy chọn.
  Ảnh kiểm tra cục bộ: `artifacts/driver_recipient_hold_390.png`.

| Trường hợp GPS đã test tự động | Kiểm chứng |
|---|---|
| Đơn giữ đứng trước đơn đang giao | Chọn đơn đang giao làm nguồn GPS |
| Chỉ còn đơn giữ / không còn đơn | Chọn đúng nhiệm vụ hoặc không chọn |
| Đổi lại đơn cũ | Không khôi phục vị trí riêng của đơn có lịch sử giữ |
| Mẫu thực của đơn mới | Ingest giữ nguyên tọa độ và mã đơn đang phát |
| GPS cũ, tương lai, sai số lớn | Client loại trước latest/history; server từ chối giám sát |
| Bước nhảy phi thực tế, mẫu trùng | Giám sát server từ chối |
| Một fix, hai kiện đang giữ trách nhiệm | Cả hai neo giám sát nhận cùng tọa độ |
| Hai đơn cùng tài xế mở theo dõi | Cùng nhận vị trí mới; đóng một subscription không gỡ cái còn lại |
| Broadcast mới gặp PG hoặc poll cũ | Không quay marker về vị trí cũ |
| Quay lại điểm giao để yêu cầu hoàn | Sai điểm hoặc GPS cũ bị chặn; đúng điểm và đủ giờ tạo một hồ sơ |

Chưa chạy thử di chuyển bằng điện thoại thật, GPS mất sóng thực tế, hệ điều hành
kill app, hoặc nền Android/iOS qua nhiều giờ. Test foreground hiện tại chỉ kiểm
tra khai báo Android; không chứng minh background tracking ngoài thực địa.
Chưa chạy full suite, build phát hành, hoặc kiểm thử E2E với hai tài khoản thật.

Giới hạn phiên bản này: chưa có kiểm tra OSRM bảo đảm đơn mới hoàn tất kịp giờ
hẹn; tài xế phải cân nhắc thời gian quay lại. Chưa có push nhắc giờ hẹn theo lịch
khi app đóng; thời gian và cảnh báo hết giờ hiển thị trong thẻ đơn giữ.
