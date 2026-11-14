# Lời mời tài xế chỉ hiển thị toàn màn hình

## Hành vi

- `DriverIncomingOfferHost` tại shell tiếp tục mở lời mời trên root Navigator,
  phủ các tab, drawer và màn hình phụ. Giữ thời hạn server, âm báo/rung,
  nhận đơn, bỏ qua và tự đóng khi lời mời hết hạn hoặc bị thu hồi.
- Tổng quan không dựng banner lời mời hoặc card nhận đơn. Danh sách công việc
  chỉ hiển thị đơn đã nhận, gồm đơn đang giữ/chờ giao lại. Thống kê tổng hợp
  vẫn được cập nhật như trước.
- Trước đây Tổng quan dựng banner/card trong cùng frame nhận dữ liệu realtime,
  còn host mở route sau frame đó, khiến lời mời lóe lên ở Tổng quan.

## Setup và kiểm tra

Không thêm dependency, biến môi trường, migration hoặc bước deploy backend.
Áp dụng cùng mã nguồn Flutter dùng chung cho app tài xế.

Chạy tại `packages/giaohang_mobile`:

```sh
flutter test --no-pub test/driver_dashboard_offer_visibility_test.dart test/driver_incoming_offer_host_test.dart test/driver_incoming_offer_layout_test.dart test/driver_cancellation_integration_ui_test.dart test/driver_recipient_hold_test.dart
flutter analyze --no-pub lib/features/driver/screens/home/widgets/driver_data_body.dart test/driver_dashboard_offer_visibility_test.dart
```

Test Tổng quan kiểm tra từng frame khi stream lời mời chuyển từ rỗng sang có đơn
ở 320/390/1024dp và giữ đơn đã nhận. Các test host/layout kiểm tra màn hình phủ,
thời hạn, nhận/bỏ qua và bố cục. Chưa thay thế kiểm tra realtime trên thiết bị thật.

Đã kiểm chứng 44 test trong các file trên và analyze ba file Dart thay đổi;
đã xem ảnh render Tổng quan 390dp khi stream có lời mời. Chưa chạy full suite,
build hoặc kiểm thử trên thiết bị thật.
