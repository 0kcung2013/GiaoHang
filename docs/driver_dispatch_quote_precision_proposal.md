# Lỗi lời mời GH-10199 / GH-10200

Trạng thái: người dùng đã duyệt riêng và bản sửa đã áp dụng trên Supabase lúc 10:04:56 ngày 10/10/2026 (giờ Việt Nam).

Migration: [20261010030456_driver_dispatch_quote_coordinate_precision.sql](../supabase/migrations/20261010030456_driver_dispatch_quote_coordinate_precision.sql).
Phiên bản file local khớp lịch sử migration trên Supabase.

## Bằng chứng ngày 10/10/2026

- `taixe@gmail.com` online, đã duyệt, GPS cập nhật mới; khóa nhận đơn cũ đã hết.
- Ví khả dụng 908.345đ, đủ khoản ứng 50.000đ; không có đơn giao/hoàn hoặc lời mời khác đang giữ.
- Cả hai đơn được `private.road_driver_candidates` trả về với tài xế này.
- Chạy đúng module routing bằng tọa độ thật: GH-10199 có tuyến 423,6m, GH-10200 có tuyến 505m; sai lệch snap đều dưới 100m.
- Trước khi sửa, cron chạy mỗi 5 giây và Edge trả HTTP 200 với `offered: 0, waiting: 2`.
- Trước khi sửa, `private.valid_pickup_road_quote` trả `false` ngay cả khi quote được tạo từ tọa độ chính đơn trong database.

## Nguyên nhân

Hàm xác thực trước khi sửa dùng `=` tuyệt đối cho hai tọa độ pickup kiểu `double precision`.
Kết quả truy vấn cho thấy `extra_float_digits = 0`: JSON làm tròn biểu diễn float8,
khi chuyển ngược về float8 thì khác các bit cuối của giá trị đang lưu.

GH-10199: latitude lưu `402610735bbcab2a`, sau JSON là `402610735bbcab0f`.
GH-10200: latitude lưu `402610c2b92e3e50`, sau JSON là `402610c2b92e3e36`.

[Tài liệu PostgreSQL](https://www.postgresql.org/docs/17/datatype-numeric.html#DATATYPE-FLOAT)
mô tả việc làm tròn khi `extra_float_digits = 0` và giới hạn của phép so sánh bằng cho số dấu phẩy động.

## Bản sửa đã áp dụng

SQL cụ thể: [driver_dispatch_quote_precision_proposal.sql](driver_dispatch_quote_precision_proposal.sql).

Chỉ thay hai phép `=` bằng kiểm tra chênh lệch tuyệt đối không quá `1e-9` độ.
Ngưỡng này rất nhỏ, chỉ bù sai số số học khi truyền cùng tọa độ qua JSON.
Giữ chữ ký, ACL và các kiểm tra quãng đường, tuổi quote, GPS nguồn cách vị trí hiện tại tối đa 30m.
Không thêm bảng/cột, đổi trạng thái đơn/tài xế, cấu hình toàn database hoặc deploy lại Edge Functions.

## Kiểm tra

- Tái hiện OSRM hai lần với tọa độ thực; kết quả được giữ tại `.tmp/gh10199_dispatch_replay.json`.
- Đã đối chiếu 14 ca chỉ đọc giữa biểu thức hiện có và hai phép so sánh đề xuất:
  quote đúng tọa độ sau JSON được nhận; sai điểm lấy, ngoài 2km, quote cũ/tương lai,
  tài xế đã di chuyển hoặc thời lượng âm vẫn bị từ chối.
- Kiểm tra trực tiếp hàm thực tế: [driver_dispatch_quote_precision_regression.sql](driver_dispatch_quote_precision_regression.sql).
  Trước khi sửa: 22/24 ca đạt, hai ca đúng điểm lấy thất bại.
  Sau migration: 24/24 ca đạt, bao gồm cả dữ liệu null, sai dạng và không hữu hạn.
- OID, owner, ACL, chế độ security invoker, thuộc tính STABLE và search_path của hàm giữ nguyên.
- Security/performance advisors đã đối chiếu trước/sau: không phát sinh finding mới; các finding cũ không thay đổi.
- Chỉ chạy kiểm tra SQL tập trung; không chạy full Flutter test suite hoặc build app vì không sửa Flutter.
- Chưa kiểm tra được lời mời thực tế sau khi sửa do không còn đơn đang trong thời hạn tìm tài xế.

Đơn hết 15 phút phải dùng luồng tìm lại tài xế hiện có; không tự gia hạn bằng cách sửa dữ liệu.

Lúc kiểm tra sau sửa, 10:06:08 ngày 10/10/2026 (giờ Việt Nam), cả hai đơn đã hết hạn tìm tài xế:
GH-10199 lúc 09:58:36, GH-10200 lúc 10:04:56. Cần tìm lại tài xế hoặc tạo đơn mới để kiểm tra lời mời thực tế.
