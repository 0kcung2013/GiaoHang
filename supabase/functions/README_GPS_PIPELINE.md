# GPS pipeline (Redis + Queue + Cloudflare R2)

## Kiến trúc

```
Driver GPS
  → client throttle (5s / 25m)
  → Edge `ingest-driver-location`
       → Redis GEO + latest
       → Redis LIST queue history
       → UPDATE drivers (max ~8s/lần)  ← Supabase Realtime khách
  → Edge `flush-gps-history` (cron / manual)
       → JSONL gzip chunk → private R2 bucket
```

Chỉ điểm có `order_id` mới vào history queue. Object được nhóm theo đơn tại
`orders/{order_id}/gps/YYYY/MM/DD/*.jsonl.gz`; GPS Online không có đơn chỉ cập
nhật `drivers.current_lat/current_lng`.

Fallback khi Edge tạm lỗi: client chỉ UPDATE `drivers` thưa để giữ Realtime và
buffer RAM có giới hạn để thử gửi lại Edge. Không ghi lịch sử GPS vào Postgres.

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
supabase functions deploy flush-gps-history
supabase functions deploy find-nearest-drivers-redis
```

Gợi ý cron (mỗi phút): gọi `flush-gps-history` với service role. Bucket GPS phải
có lifecycle xóa object sau 14 ngày.

## Kafka

Chưa dùng. Khi throughput rất lớn: thay Redis LIST bằng Kafka topic + consumer ghi chunk R2.
