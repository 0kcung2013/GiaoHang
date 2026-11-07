# GPS chờ bật Online và lỗi bị báo như PIN sai — 2026-11-03

## Nguyên nhân đã tái hiện

Ảnh lần này thuộc cửa sổ xác thực Online, khác thẻ cảnh báo trang chủ đã bỏ ở
`driver_presence_background.md`. Callback xác thực lấy GPS trước khi gọi RPC
PIN. Luồng cũ giới hạn việc này ở 8 giây và hủy watch riêng lúc hết hạn. Khi
fix đầu đến ở giây thứ 9, request đã bị hủy. Mỗi lần nhập lại PIN mở một
request lạnh mới; GPS lỗi cũng bị sheet xử lý như PIN sai và xóa sáu số.

Test dùng `LocationService(isWeb: true)` và fake geolocation platform đã tái
hiện lỗi timeout đúng chuỗi trong ảnh, vị trí đến muộn bị bỏ và PIN bị xóa.
Đây là lỗi client có thể tái hiện, không phải bằng chứng nguồn định vị máy
người dùng chắc chắn trả được tọa độ sau 8 giây.

## Thay đổi

- Acquisition Online Web có watch riêng, thời hạn tổng 30 giây. Không bị hủy
  bởi deadline 8 giây của các lần đọc GPS thông thường hoặc màn kiểm tra.
- Bắt đầu với high accuracy. Sau 8 giây, thử thêm request medium accuracy để
  browser có thể dùng nguồn định vị cân bằng/mạng; vẫn giữ watch đầu chờ fix.
  Đây là lựa chọn yêu cầu cho browser, không bảo đảm browser cung cấp một
  nguồn phần cứng/mạng cụ thể.
- Cả hai nguồn đều phải qua cùng kiểm tra: sai số tối đa 200 m, capture không
  cũ quá 90 giây hoặc tương lai quá 15 giây, tọa độ hợp lệ. Mẫu thô chưa đủ tốt
  được bỏ qua để tiếp tục chờ mẫu đạt yêu cầu; không nới ngưỡng hoặc dùng IP,
  vị trí lưu ở server, tọa độ giả hay GPS cũ làm vị trí hiện tại.
- Caller Online đồng thời dùng chung Future. Thành công/lỗi/hủy đều giải
  phóng timer và subscription của request, giữ nguyên tracking đang có.
  Đóng service thì hủy request đang chờ. Quyền bị chặn hoặc dịch vụ bị tắt
  kết thúc ngay; timeout thường và hành vi native Android/iOS không bị kéo dài.
- `OnlineLocationException` tách lỗi định vị khỏi lỗi PIN. Sheet giữ PIN khi
  lấy vị trí thất bại, không viền đỏ các ô PIN và có nút **Thử lại vị trí**.
  Lỗi PIN thật vẫn được xóa mã/cho nhập lại như trước. Trạng thái chờ ghi rõ
  đang xác thực và lấy vị trí. Sau khi hủy sheet, GPS về muộn không tiếp tục
  cấu hình PIN hoặc bật Online.

Luồng vẫn yêu cầu GPS hợp lệ trước khi gọi RPC bật Online. Không đổi PIN,
giới hạn thử sai, phê duyệt, ví, trạng thái nhiệm vụ hoặc hợp đồng backend.

## Setup, kiểm tra và khôi phục

Chỉ sửa Flutter client; không thêm dependency, biến môi trường hoặc secret,
không đổi RPC/schema/RLS/Edge Functions/R2. Cần hot restart hai phiên Driver
Web đang mở hoặc phát hành client mới. Không sửa trong pub-cache, không cần
reset tài khoản hoặc xóa dữ liệu trình duyệt.

Test tập trung: `driver_online_location_test.dart`,
`driver_online_pin_verification_sheet_test.dart`, `driver_presence_pin_test.dart`,
`location_acquisition_timeout_test.dart`, `driver_presence_session_test.dart`.
Lượt kiểm tra cuối: 33 test đạt; analyze chín file Dart không có lỗi.
Kiểm tra fix sau 8 giây, request medium không nới chất lượng, dọn request,
caller đồng thời, tracking đang chạy, timeout/bị chặn quyền, giữ PIN và retry,
PIN sai thật, setup và hủy sheet trước khi GPS về. UI lỗi định vị được render
ở 320×568, Galaxy S20 360×800 và 1024×768 với chữ 160%; ảnh test harness tại
`artifacts/driver_online_pin_location_retry.png`.

Computer Use không kết nối được native pipe trong lần này, nên chưa kiểm
chứng trên phiên Chrome của người dùng hoặc nguồn định vị Windows thực tế.
Browser/Windows không trả tọa độ thì code không thể tự tạo GPS hợp lệ. Khi
đối soát, phân biệt lỗi quyền, nguồn vị trí không trả fix và vị trí trả về sai
số vượt 200 m; không coi việc bật quyền là bằng chứng chắc chắn có fix.

Không chạy full suite hoặc build phát hành. Khôi phục bằng bản Flutter trước
của request Online và sheet; giữ các bản vá GPS nền/cancel watch không liên
quan. Không có dữ liệu server cần rollback.

Tham chiếu ý nghĩa `enableHighAccuracy` và options:
[MDN Geolocation](https://developer.mozilla.org/en-US/docs/Web/API/Geolocation/getCurrentPosition).
