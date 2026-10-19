# GiaoHang R2 Gateway

Worker này giữ hai bucket R2 ở chế độ private và là điểm duy nhất mà Flutter/Supabase Edge Functions dùng để truy cập object:

- `giaohang-media-private`: ảnh nghiệp vụ, không đặt lifecycle 14 ngày.
- `giaohang-gps-private`: các lô GPS dạng JSONL gzip, tự xóa sau 14 ngày.

Flutter chỉ nhận URL PUT/GET ngắn hạn do Worker ký. R2 access key và `SIGNING_SECRET` không được đưa vào app.

## Khởi tạo Cloudflare

```bash
npx wrangler r2 bucket create giaohang-media-private
npx wrangler r2 bucket create giaohang-gps-private
npx wrangler secret put SUPABASE_URL
npx wrangler secret put SUPABASE_ANON_KEY
npx wrangler secret put SIGNING_SECRET
npx wrangler secret put GPS_INGEST_SECRET
npx wrangler secret put R2_INTERNAL_SECRET
npx wrangler deploy
```

Trong R2 Dashboard, tạo lifecycle rule cho toàn bộ prefix của bucket `giaohang-gps-private`: xóa object sau 14 ngày. Không áp dụng rule này cho bucket media.

Thêm origin thật của Operations Web vào `ALLOWED_ORIGINS`. Không bật `r2.dev` hoặc public access cho hai bucket.

## Cấu hình ứng dụng

- Flutter mặc định dùng
  `https://giaohang-r2-gateway.sidat-giaohang.workers.dev`, nên `flutter run`
  và `flutter build` thông thường đều ghi media mới vào R2.
- `GIAOHANG_R2_GATEWAY_URL` chỉ dùng khi cần override sang Worker khác
  (ví dụ staging). Không có fallback ghi mới vào Supabase Storage.
- Edge Function `flush-gps-history`: đặt secrets `R2_GATEWAY_URL` và `R2_GPS_INGEST_SECRET` (cùng giá trị với `GPS_INGEST_SECRET` của Worker).
- Edge Function duyệt hồ sơ tài xế: đặt `R2_GATEWAY_URL` và `R2_INTERNAL_SECRET` để publish/xóa avatar mà không công khai bucket.
- URL/object cũ trong Supabase Storage vẫn được đọc trong giai đoạn
  chuyển tiếp; chỉ luồng ghi mới bị bắt buộc qua R2.

## Tự động lưu lịch sử GPS

`wrangler.jsonc` cấu hình cron `* * * * *`. Handler `scheduled` gọi Supabase
`flush-gps-history` mỗi phút bằng `GPS_INGEST_SECRET`; không cần service role key
trên Worker. Edge lấy batch từ Redis rồi gửi lại `/v1/gps/chunks` để ghi R2.

Batch có ID ổn định được ghi vào
`orders/{order_id}/gps/YYYY/MM/DD/{batch_id}.jsonl.gz`. Thử lại cùng batch ghi
cùng object key. Redis giữ batch đang xử lý đến khi R2 xác nhận thành công.
Chi tiết và các trường log nằm trong
[`README_GPS_PIPELINE.md`](../../supabase/functions/README_GPS_PIPELINE.md).

## Đọc lịch sử để giám sát hành trình

`POST /v1/gps/history` nhận `{ "orderId": "...", "cursor": "..." }`.
Tái sử dụng JWT Supabase, chỉ cho CSKH/Admin và kiểm tra quyền đọc đơn bằng
JWT của người gọi trước khi truy cập R2. Không dùng service-role để bỏ qua RLS.
Mỗi trang đọc tối đa 20 chunk theo nhóm tối đa 4 lượt đọc đồng thời, trả
`points`, `nextCursor`, `unavailableChunks`;
client đọc hết các trang, sắp xếp và loại mẫu trùng. Chỉ trả mẫu trong 14 ngày
gần nhất, không cache phản hồi, không thay đổi pipeline ghi hay lifecycle.
Mẫu mới có thể chưa xuất hiện cho đến khi cron flush hoàn tất. Không suy diễn
tuyến đi từ OSRM/AI khi thiếu dữ liệu. UI ngắt polyline khi thiếu mẫu >60 giây,
hai mẫu cách nhau >200m, đổi tài xế hoặc bước nhảy tương đương trên 150 km/h;
đây là quy tắc hiển thị,
không phải kết luận vi phạm.

`POST /v1/gps/archives` nhận `{ "cursor": "..." }` (cursor tùy chọn).
Chỉ CSKH/Admin được liệt kê các đơn thực sự có file GPS trong R2. Mỗi trang
quét tối đa 500 object, bỏ file ngoài khoảng ngày lưu 14 ngày và kiểm tra RLS
của các đơn bằng JWT người gọi trước khi trả `archives` và `nextCursor`.
Các trang có thể chứa cùng một đơn; client ghép `firstDay`, `lastDay`, `chunks`
rồi lấy thông tin đơn theo danh sách ID. Ngày ở đây là ngày UTC trong object
key, không phải ngày tạo đơn. Có file không bảo đảm còn mẫu hợp lệ ở thời điểm
mở: `/v1/gps/history` vẫn lọc từng mẫu theo giờ và thời hạn lưu chính xác.
API này chỉ đọc danh sách object; không thêm bảng, không đổi lịch ghi, bucket,
lifecycle hoặc nội dung chunk GPS.

Màn hình Giám sát giữ tạm tối đa 8 hành trình vừa mở trong bộ nhớ của phiên
màn hình. Đổi kích thước cửa sổ giữ bản đồ, tài xế đã chọn và mốc phát lại;
nút tải lại của hành trình loại dữ liệu tạm để đọc mới. Cache không ghi ra
ổ đĩa, không dùng chung giữa các phiên người dùng.

Khi mở đơn, bản đồ chọn GPS mới nhất đã lưu và lấy khung nhìn theo đoạn GPS
liên tục cuối cùng cùng điểm lấy/giao. Mẫu cũ bị gián đoạn vẫn giữ trong lịch sử;
“Xem toàn hành trình” lấy khung nhìn của tất cả mẫu. Nhãn thời điểm phân biệt
GPS đã lưu mới nhất với mốc đang xem lại; đây không phải vị trí trực tiếp.

## Kiểm tra nhanh

```bash
npm install
npm run check
node --test test/gps.test.js test/gps_scheduler.test.js ../../supabase/functions/flush-gps-history/archive_test.mjs
npm run dev
```
