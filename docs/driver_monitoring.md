# Giám sát tài xế sau khi nhận đơn

Phạm vi: nhắc xuất phát phút 5, cảnh báo phút 8, thu hồi phút 10; mất cập nhật GPS nhắc phút 5, cảnh báo phút 9, xử lý phút 10. Tất cả mốc dùng giờ server. Năm phút chuẩn bị nằm trong mười phút đầu, không cộng thêm.

## Quyền giữ hàng

Chỉ thu hồi khi đơn còn `assigned`/`picking_up`, chưa có `actual_picked_up_at`, chưa có bằng chứng nhận hàng, chưa có yêu cầu bàn giao/trả hàng. Sau nhận hàng, mất GPS tạo hồ sơ CSKH và giữ nguyên tài xế. Đến điểm lấy hoặc đã xác nhận xuất phát thì kết thúc bộ đếm chưa xuất phát; dừng đèn đỏ không khởi động lại bộ đếm đó.

Popup xuất phát và thẻ giám sát đọc cả `pickup_arrived_at` đã được server xác
nhận trên đơn, bên cạnh trạng thái GPS. Khi mốc đến nơi thuộc phân công hiện
tại, popup đang mở tự đóng và không hiện lại trong lúc RPC giám sát cập nhật
chậm. Không dùng mốc đến nơi trước lúc nhận phân công mới. Cảnh báo mất GPS
và xử lý thu hồi từ server vẫn hoạt động độc lập.

## Vị trí và thời gian

GPS hợp lệ có độ chính xác ≤50m, được đo trong 90 giây gần nhất và không lặp/thứ tự ngược. Server ghi thời điểm nhận. Xuất phát cần dịch chuyển tối thiểu 100m sau khi trừ sai số và được xác nhận bởi hai mẫu cách nhau ít nhất 10 giây. Tại điểm lấy: khoảng cách cộng sai số ≤100m. Loại bước nhảy vượt 35m/s cộng biên sai số 100m.

Điện thoại đứng yên vẫn phải lấy GPS mới định kỳ; không gửi lại vị trí đã cache để giả lập kết nối còn tốt. Ngoài stream khi di chuyển, client lấy mẫu mới mỗi 15 giây khi chưa mở điều hướng, đang ở màn điều hướng hoặc chờ nhận hàng; service Android tiếp tục lấy mẫu khi app ở nền. RPC được gọi trước bộ lọc khoảng cách của pipeline ingest, tối đa một lần mỗi 5 giây cho một đơn trên mỗi instance.

Chế độ demo gửi vị trí mô phỏng hiện tại với thời điểm mới. Nút **Bắt đầu / Đang chạy** điều khiển mô phỏng chuyển động; khối **Giám sát hành trình** thể hiện trạng thái và có nút **Khôi phục GPS** khi thiếu mẫu mới. Thiếu GPS quá 90 giây được hiển thị cho tài xế; các mốc xử lý vẫn là 5/9/10 phút. R2 tiếp tục lưu lịch sử theo pipeline hiện có.

## Thu hồi và ETA

Khóa đơn và kiểm tra quyền giữ hàng trước khi xử lý. Hoàn giữ cọc COD bằng ledger hiện có nếu có. Đơn quay lại `pending`, giữ nguyên mã đơn/thanh toán, mở cửa sổ tìm tài xế mới 15 phút, loại tài xế cũ khỏi danh sách mời của đơn đó. Không tính sự cố này vào lượt từ chối và không tự khóa nhận đơn. ETA và hạn giao của tài xế cũ được xóa; tài xế mới tính lại một lần. Chỉ bỏ 5 phút chuẩn bị khỏi ETA nếu xuất phát trong 5 phút đầu.

## CSKH và trao đổi

Sự cố xử lý ở phút 10 tạo hai hồ sơ ưu tiên cao, hạn phản hồi 10 phút: một của tài xế và một của khách hàng. Hai người trao đổi riêng với CSKH, không đọc hội thoại của nhau hoặc ghi chú nội bộ. Tin mở đầu hiển thị tác giả **Hệ thống**, nêu nguyên nhân, mốc nhận đơn/GPS hợp lệ cuối/xuất phát/phát hiện và cách xử lý. Nội dung được giữ trong hội thoại ngay cả khi tài xế mới làm reset trạng thái giám sát trên đơn. Sự cố mất GPS lặp lại khi đang giữ hàng tái sử dụng hồ sơ còn mở; hồ sơ đã đóng thì tạo hồ sơ mới.

