# Driver location mode selector

## Mục tiêu

Cho tài xế demo chuyển qua lại giữa hai nguồn vị trí ngay trong sheet
`Kiểm tra vị trí`:

- GPS thật của thiết bị để chạy thử tuyến đường gần vị trí hiện tại.
- Tọa độ demo TP.HCM cố định đã cấu hình theo email tài xế để chạy các tuyến
  demo có sẵn.

Không tạo tọa độ demo mới và không thay đổi Supabase schema, RLS, migration
hoặc Edge Function.

## Hành vi

- Tài khoản demo tiếp tục mặc định dùng tọa độ TP.HCM theo email như hiện tại.
- Bỏ hai hành động `Đo lại GPS` và `Đồng bộ`.
- `Dùng vị trí hiện tại` đọc một mẫu GPS mới, chuyển phiên app sang chế độ GPS
  thiết bị và gửi chính tọa độ đó lên pipeline location.
- `Dùng vị trí demo TP.HCM` chuyển phiên app về chế độ demo và gửi tọa độ cố
  định của email hiện tại lên pipeline location.
- Chế độ đã chọn có hiệu lực với các lần publish GPS nền và GPS navigation tiếp
  theo, tránh việc lựa chọn vừa bấm bị producer khác ghi đè.
- Chế độ chỉ tồn tại trong phiên app. Khởi động lại app sẽ trở về hành vi demo
  theo email hiện có.
- Nếu email không có tọa độ demo, nút demo bị vô hiệu hóa và UI giải thích ngắn
  gọn; nút GPS thật vẫn hoạt động.
- Sau mỗi thao tác thành công, sheet cập nhật tọa độ đang lưu và hiển thị thông
  báo nguồn vị trí vừa áp dụng. Lỗi quyền/GPS/network được hiển thị inline.

## Thiết kế kỹ thuật

### Trạng thái và policy

Thêm enum chế độ vị trí tài xế gồm `demoHcm` và `deviceGps`, cùng Riverpod state
provider cấp phiên. Provider mặc định là `demoHcm` để giữ nguyên hành vi hiện
tại.

Policy thuần chịu trách nhiệm:

- Quyết định raw GPS có cần áp mapping demo hay không.
- Chọn `LocationIngestCoordinateSpace.rawGps` cho chế độ demo và
  `LocationIngestCoordinateSpace.mapCoordinates` cho GPS thật.
- Trả về tọa độ demo đã cấu hình theo email khi người dùng chọn demo.

### Các producer vị trí

Các đường publish raw GPS của dashboard/background, availability và navigation
đọc cùng provider chế độ. Chế độ `deviceGps` phải bypass mapping email; chế độ
`demoHcm` giữ nguyên mapping hiện tại. Tọa độ simulation/session đã ở map
coordinate space nên không bị biến đổi thêm.

### Sheet Kiểm tra vị trí

Sheet tiếp tục tải hồ sơ tài xế, GPS thiết bị, tọa độ demo và vị trí đang lưu để
hiển thị bản đồ so sánh. Hai nút mới dùng chung một hàm publish theo nguồn đã
chọn, sau đó refresh hồ sơ tài xế.

Hai nút xếp dọc để an toàn ở màn hình 375 dp và text scale lớn:

- Nút phụ viền xanh: `Dùng vị trí hiện tại`.
- CTA cam: `Dùng vị trí demo TP.HCM`.

Nút đang chạy hiển thị trạng thái riêng và khóa cả hai hành động để tránh gửi
đồng thời. UI dùng `AppColors`, `AppTextStyles`, `AppSpacing` và `AppRadius`.

## Kiểm thử

- Unit test policy: mặc định demo áp mapping; GPS thiết bị bypass mapping; map
  coordinates không bị offset lần hai.
- Widget test action area: có hai nhãn mới, không còn `Đo lại GPS`/`Đồng bộ`, và
  trạng thái loading/disabled đúng.
- Test tập trung cho dashboard/navigation nếu chữ ký resolver thay đổi.
- Chạy `flutter test` chỉ với các test liên quan và `flutter analyze` trên các
  file vừa sửa theo phạm vi verification của dự án.

## Ngoài phạm vi

- Lưu chế độ qua lần khởi động tiếp theo.
- Thay đổi ba tọa độ demo TP.HCM hiện có.
- Tạo tuyến đường, đơn hàng hoặc dữ liệu demo mới.
- Thay đổi database hoặc backend.
