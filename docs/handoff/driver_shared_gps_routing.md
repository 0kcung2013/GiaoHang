# GPS chung và chuyển tuyến giao lại

Triển khai Flutter ngày 2026-10-30, theo luồng được người dùng duyệt: tài xế đang
ở X khi giao B, khách A gọi nhận hàng sớm, bấm **Bắt đầu giao lại A** thì marker
giữ tại X và tuyến mới đi từ X đến điểm giao A. Trạng thái, thời hạn và giới hạn
hai đơn dùng các RPC đã triển khai trước đó.

## Nguồn vị trí

- `driverActiveGpsProvider` chạy ở Driver Shell: một subscription GPS cho phiên
  tài xế, nhận thay đổi thiết bị và lấy mẫu bổ sung mỗi 5 giây. Mở/đóng MAP hoặc
  chuyển đơn không tạo lại subscription.
- `driverPositionPublisherProvider` giữ tọa độ/capture chung, ingest cho đơn ưu
  tiên và broadcast cả hai đơn đang nhận với nguyên tọa độ và timestamp capture.
  Các lần gửi được tuần tự hóa; phản hồi cũ không phát lại marker cũ sau mẫu mới.
- Màn giao giữ tiến độ/tuyến riêng; không khôi phục lat/lng hay index của session
  riêng thành vị trí hiện tại. Chưa có capture mới thì chỉ hiển thị vị trí gần
  nhất từ profile kèm nhãn đang cập nhật; GPS thực chưa đủ mới thì chưa tính tuyến
  hoặc mở xác nhận. Capture mới xác định lại vùng đến nơi của đơn được chọn.
- Web ở `deviceGps` dùng GPS trình duyệt. Chỉ mô phỏng khi tài xế chọn demo hoặc
  đơn thuộc kịch bản traffic demo rõ ràng. Mô phỏng tiếp từ vị trí chung hiện tại.
- Marker tài xế giữ nguyên GPS, không snap vào polyline. Màn khách hàng cũng giữ
  tọa độ nhận được; animation chỉ nội suy giữa hai mẫu, không chiếu sang tuyến.

## Polyline

Chỉ vẽ một tuyến xanh từ vị trí chung đến điểm cần đến của đơn đang ưu tiên:
điểm giao khi `delivering`, điểm lấy khi chưa nhận hàng. Điểm đến của đơn còn
lại có marker xám, không vẽ thêm đường. Khi chuyển đơn hoặc lệch tuyến trên
60 m, bỏ tuyến không còn phù hợp và gọi OSRM từ vị trí hiện tại. Marker giữ
tọa độ capture trong lúc **Đang tìm đường**.

Kết quả OSRM cũ bị bỏ qua sau khi đổi đơn/chặng. Nếu tài xế đã di chuyển khỏi
tuyến khi kết quả về, tính lại từ điểm mới. Không có đường hoặc mất mạng thì
báo thử lại, không dùng đường thẳng thay đường bộ. Traffic demo chỉ tái sử dụng
geometry dự báo khi vị trí hiện tại còn nằm trên geometry phù hợp.

## Setup và xử lý sự cố

Không thêm dependency, biến môi trường hay secret. Không thay schema, RPC, RLS,
Edge Function hoặc cấu trúc GPS/R2 trong lần sửa này. Lịch sử ingest gắn đơn ưu
tiên, không nhân bản chunk sang đơn kia. Giám sát hai đơn dùng RPC hiện có.

Cần hot restart hai app dùng `giaohang_mobile` hoặc phát hành bản Flutter mới;
không áp dụng lại migration giữ đơn. Cấp quyền GPS cho trình duyệt/điện thoại.
Muốn thử di chuyển ảo thì chọn demo trong công cụ kiểm tra vị trí; chạy Web
không tự bật mô phỏng. Ngưỡng active GPS vẫn là accuracy ≤50 m, capture không
cũ quá 90 giây/tương lai quá 15 giây. Tolerance 200 m của online chờ đơn không
được dùng để xác nhận giao nhận.

Marker đứng yên: kiểm tra quyền, chế độ, accuracy và timestamp capture chung.
Marker đúng nhưng thiếu tuyến: kiểm tra kết nối OSRM. Không reset tọa độ, thời
hạn hay tiền của đơn thật để ép hiện đường. Nếu cần rollback, giữ dữ liệu server
và xử lý client; quay lại code khôi phục tọa độ từng đơn sẽ tái tạo lỗi này.

## Kiểm chứng

Test dùng widget/provider thật với routing/transport được kiểm soát; không thao
tác giao nhận hay thay đổi vị trí của tài xế thật.

82 test tập trung trong 12 file đã đạt (lượt cuối chạy lại file render sau khi
nạp font fixture); analyze 12 mục vừa sửa không có vấn đề. Không dùng tổng số
test này để kết luận độ chính xác GPS ngoài thực địa.

| Trường hợp | Kết quả |
|---|---|
| B → A → B → A, GPS thực và demo được chọn | Marker giữ X; request bắt đầu từ X, kết thúc đúng đích |
| Session A còn GPS/cờ đến nơi cũ, danh sách đơn chưa tải | Không dùng tọa độ A làm vị trí tài xế |
| Tuyến B về muộn sau khi mở A | Không ghi đè tuyến A |
| Lệch tuyến, OSRM lỗi | Marker ở GPS mới; bỏ tuyến cũ, không dựng đường thẳng |
| Cold start chưa có capture | Chờ GPS; capture mới mở tuyến từ điểm mới |
| Đổi đơn, mở/đóng MAP | Một subscription GPS tiếp tục hoạt động |
| GPS cũ, sai số lớn, mẫu sai thứ tự | Không cập nhật bằng mẫu không hợp lệ |
| Mạng chậm, hai đơn cùng tài xế | Cùng tọa độ và timestamp trong broadcast hai đơn |
| Demo B mất quyền ưu tiên | Không phát vị trí đè lên A |
| Polyline khách hàng nằm ở đường khác | Marker giữ tọa độ tài xế nhận được |
| Lấy hàng → giao hàng, retry bàn giao | Giữ luồng xác nhận hiện có |

Ảnh widget: `artifacts/driver_shared_gps_route_a.png`, 390×844 với tile fixture.
Chưa thử di chuyển ngoài thực địa, app bị hệ điều hành kill, nền Android/iOS
hoặc E2E hai tài khoản thật. Không chạy full suite/build phát hành.