Hồ sơ tài xế vẫn có thể nhắn sau khi phân công bị thu hồi. Nhân viên tiếp nhận hồ sơ theo luồng hiện tại; tên, số điện thoại và email người yêu cầu lấy qua RPC dành riêng cho CSKH/Admin, không dựa vào tài xế hiện tại của đơn. Khối thông tin đơn cập nhật bằng Realtime, có polling dự phòng; thẻ giám sát hiển thị trạng thái, nguyên nhân và các mốc thời gian. Tài xế cũ chỉ nhận trạng thái đã thu hồi và mã hồ sơ của mình, không đọc GPS/phân công của tài xế mới.

## Supabase đã áp dụng

Người dùng đã duyệt riêng **“Cho phép áp dụng SQL và GPS”** ngày 11/10/2026. Bản đề xuất được lưu tại [driver_monitoring_proposal.sql](driver_monitoring_proposal.sql); mã triển khai theo các migration đã áp dụng:

- [20261011021932_driver_assignment_monitoring.sql](../supabase/migrations/20261011021932_driver_assignment_monitoring.sql): trạng thái, ingest, cron, hồ sơ và liên hệ.
- [20261011024717_driver_monitoring_case_lock_and_readback.sql](../supabase/migrations/20261011024717_driver_monitoring_case_lock_and_readback.sql): tránh chờ khóa hồ sơ khi cron đang khóa đơn; phân biệt thu hồi giám sát với đổi tài xế thông thường.
- [20261011030731_driver_monitoring_incident_timing.sql](../supabase/migrations/20261011030731_driver_monitoring_incident_timing.sql): giữ các mốc GPS/xuất phát trong tin sự cố sau khi đổi tài xế.

Không thêm bảng. Thêm một cột JSON trạng thái hiện tại `orders.driver_monitoring` vì `delivery_eta` bị Edge Function ghi đè toàn snapshot và có vòng đời dự đoán riêng. Chỉ giữ vị trí neo/vị trí mới nhất, không chứa lịch sử GPS. Bổ sung RPC ghi mẫu hợp lệ, đọc trạng thái, đọc liên hệ người yêu cầu; trigger giữ dữ liệu server; cron 5 giây; mở check constraint tác giả tin hệ thống và nhánh tạo hồ sơ nội bộ. RLS và role người dùng giữ nguyên. RPC có kiểm tra người dùng/đối tượng và không cấp quyền cho `anon`; client không được tự sửa trạng thái giám sát hoặc giả mạo tác giả Hệ thống.

Không bật thu hồi cho đơn đã có tài xế trước rollout, tránh phạt các phiên cũ không có dữ liệu giám sát. Các phiên nhận đơn mới mới được khởi tạo.

Security Advisor so với trước thay đổi ghi nhận thêm ba RPC có quyền `authenticated` và `SECURITY DEFINER`: `get_order_driver_monitoring`, `get_support_ticket_contacts`, `record_driver_monitoring_position`. Đây là các API được chủ ý cấp cho người đã đăng nhập; từng RPC kiểm tra vai trò/quyền trên đơn hoặc hồ sơ, và đã kiểm thử quyền thực. Không phát sinh quyền gọi cho `anon` hay cảnh báo RLS mới. Quy tắc và hướng xử lý cảnh báo: [Supabase Database Linter 0029](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).

## Kịch bản kiểm tra trên app

Tải lại cả Delivery App và Operations Web rồi **tạo/nhận một đơn mới**. Dùng hai tài khoản tài xế khác nhau cùng tài khoản khách hàng và CSKH; chọn điểm lấy cách vị trí nhận đơn trên 100m. Thời gian lấy theo server, không đổi đồng hồ điện thoại để rút ngắn kịch bản.

