# Điểm lấy tham chiếu khi chọn điểm giao

Triển khai 2026-11-06. Luồng: Tạo đơn → chọn điểm lấy → chọn điểm giao.

- Màn chọn điểm giao nhận `pickupSelection` từ form tạo đơn. Hai điểm dùng chấm
  nhỏ 14 px, viền trắng; điểm lấy xanh, điểm giao cam, không có nhãn nổi trên map.
  Điểm lấy giữ cố định, có thẻ địa chỉ “Điểm lấy đã chọn” phía trên bản đồ.
- Nếu chưa có điểm giao, bản đồ bắt đầu ở điểm lấy; không cần gọi GPS chỉ để mở
  bản đồ. Nếu sửa điểm giao cũ, giữ đúng tọa độ/địa chỉ/ghi chú của điểm giao đó.
- Bản đồ thu phóng để thấy hai điểm khi mở hoặc chọn địa chỉ qua tìm kiếm, đã lưu,
  gần đây hay định vị. Nút “Xem hai điểm” và thẻ địa chỉ điểm lấy cho phép xem lại.
- Camera luôn giữ ghim đang chỉnh ở trung tâm. Việc xem hai điểm chỉ đổi mức
  zoom, không chuyển điểm giao sang trung điểm hai tọa độ và không ghi đè địa chỉ.
- Kéo bản đồ vẫn chỉnh điểm giao như trước; điểm lấy không di chuyển. Khi zoom
  hoặc kéo xa làm điểm lấy ra ngoài khung, dùng “Xem hai điểm” để xem lại.
- Thẻ điểm lấy, tìm kiếm, tabs và bản đồ/form cuộn chung; tiêu đề và nút xác nhận
  nằm cố định. Bấm “Xem hai điểm” cuộn tới bản đồ để thấy đầy đủ hai marker ngay
  cả trên máy ngắn/chữ lớn. Nút xác nhận tự tăng chiều cao khi nhãn xuống dòng.
  Khi bàn phím mở, tạm ẩn thẻ điểm lấy
  và hàng tab để giữ chỗ cho tìm kiếm/nút xác nhận; đóng bàn phím thì hiện lại.
- Chọn điểm lấy, sổ địa chỉ và các luồng không truyền điểm lấy tham chiếu vẫn hoạt
  động như cũ. Đóng/hủy picker không thay đổi các điểm trong form tạo đơn.

## Cấu hình và setup

Không đổi Supabase, dependencies, secrets hoặc API. Chạy lại app khách hàng với
code mới. OSM tiles, tìm kiếm Photon và reverse geocoding dùng cấu hình hiện có.
`tileProvider` tùy chọn trên sheet/map chỉ phục vụ thay thế nguồn tile khi kiểm
tra; mặc định runtime vẫn tải tiles OSM.

Các điểm tích hợp:

- `create_order_screen.dart` → `OrderMapPickerController.pick(pickupSelection: …)`.
- `MapPickerSheet` giữ dữ liệu tham chiếu và thẻ địa chỉ.
- `MapAddressTab`, `AddressMapDot`, `PickupReferenceCard` render UI.
- `PickupContextCameraFit` và controller thực hiện camera fit không đổi lựa chọn.

## Kiểm tra / xử lý sự cố

Từ `packages/giaohang_mobile`, chạy tập trung:

```powershell
flutter test --no-pub test/delivery_picker_pickup_context_test.dart test/address_picker_controller_test.dart test/address_picker_ui_test.dart test/traffic_demo_selection_test.dart
```

Kiểm tra hai tọa độ trong khung, ghim lấy cố định, tìm địa chỉ mới vẫn giữ điểm lấy,
nút xem lại không đổi địa chỉ/ghi chú, form thực sự truyền đúng điểm lấy mới nhất,
320/390 px và landscape, chữ 160%, mở/đóng bàn phím, luồng sổ địa chỉ.
Ảnh render: `artifacts/delivery_picker_pickup_context.png`; test dùng tile trong
suốt để giữ kiểm tra độc lập mạng, nên ảnh kiểm tra không có nền đường thực tế.

Nếu không thấy điểm lấy, xác nhận form đã có `_pickupSelection`, đang chọn điểm
giao và không ở luồng sửa sổ địa chỉ. Nếu vừa kéo/zoom ra xa, bấm “Xem hai điểm”.
Nếu geocoding lỗi, vẫn dùng thông báo/thử lại của picker hiện tại; không tự đổi
địa chỉ hoặc lấy ghi chú của điểm lấy sang điểm giao.

Không chạy full suite/build phát hành hoặc kiểm tra trên điện thoại thật cho thay
đổi này. Muốn khôi phục UI cũ, bỏ truyền `pickupSelection` tại điểm gọi form;
không cần migration dữ liệu.

Kết quả: 13 test tập trung trong bốn file trên đã đạt; analyze các file thay đổi
không có vấn đề. Đã xem ảnh render 390 px và 320 px/chữ 160%; trên máy nhỏ nút
“Xem hai điểm” cuộn bản đồ vào khung nhìn, nút xác nhận xuống dòng không bị cắt.
