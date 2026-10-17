# GPS pipeline (Redis + Queue + Cloudflare R2)

## Kiến trúc

```
Driver GPS
  → client throttle (đơn active: 5s; online chờ đơn: 5s / 25m + heartbeat 60s)
  → Edge `ingest-driver-location`
       → Redis GEO + latest
       → Redis LIST queue history
       → UPDATE drivers (max 1 lần/10s/tài xế)
Cloudflare Worker Cron (mỗi phút)
  → Edge `flush-gps-history` (x-gps-ingest-secret)
       → dọn latest/GEO của tài xế OFF đủ 30 phút, không còn đơn active
       → JSONL gzip chunk → private R2 bucket
```

Map/navigation tài xế và Realtime Broadcast cho khách giữ nguyên nhịp GPS hiện
có, độc lập với ingest Redis/PG. Navigation, foreground và heartbeat dùng cùng
giới hạn PG trên Redis; Flutter không PATCH `drivers` bổ sung khi Edge thành công.
`force_pg_sync: true` đồng bộ PG ngay ở mốc nhận đơn/đến điểm/giao hoàn tất và
đặt lại cửa sổ 10s. Mẫu giám sát `record_driver_monitoring_position` giữ nguyên.
Fallback chỉ UPDATE latest `drivers` mỗi 10s (ngoại trừ mốc force), không ghi
lịch sử vào PostgreSQL. Lỗi PG giải phóng dấu chặn để mẫu tiếp theo được thử lại.

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

## Dọn GPS khi OFF

- App gọi `driver-location-presence` với `event: offline`. Edge xác thực JWT,
  gọi RPC `set_driver_availability(false)` hiện có và ghi mốc OFF bằng giờ server.
  Online vẫn phải qua RPC kiểm tra PIN; thông báo `event: online` chỉ đồng bộ cache,
  không có quyền bật Online hoặc thay đổi tài xế khác.
- `driver:offline:<user_id>` giữ mốc OFF, hạn 30 phút và token của lần OFF;
  sorted set `drivers:offline:cleanup` giữ lịch dọn. GPS gửi tiếp và retry OFF không
  gia hạn. Một lần chuyển từ Online sang OFF bắt đầu mốc mới.
  Redis latest được đánh dấu `is_available: false` ngay khi đăng ký OFF, giữ
  nguyên tọa độ và thời điểm GPS; cache còn cờ Online giúp phục hồi mốc OFF bị bỏ lỡ.
- Cron hiện có xử lý tối đa 100 tài xế đến hạn mỗi lượt, đọc trạng thái `drivers`
  và đơn hàng theo nhóm, rồi dọn bằng một lệnh Lua. Sau đủ 30 phút, xóa
  `driver:loc:<user_id>` và member tương ứng trong `drivers:geo`. Với lượng nhỏ,
  việc xóa thường diễn ra ở lượt cron kế tiếp (khoảng 30–31 phút); nhiều tài xế
  cùng đến hạn được xử lý qua các lượt tiếp theo.
- Giữ vị trí nếu còn đơn `assigned`, `picking_up`, `delivering`, `return_approved`
  hoặc `returning`, rồi kiểm tra lại sau một phút. Nếu đã OFF đủ 30 phút và đơn
  kết thúc, lượt kiểm tra tiếp theo dọn cache. Online lại hủy lịch dọn và ghi
  vị trí mới nhất từ lần xác thực Online.
- Lua so khớp token và bản GPS đã đọc trước khi xóa; cron cũ không xóa vị trí
  của phiên Online/OFF mới. Sau khi dọn, giữ mốc OFF nhỏ **không chứa tọa độ**
  cho đến lần Online tiếp theo để GPS cũ gửi lại không tạo lại cache đã hết hạn.
  Nếu mẫu GPS vừa kiểm tra đơn active đến sau lượt dọn, nó được đặt lại lịch
  kiểm tra trạng thái để cache không bị sót khi đơn vừa kết thúc.
- Cron chạy cả khi queue lịch sử rỗng. Lỗi kiểm tra database giữ GPS và thử lại;
  lỗi dọn cache không ngăn luồng đóng gói lịch sử R2 hiện có.
- Cron quét dần GEO để hỗ trợ cache cũ, client cũ hoặc đồng bộ OFF gặp lỗi Redis.
  Nếu thiếu mốc OFF, đếm 30 phút từ lúc server quan sát được OFF, tránh xóa sớm.
  Đây là cơ chế phục hồi; lúc hệ thống gián đoạn, việc dọn có thể trễ hơn.
  Nếu Edge presence không khả dụng, app vẫn tắt nhận đơn qua RPC OFF hiện có.
- Không xóa tọa độ mới nhất trong bảng `drivers`, không đụng queue lịch sử và
  không đổi lifecycle R2 14 ngày. Không dùng TTL trên cả key `drivers:geo`, vì
  key đó chứa vị trí của nhiều tài xế và cần kiểm tra đơn active trước khi dọn.

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
supabase functions deploy driver-location-presence
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

Kiểm tra tập trung:

```bash
node --experimental-strip-types --test supabase/functions/ingest-driver-location/latest_location_sync_test.ts supabase/functions/ingest-driver-location/history_queue_test.ts
node --test supabase/functions/_shared/driver_location_retention_test.mjs supabase/functions/driver-location-presence/presence_test.mjs supabase/functions/flush-gps-history/archive_test.mjs
cd apps/delivery_app
flutter test test/driver_location_presence_test.dart test/driver_service_online_test.dart test/location_ingest_cadence_test.dart test/location_ingest_arrival_timestamp_test.dart test/driver_monitoring_ingest_test.dart
```

## Kafka

Chưa dùng. Khi throughput rất lớn: thay Redis LIST bằng Kafka topic + consumer ghi chunk R2.
