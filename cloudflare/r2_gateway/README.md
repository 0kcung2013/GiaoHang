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

## Kiểm tra nhanh

```bash
npm install
npm run check
node --test test/gps.test.js test/gps_scheduler.test.js ../../supabase/functions/flush-gps-history/archive_test.mjs
npm run dev
```