| Tình huống | Thao tác | Kết quả cần thấy |
| --- | --- | --- |
| Nhận đơn rồi chưa đi | Giữ app có mạng/GPS mới, không bắt đầu mô phỏng hoặc di chuyển | Nhắc phút 5, cảnh báo phút 8; phút 10 đơn quay lại tìm tài xế, mỗi lần xử lý chỉ một lần |
| Xuất phát trong 5 phút đầu | Di chuyển đủ khoảng cách và có hai mẫu hợp lệ | Kết thúc nhắc xuất phát; chỉ bỏ 5 phút chuẩn bị trong ETA, các thành phần còn lại giữ nguyên |
| Xuất phát sau phút 5, trước phút 10 | Di chuyển đủ khoảng cách | Không thu hồi vì chưa xuất phát; không bỏ 5 phút chuẩn bị khỏi ETA |
| Đang chờ tại điểm lấy | Đến vùng điểm lấy, giữ GPS có cập nhật | Không thu hồi vì đứng yên/chưa xuất phát |
| Mất GPS trước nhận hàng | Tắt quyền GPS hoặc mạng trên thiết bị tài xế | Thiếu mẫu mới hiện trạng thái mất cập nhật; nhắc 5, cảnh báo 9, thu hồi ở phút 10 kể từ mẫu hợp lệ cuối |
| Khôi phục GPS trước phút 10 | Bật lại GPS/mạng, nhấn Khôi phục GPS khi cần | Mẫu hợp lệ mới xóa đợt mất GPS; bộ đếm chưa xuất phát vẫn tính từ lúc nhận đơn |
| Mất GPS sau Gạt nhận hàng | Nhận hàng hoàn tất rồi ngừng cập nhật GPS | Giữ nguyên tài xế/đơn đang giao; ở phút 10 tạo hồ sơ CSKH xác minh |
| Tài xế mới nhận đơn bị thu hồi | Nhận bằng tài khoản tài xế khác | Cùng mã đơn/thanh toán, phiên giám sát mới; ETA tính lại một lần cho phân công mới |
| CSKH xử lý sau đổi tài xế | Mở hồ sơ tài xế cũ, tiếp nhận, nhắn phản hồi | Liên hệ vẫn là tài xế cũ; tin Hệ thống và mốc sự cố còn đủ; hai bên tiếp tục chat |
| Quyền hội thoại | Mở hồ sơ khách/tài xế bằng từng tài khoản | Mỗi người chỉ đọc hồ sơ của mình; CSKH đọc được hai hồ sơ và ghi chú nội bộ |

Khi thiết bị tài xế mất mạng, không thể nhận cảnh báo ngay trên thiết bị đó. Server vẫn xử lý đúng mốc; khi kết nối lại, app đọc trạng thái thu hồi và thông báo/hồ sơ đã lưu. Mốc thực thi có thể chậm vài giây theo nhịp cron hoặc lúc khóa giao dịch đang bận.

## Xác minh tự động

[driver_monitoring_regression.sql](../supabase/tests/driver_monitoring_regression.sql) chạy trong giao dịch rollback, đã kiểm tra:

- Đứng yên: 5/8/10 phút; nhắc một lần, thu hồi một lần.
- Xuất phát sớm/đến điểm lấy: không thu hồi vì chưa xuất phát; ETA chỉ bỏ 5 phút chuẩn bị khi phù hợp.
- Mất GPS 5/9/10 phút; khôi phục trước hạn xóa bộ đếm mất GPS.
- Đã nhận hàng hoặc có bằng chứng nhận: chỉ cảnh báo và CSKH, giữ người giữ hàng.
- Chạy lại cron, hai nguyên nhân đồng thời, mẫu lặp/cũ/sai số lớn: không xử lý kép.
- Ví COD trả phần giữ đúng một lần; thanh toán/mã đơn giữ nguyên.
- Tài xế mới nhận: trạng thái/ETA mới; tài xế cũ chỉ đọc hồ sơ của mình.
- CSKH đọc đúng người yêu cầu cũ, tiếp nhận và chat hai chiều realtime; khách/tài xế không đọc hồ sơ người khác.

Phân quyền SELECT/INSERT/UPDATE cũng được kiểm tra bằng `SET LOCAL ROLE authenticated`: tài xế cũ không đọc đơn/phân công mới hoặc ghi chú nội bộ, không giả mạo Hệ thống, không làm mới GPS cho tài xế mới; client không tự sửa JSON giám sát. Kiểm thử SQL xác nhận ghi/đọc tin và quyền; việc giao tin qua WebSocket trên nhiều thiết bị cần kiểm tra theo kịch bản app ở trên.

Kiểm thử giới hạn từ chối hết hạn cũng đã chạy lại để xác minh luồng lời mời còn hoạt động. Analyze tập trung Delivery/Operations đạt. Các test domain, ingest GPS đứng yên, cảnh báo/khôi phục, vòng đời điều hướng/hủy/trả hàng, liên hệ CSKH và thông tin đơn đạt. Preview Flutter thực đã render màn MAP/DETAILS ở 320/390px với cỡ chữ 100%/160%, mất GPS khi giữ hàng và hội thoại CSKH ở 882/1280px; phần nền bản đồ trong preview được thay bằng nền tĩnh.

Cron đã được xác nhận bật, lịch `5 seconds`, các lượt chạy gần nhất thành công. Chưa chạy toàn bộ suite/build phát hành, chưa kiểm tra GPS nền trên điện thoại Android/iOS thật hoặc giao dịch đồng thời bằng nhiều kết nối thật. Android tái sử dụng foreground service hiện có; iOS chưa bổ sung cơ chế theo dõi nền mới.
