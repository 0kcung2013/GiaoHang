# Driver Location Addresses Design

## Goal

Trong hộp thoại **Kiểm tra vị trí** của tài xế, thay toàn bộ chuỗi tọa độ bằng địa chỉ dễ đọc cho GPS thiết bị, vị trí demo TP.HCM và vị trí đang lưu trên Supabase.

## Scope

- Chỉ thay đổi cách trình bày và tra cứu địa chỉ trong Delivery App.
- Không thay đổi Supabase schema, RLS, migration, Edge Function hay dữ liệu vị trí.
- Không thêm dependency; tiếp tục dùng Nominatim/OpenStreetMap và HTTP client hiện có.

## Architecture

Di chuyển `ReverseGeocodingService` và `ReverseGeocodeResult` đang nằm trong feature tạo đơn của Customer sang `lib/core/` để Customer và Driver dùng chung, tránh phụ thuộc chéo giữa các feature và tránh nhân bản logic.

Hộp thoại Driver giữ trạng thái địa chỉ theo khóa tọa độ đã chuẩn hóa. Mỗi tọa độ duy nhất chỉ được tra cứu một lần trong vòng đời hộp thoại; các tọa độ trùng nhau dùng chung kết quả. Các yêu cầu được thực hiện tuần tự để không tạo burst request tới dịch vụ công cộng.

## UI behavior

- Đổi tiêu đề khu vực từ **Đối chiếu tọa độ** thành **Đối chiếu vị trí**.
- Ba thẻ giữ nguyên nhãn, biểu tượng, màu semantic và mô tả hiện có.
- Dòng cuối của mỗi thẻ hiển thị địa chỉ cụ thể bằng typography token hiện có, tối đa ba dòng.
- Trong lúc tra cứu, hiển thị **Đang xác định địa chỉ…**.
- Khi không có tọa độ hoặc reverse geocoding thất bại, hiển thị **Không xác định được địa chỉ**.
- Không hiển thị tọa độ số trong bất kỳ trạng thái hoặc fallback nào.

## Data flow and errors

Khi hộp thoại nhận hoặc cập nhật GPS thiết bị, vị trí demo hay vị trí lưu trên Supabase, nó tạo danh sách các tọa độ chưa có trong cache, gọi service chung và cập nhật đúng thẻ nếu widget còn mounted. Lỗi mạng, timeout, phản hồi không hợp lệ và kết quả rỗng đều được chuyển thành fallback thân thiện; lỗi không làm đóng hộp thoại và không ảnh hưởng cơ chế chọn nguồn vị trí.

## Testing

- Cập nhật import của các test reverse-geocode hiện có sang `core/` để bảo vệ parsing/format địa chỉ.
- Thêm widget test cho thẻ vị trí: hiển thị địa chỉ, trạng thái loading và fallback; xác nhận chuỗi tọa độ không xuất hiện.
- Không gọi Nominatim thật trong test.
- Chỉ chạy test và analyze tập trung cho các file/feature bị tác động.

