# GPS pipeline (Redis + Queue + Cloudflare R2)

## Kiến trúc

```
Driver GPS
  → client throttle (5s / 25m)
  → Edge `ingest-driver-location`
       → Redis GEO + latest
       → Redis LIST queue history
       → UPDATE drivers (max ~8s/lần)  ← Supabase Realtime khách
Cloudflare Worker Cron (mỗi phút)
  → Edge `flush-gps-history` (x-gps-ingest-secret)
       → JSONL gzip chunk → private R2 bucket
```

Chỉ điểm có `order_id` mới vào history queue. Object được nhóm theo đơn tại
`orders/{order_id}/gps/YYYY/MM/DD/{batch_id}.jsonl.gz`; GPS Online không có đơn chỉ cập
nhật `drivers.current_lat/current_lng`.

Fallback khi Edge tạm lỗi: client chỉ UPDATE `drivers` thưa để giữ Realtime và
buffer RAM có giới hạn để thử gửi lại Edge. Không ghi lịch sử GPS vào Postgres.

## Flush và thử lại

- Worker `giaohang-r2-gateway` chạy cron `* * * * *`, gọi Edge bằng secret GPS
  đã có. Không cần service role key trên Worker hoặc dịch vụ cron riêng.
- Mỗi lượt lấy tối đa 500 điểm cũ nhất từ `gps:history:queue`. Redis lock có
  thời hạn 180 giây ngăn hai lượt flush xử lý cùng lúc.
- Batch được chuyển nguyên tử vào `gps:history:processing`; chỉ xóa sau khi
  R2 xác nhận ghi thành công. Nếu bị ngắt hoặc R2 lỗi, lượt sau xử lý lại batch này.
- SHA-256 của batch tạo object key ổn định, tránh tạo object trùng khi thử lại.
- Điểm lỗi hoặc cũ hơn 14 ngày bị loại khỏi queue. Bucket GPS có lifecycle xóa
  object sau 14 ngày; không áp dụng thời hạn này cho ảnh nghiệp vụ.
- Log `[GpsArchive]` có `archived`, `discarded`, `objects`, `queue_remaining`;
  queue rỗng trả `queue_empty`, lượt đang có lock trả `busy`.

## Secrets (Supabase Edge)

- `UPSTASH_REDIS_REST_URL`
- `UPSTASH_REDIS_REST_TOKEN`
- `SUPABASE_SERVICE_ROLE_KEY` (thường có sẵn)
- `SUPABASE_URL`, `SUPABASE_ANON_KEY` (thường có sẵn)
- `R2_GATEWAY_URL`
- `R2_GPS_INGEST_SECRET`

## Deploy

```bash
supabase functions deploy ingest-driver-location
supabase functions deploy flush-gps-history --no-verify-jwt
supabase functions deploy find-nearest-drivers-redis
# Trong cloudflare/r2_gateway:
npx wrangler deploy
```

`flush-gps-history` tự kiểm tra chính xác secret trong handler. `GPS_INGEST_SECRET`
của Worker phải cùng giá trị với `R2_GPS_INGEST_SECRET` của Edge. Cron nằm trong
`cloudflare/r2_gateway/wrangler.jsonc`; thay đổi cron có thể cần thời gian lan
truyền trên Cloudflare trước lần chạy đầu tiên.

Kiểm tra sau deploy: lịch Worker có `* * * * *`, Edge có lượt POST thành công,
và R2 xuất hiện object GPS khi queue có điểm thuộc đơn trong 14 ngày gần nhất.
Không tạo GPS giả hoặc ghi thêm vào `driver_locations` để kiểm tra.

## Kafka

Chưa dùng. Khi throughput rất lớn: thay Redis LIST bằng Kafka topic + consumer ghi chunk R2.
