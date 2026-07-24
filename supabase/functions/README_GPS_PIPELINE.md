# GPS pipeline (Redis + Queue + Postgres)

## Kiến trúc

```
Driver GPS
  → client throttle (5s / 25m)
  → Edge `ingest-driver-location`
       → Redis GEO + latest
       → Redis LIST queue history
       → UPDATE drivers (max ~8s/lần)  ← Supabase Realtime khách
  → Edge `flush-gps-history` (cron / manual)
       → bulk INSERT driver_locations
```

Fallback (không Redis/Edge): client UPDATE drivers thưa + bulk `driver_locations` local queue.

## Secrets (Supabase Edge)

- `UPSTASH_REDIS_REST_URL`
- `UPSTASH_REDIS_REST_TOKEN`
- `SUPABASE_SERVICE_ROLE_KEY` (thường có sẵn)
- `SUPABASE_URL`, `SUPABASE_ANON_KEY` (thường có sẵn)

## Deploy

```bash
supabase functions deploy ingest-driver-location
supabase functions deploy flush-gps-history
supabase functions deploy find-nearest-drivers-redis
```

Gợi ý cron (mỗi phút): gọi `flush-gps-history` với service role.

## Kafka

Chưa dùng. Khi throughput rất lớn: thay Redis LIST bằng Kafka topic + consumer bulk insert.
