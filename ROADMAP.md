# ROADMAP — Hệ thống Giao Hàng Thông Minh

> Cập nhật: 01/08/2026
> Đề tài: **Xây dựng ứng dụng quản lý giao hàng thông minh hỗ trợ theo dõi vị trí thời gian thực và dự đoán thời gian giao hàng.**

## 1. Mục đích

Roadmap này là nguồn định hướng cho việc hoàn thiện và tiếp tục phát triển project. Tài liệu tập trung vào chiều sâu của hệ thống:

- Nghiệp vụ giao hàng rõ ràng.
- Dữ liệu nhất quán.
- Phân công tài xế an toàn khi có xử lý đồng thời.
- Tracking GPS có retry và phục hồi lỗi.
- ETA được tính, lưu, cập nhật và đánh giá.
- Phân quyền và dữ liệu nhạy cảm được bảo vệ.
- Hệ thống có thể kiểm thử, triển khai và demo lại.

Quy ước:

- **Đã có:** đã xuất hiện trong source.
- **Cần hoàn thiện:** đã có nền tảng nhưng chưa đủ tin cậy.
- **Chưa triển khai:** chưa có luồng hoàn chỉnh trong source.
- **Tương lai:** chỉ thực hiện sau khi phần cốt lõi ổn định.

## 2. Quyết định đã thống nhất

### 2.1. Kiến trúc sản phẩm

- Sử dụng **một monorepo với hai ứng dụng Flutter**: Delivery App cho Customer/Driver và Operations Web cho Support/Admin.
- Hai ứng dụng có vòng đời build/deploy riêng nhưng dùng chung packages nền tảng, Supabase migrations và Edge Functions.
- Không tách thành nhiều repository và không sao chép domain models/design tokens giữa hai ứng dụng.
- PostgreSQL của Supabase là nguồn dữ liệu nghiệp vụ lâu dài.
- Redis chỉ là nơi lưu dữ liệu GPS mới nhất và hàng đợi tạm thời.
- Supabase Edge Functions xử lý các tác vụ cần xác thực hoặc quyền backend.

### 2.2. Vai trò người dùng

Hệ thống hướng đến bốn vai trò:

- **Customer:** tạo và theo dõi đơn hàng.
- **Driver:** nhận và thực hiện giao hàng.
- **Support:** tra cứu đơn và ghi nhận yêu cầu hỗ trợ.
- **Admin:** quản lý hệ thống và tạo tài khoản Support.

Source hiện có Customer, Driver, Admin và lát cắt Support tối thiểu. Support không được làm chậm tracking, ETA, bảo mật hoặc kiểm thử.

### 2.3. Một tài xế — một đơn hàng

- Mỗi tài xế chỉ được xử lý một đơn ở trạng thái hoạt động tại một thời điểm.
- Các trạng thái hoạt động gồm:
  - `assigned`
  - `picking_up`
  - `delivering`
- Business rule này phải được bảo đảm bằng constraint và transaction tại PostgreSQL, không chỉ kiểm tra trên Flutter.
- Không triển khai giao nhiều đơn đồng thời hoặc tối ưu nhiều điểm giao.

### 2.4. Luồng offer và nhận đơn

Hệ thống không tự động gán tài xế ngay khi Customer tạo đơn.

```text
Đơn pending
→ lọc tài xế đủ điều kiện
→ xếp hạng ứng viên
→ gửi offer cho ứng viên đứng đầu
→ tài xế chấp nhận hoặc từ chối
→ backend gán đơn nguyên tử khi chấp nhận
→ nếu từ chối, xét ứng viên tiếp theo
```

Ứng viên hợp lệ phải:

1. Được Admin duyệt.
2. Đang sẵn sàng nhận đơn.
3. Không có đơn đang hoạt động.
4. Có GPS hợp lệ và chưa quá hạn.
5. Chưa từ chối đơn đang xét.

Quy tắc xếp hạng:

1. Tìm khoảng cách nhỏ nhất đến điểm lấy hàng.
2. Lấy nhóm tài xế có khoảng cách không vượt quá `khoảng cách nhỏ nhất + 100 m`.
3. Trong nhóm này, ưu tiên rating cao hơn.
4. Nếu rating bằng nhau, ưu tiên vị trí được cập nhật mới hơn.
5. Nếu vẫn bằng nhau, dùng `user_id` làm tiêu chí cuối để kết quả xác định.

### 2.5. ETA không sử dụng AI

ETA sử dụng thời lượng tuyến đường từ OSRM, GPS hiện tại, trạng thái đơn và thời gian xử lý cấu hình.

Báo giá trước khi tạo đơn đã có `DeliveryEtaCalculator` độc lập với Widget:

```text
thời gian di chuyển hiệu chỉnh
= max(
    thời gian OSRM × hệ số khung giờ,
    khoảng cách / vận tốc đô thị tham chiếu
  )

thời gian giao dự kiến
= thời gian di chuyển hiệu chỉnh
+ thời gian bàn giao cố định
```

- Loại thời lượng OSRM nếu vận tốc suy ra nằm ngoài khoảng hợp lý.
- Ngoài cao điểm dùng vận tốc tham chiếu `28 km/h`; cao điểm dùng `22 km/h`.
- Cộng `6 phút` cho thao tác nhận và giao hàng.
- UI hiển thị khoảng thời gian làm tròn 5 phút, không hiển thị một con số giả chính xác.
- Thời gian tìm tài xế tối đa 15 phút được trình bày riêng, không trộn vào thời gian vận chuyển.

Phí giao hàng tiêu chuẩn đã được tách thành `DeliveryPricingPolicy`:

```text
18.000đ bao gồm 2 km đầu
+ 5.000đ/km từ trên 2 km đến 10 km
+ 4.000đ/km từ trên 10 km
→ làm tròn lên 1.000đ
```

Không áp dụng giá động, thời tiết, khuyến mãi hoặc phụ phí ẩn khi chưa có nguồn dữ liệu đáng tin cậy. Màn hình xác nhận phải hiển thị đầy đủ cách hình thành tổng phí.

Khi tài xế chưa lấy hàng:

```text
ETA giao hàng
= thời gian tài xế → điểm lấy
+ thời gian xử lý lấy hàng
+ thời gian điểm lấy → điểm giao
+ thời gian xử lý giao hàng
```

Khi tài xế đã lấy hàng:

```text
ETA giao hàng
= thời gian tài xế hiện tại → điểm giao
+ thời gian xử lý giao hàng
```

ETA được tính lại khi:

- Tài xế nhận đơn.
- Trạng thái đơn thay đổi.
- Tài xế di chuyển tối thiểu 100 m.
- ETA đã quá 30 giây chưa được cập nhật.

Khi OSRM lỗi, hệ thống giữ ETA hợp lệ gần nhất và đánh dấu dữ liệu đã cũ; không tạo một ETA giả có vẻ chính xác.

### 2.6. Nguyên tắc tổ chức source

- Không áp dụng giới hạn cứng về số dòng của một file.
- Kích thước file chỉ là tín hiệu để xem xét, không phải tiêu chí quyết định.
- Mỗi file/module phải có **một trách nhiệm chính rõ ràng**.
- Không gom UI, truy vấn dữ liệu, business rule, xử lý lỗi, formatter và tích hợp bên ngoài vào cùng một file nếu chúng thay đổi vì các lý do khác nhau.
- Chỉ tách file khi việc tách giúp:
  - Dễ hiểu trách nhiệm.
  - Dễ kiểm thử.
  - Giảm phụ thuộc.
  - Dễ thay đổi mà không ảnh hưởng phần không liên quan.
- Không chia nhỏ máy móc thành nhiều file chỉ để giảm số dòng.
- Không viết lại toàn bộ ứng dụng theo một kiến trúc mới; chỉ refactor các phần trực tiếp cản bảo trì hoặc kiểm thử.

## 3. Hiện trạng

### 3.1. Đã có trong source

- Auth và điều hướng cho Customer, Driver và Admin.
- Đăng ký, KYC và duyệt tài xế.
- Customer tạo đơn, chọn địa chỉ trên bản đồ và thêm thông tin hàng hóa.
- Saved address và reverse geocoding.
- Tài xế xem, nhận, từ chối và cập nhật trạng thái đơn.
- Đơn mới có thời hạn 15 phút để tài xế nhận; hết hạn Customer có thể tìm lại hoặc hủy.
- Nhận đơn dùng RPC nguyên tử và unique partial index để bảo đảm một Driver chỉ có một order active.
- Bản đồ OpenStreetMap và tuyến đường OSRM.
- GPS tracking, Supabase Realtime và polling fallback.
- Edge Function, Redis GEO/latest location và queue lịch sử GPS.
- Notification trong ứng dụng.
- Đánh giá hai chiều Customer–Driver.
- Admin dashboard, danh sách đơn và duyệt tài xế.
- Web GPS/navigation simulation phục vụ demo.

### 3.2. Chưa hoàn chỉnh hoặc chưa đủ tin cậy

- Báo giá ETA trước khi tạo đơn đã hoàn thành; ETA theo GPS sau khi tài xế nhận đơn chưa được tính, lưu và hiển thị end-to-end.
- Rating chưa được sử dụng khi xếp hạng tài xế có khoảng cách tương đương.
- State machine trong source và tài liệu chưa thống nhất.
- Order update, item và status log chưa luôn được ghi trong cùng transaction.
- GPS local fallback có thể mất batch khi PostgreSQL lỗi.
- Redis queue chưa có idempotency và quy trình acknowledge/recovery đầy đủ.
- GPS stale chưa được dùng để loại tài xế khỏi phân công.
- Role, route, schema và RLS cho Support đã có ở mức tối thiểu; tài khoản Support vẫn phải được Admin tạo qua luồng an toàn.
- Router chưa bảo vệ đầy đủ route Admin và role lạ có thể rơi về Customer.
- Database migrations chưa dựng lại được toàn bộ schema từ đầu.
- README và một số tài liệu cũ chưa khớp source.
- Test chưa bao phủ đầy đủ state machine, RLS, concurrency nhiều session, ETA và GPS recovery.

## 4. Giai đoạn 0 — Cổng an toàn và khả năng tái lập

Không mở rộng chức năng trước khi hoàn thành các hạng mục sau.

### 4.1. Sửa quyền dữ liệu quan trọng

- Người dùng không thể tự thay đổi `role`.
- Driver không thể tự thay đổi:
  - `approval_status`
  - `rating`
  - `rating_count`
  - `total_deliveries`
- Customer và Driver chỉ được cập nhật các cột và trạng thái đúng quyền.
- KYC không dùng bucket public.
- Lịch sử GPS không được cho toàn bộ authenticated user đọc.
- Status log chỉ do backend tạo; client chỉ được đọc.
- Notification và review chỉ được tạo qua RPC/trigger có kiểm tra actor và dữ liệu liên quan.
- Không có service role key hoặc cron secret trong Flutter, source, log hay URL query.

### 4.2. Chuẩn hóa migrations

- Tạo baseline migration có thể dựng database mới từ đầu.
- Đối chiếu migration ledger với live database.
- Xác định và xử lý an toàn các bảng legacy; không xóa dữ liệu live khi chưa kiểm tra.
- Bổ sung index và constraint cho các bất biến nghiệp vụ hiện tại.
- Kiểm tra schema từ source phải tạo được cùng cấu trúc với môi trường demo.

### 4.3. Đồng bộ tài liệu nguồn

- `AGENTS.md`: quyết định kiến trúc và quy tắc làm việc.
- `ROADMAP.md`: phạm vi, thứ tự ưu tiên và tiêu chí hoàn thành.
- `supabase/migrations/`: nguồn sự thật của schema và RLS.
- `supabase/functions/`: nguồn sự thật của Edge Functions.
- `README.md`: trạng thái chức năng và hướng dẫn chạy thực tế.

Khi tài liệu mâu thuẫn với source hoặc migrations, phải cập nhật hoặc đánh dấu tài liệu lỗi thời.

## 5. Giai đoạn 1 — Hoàn thiện nghiệp vụ đơn hàng

### 5.1. State machine thống nhất

Luồng chính:

```text
pending → assigned → picking_up → delivering → delivered
```

Không sử dụng `confirmed` trong luồng chính nếu chưa có bước nghiệp vụ riêng tạo ra trạng thái này.

Nhánh không tìm thấy tài xế:

```text
pending
→ hết assignment_expires_at
→ assignment_timed_out_at được ghi nhận
→ Customer tìm lại (mở cửa sổ 15 phút mới) hoặc hủy đơn
```

`assignment_timeout` là trạng thái hiệu lực ở tầng ứng dụng, không phải giá trị mới của enum `order_status`. Database vẫn giữ `pending` hoặc `confirmed` và dùng hai timestamp để tránh phá vỡ state machine hiện tại.

Không bổ sung trạng thái `failed` trong phạm vi hiện tại. Trường hợp không thể tiếp tục giao được biểu diễn bằng `cancelled` cùng actor và lý do.

| Hiện tại | Tiếp theo | Chủ thể | Điều kiện |
|---|---|---|---|
| `pending` | `assigned` | Driver nhận offer | Driver đủ điều kiện |
| `assigned` | `picking_up` | Driver được gán | Đúng Driver của đơn |
| `picking_up` | `delivering` | Driver được gán | Đã nhận hàng |
| `delivering` | `delivered` | Driver được gán | Giao thành công |
| `pending` | `cancelled` | Customer hoặc Admin | Có lý do |
| `assigned` | `cancelled` | Customer hoặc Admin | Có lý do |
| `picking_up`/`delivering` | `cancelled` | Admin | Trường hợp ngoại lệ, có lý do |

Mỗi transition phải:

- Kiểm tra trạng thái cũ, trạng thái mới và actor.
- Cập nhật order và status log trong cùng transaction.
- Lưu actor, thời điểm và lý do.
- Từ chối transition sai thứ tự hoặc lặp lại.

### 5.2. Tính nhất quán dữ liệu

Các thao tác sau phải nguyên tử tại backend:

- Tạo order, order item ban đầu và status log `pending`.
- Nhận đơn, kiểm tra Driver chưa có đơn active và tạo log `assigned`.
- Chuyển trạng thái và tạo status log tương ứng.
- Hủy đơn và tạo status log `cancelled`.
- Hoàn thành đơn và lưu `actual_delivered_at`.

Không bỏ qua lỗi order item hoặc status log rồi báo toàn bộ thao tác thành công.

### 5.3. Concurrency và constraint

- PostgreSQL phải bảo đảm mỗi order chỉ có tối đa một Driver.
- PostgreSQL phải bảo đảm mỗi Driver chỉ có tối đa một order active.
- Hai request cùng nhận một order chỉ có một request thành công.
- Hai transaction trên hai order khác nhau không được gán cùng một Driver.
- Khi vi phạm constraint, backend trả lỗi nghiệp vụ rõ ràng hoặc chọn lại ứng viên.

## 6. Giai đoạn 2 — Hoàn thiện phân công và ETA

### 6.1. Assignment module

Tập trung các quy tắc vào một module có trách nhiệm rõ ràng:

- Lọc điều kiện hợp lệ.
- Kiểm tra GPS stale.
- Xếp hạng theo khoảng cách; chưa dùng rating để đảo thứ tự offer trong MVP.
- Tie-break có tính xác định.
- Loại Driver đã từ chối.

Redis, PostGIS và fallback phía Flutter phải tạo cùng kết quả với cùng dữ liệu đầu vào. Business rule không được thay đổi theo adapter đang sử dụng.

Kịch bản demo hiện tại:

> Pickup gần `taixe3`; khi `taixe3` chuyển đơn thì offer sang `taixe2`, sau đó
> sang `taixe`. Mỗi Driver chỉ có tối đa một order active.

Checklist lát cắt chuyển đơn 3 tài xế (2026-08-04):

- [x] Bán kính offer mặc định 5 km trên Flutter, PostgreSQL và Redis adapter.
- [x] Loại Driver đã chuyển đơn trước khi xếp lại theo khoảng cách.
- [x] PostgreSQL và Redis chỉ xếp theo khoảng cách, tie-break bằng `user_id`.
- [x] Áp migration mới lên Supabase Cloud và deploy Edge Function v12 với JWT.
- [x] Cấu hình debug: `taixe2` cách GPS thật khoảng 3,1 km; `taixe3` cách
  `taixe2` khoảng 1 km trên cùng hướng, vẫn nằm trong bán kính 5 km.
- [x] Test tự động chuỗi `taixe3 → taixe2 → taixe → hết tài xế` và kiểm tra
  static hardening migration/Edge Function.
- [x] Chạy manual E2E trên ba phiên đăng nhập sau khi hot restart app (đã xác nhận đạt).

### 6.2. ETA pipeline

```text
GPS Driver + trạng thái order
→ xác định chặng hiện tại
→ gọi OSRM
→ EtaCalculator cộng thời gian xử lý
→ backend lưu ETA
→ Realtime cập nhật Customer UI
```

Dữ liệu tối thiểu:

- `estimated_pickup_at`
- `estimated_delivery_at`
- `eta_updated_at`
- `eta_source`
- `eta_is_stale`
- `actual_picked_up_at`
- `actual_delivered_at`

Yêu cầu:

- ETA không được tính trực tiếp trong Widget.
- `DeliveryEtaCalculator` hiện xử lý báo giá trước khi tạo đơn; không để UI tự chia hoặc hiệu chỉnh thời lượng OSRM.
- Thời lượng OSRM phải qua kiểm tra vận tốc hợp lý trước khi được sử dụng.
- UI hiển thị ETA theo khoảng và nêu rõ mốc bắt đầu tính.
- Customer chỉ đọc ETA; workflow Driver/backend chịu trách nhiệm cập nhật.
- UI hiển thị thời điểm cập nhật gần nhất.
- OSRM lỗi không được làm mất ETA hợp lệ cuối cùng.
- Lưu thời gian thực tế để đánh giá sai số:

```text
Sai số tuyệt đối = |thời gian thực tế - ETA dự kiến|
```

Không công bố kết quả thử nghiệm như SLA thương mại.

## 7. Giai đoạn 3 — Hoàn thiện GPS và Realtime

### 7.1. Hợp đồng dữ liệu GPS

- Mỗi mẫu GPS có `sample_id` duy nhất.
- Kiểm tra miền hợp lệ của latitude, longitude, heading, speed và timestamp.
- Redis latest location có TTL.
- Driver có vị trí stale không được đưa vào phân công.
- Chỉ nhận GPS từ đúng Driver đã xác thực.
- Chỉ tracking tần suất cao khi Driver có order active.

### 7.2. Queue và recovery

- Chuyển mẫu từ queue sang processing list.
- Chỉ acknowledge/xóa sau khi PostgreSQL ghi thành công.
- Worker dừng giữa chừng phải có thể phục hồi dữ liệu từ processing.
- Retry có backoff và giới hạn.
- Payload sai được ghi log hoặc đưa vào dead-letter list.
- Edge Function lỗi phải được thử lại sau cooldown.
- Local fallback được xem là `best-effort` cho đến khi có lưu tạm bền vững trên thiết bị.

### 7.3. Hiển thị trạng thái tracking

- Customer thấy thời điểm cập nhật vị trí gần nhất.
- UI phân biệt `live`, `stale` và `offline`.
- Realtime ngắt kết nối thì polling/reconnect theo chiến lược xác định.
- Không báo cập nhật thành công nếu PostgreSQL latest location chưa được cập nhật.
- Debug GPS và Web simulation chỉ hiển thị trong debug/demo build.

### 7.4. Ma trận sự cố

| Sự cố | Hành vi mong đợi |
|---|---|
| Mất quyền GPS | Dừng gửi và hướng dẫn bật lại |
| Mất mạng | Lưu tạm có giới hạn và retry |
| Redis lỗi | Dùng fallback có kiểm soát và thử kết nối lại |
| PostgreSQL ghi lỗi | Không xóa mẫu khỏi processing |
| Realtime ngắt | Poll/reconnect và hiển thị timestamp cuối |
| GPS stale | Không dùng Driver để phân công |
| OSRM timeout | Giữ ETA cuối và đánh dấu stale |
| App khởi động lại | Khôi phục order active và navigation session |

## 8. Giai đoạn 4 — Support tối thiểu

Chỉ bắt đầu sau khi state machine, assignment, tracking, ETA và security đã ổn định.

### 8.1. Quản lý tài khoản

Admin có thể:

- Tạo tài khoản Support qua Edge Function an toàn.
- Gửi lời mời đặt mật khẩu.
- Khóa hoặc mở khóa tài khoản.

Service role key không được đưa vào Flutter.

### 8.2. Phạm vi Support

Support chỉ có:

- Đăng nhập vào khu vực riêng.
- Tra cứu order được phép hỗ trợ.
- Xem timeline của order.
- Ghi nhận nội dung và kết quả hỗ trợ.

Support không được:

- Duyệt KYC.
- Sửa rating.
- Gán hoặc đổi Driver.
- Sửa giá.
- Cập nhật trạng thái giao hàng.
- Xem GPS hoặc KYC không liên quan.

Không phát triển full CRM, SLA, escalation, tổng đài hoặc phân tích hiệu suất Support trong phạm vi hiện tại.

## 9. Chiến lược kiểm thử

| Tầng | Nội dung | Bằng chứng |
|---|---|---|
| Unit | State machine, ranking, ETA, GPS throttle/stale | Test tự động |
| Database/RPC | Constraint, transaction, trigger, concurrency | Integration/SQL test |
| RLS | Permission matrix cho từng vai trò | Allow/deny tests |
| Edge Function | Auth, payload sai, Redis lỗi, flush/recovery | Request tests |
| Flutter | Action theo trạng thái, ETA và tracking state | Widget/integration test |
| End-to-end | Customer tạo đơn đến delivered | Demo runbook |
| Failure | OSRM lỗi, Redis lỗi, mất mạng, GPS stale | Expected/actual |

Quality gate:

- `flutter analyze` không có warning hoặc error.
- `flutter test` hoàn tất trong thời gian xác định và chạy xanh.
- Database dựng lại được từ migrations.
- RLS matrix chạy đúng.
- Concurrency test chứng minh một Driver/một order active.
- Không có debug control trong release.

## 10. Nguyên tắc bảo trì và refactor

Không dùng số dòng làm điều kiện bắt buộc để tách file.

Ưu tiên refactor khi:

- Một file có nhiều trách nhiệm không liên quan.
- Business rule nằm trong Widget và khó kiểm thử.
- Cùng một quy tắc bị lặp ở nhiều nơi.
- Thay đổi một chức năng thường làm hỏng chức năng khác.
- File phụ thuộc trực tiếp quá nhiều nguồn dữ liệu hoặc dịch vụ ngoài.

Các module nên được làm rõ trong quá trình phát triển:

- `OrderStateMachine`: trạng thái và quyền transition.
- `DriverAssignmentPolicy`: điều kiện và xếp hạng Driver.
- `EtaCalculator`: công thức và refresh rule.
- Order command module: create, accept, transition và cancel.
- GPS ingest module: validate, retry, queue và recovery.

Mục tiêu là tăng tính tập trung trách nhiệm và khả năng kiểm thử, không phải tạo thật nhiều file.

## 11. Tài liệu kiến trúc cần bổ sung

### 11.1. ADR

- ADR-001: Một Flutter app cho các vai trò.
- ADR-002: Một Driver chỉ xử lý một order active.
- ADR-003: PostgreSQL là source of truth; Redis là hot store/queue.
- ADR-004: Offer/accept thay vì auto-assign.
- ADR-005: ETA dùng OSRM và công thức, không dùng AI.

### 11.2. Sơ đồ

- Context diagram của hệ thống.
- State/activity diagram của order.
- Sequence diagram tạo và nhận order.
- Sequence diagram GPS → Edge Function → Redis → PostgreSQL/Realtime.
- Sequence diagram cập nhật ETA.
- Deployment diagram gồm Flutter, Supabase, Redis và OSRM.
- ERD khớp với migrations thực tế.

### 11.3. Tài liệu vận hành

- Permission matrix cho Customer, Driver, Support và Admin.
- Security checklist.
- Hướng dẫn secrets và deploy Edge Functions.
- Hướng dẫn Redis và cron worker.
- Known limitations.
- Demo runbook và dữ liệu demo có thể tái lập.

## 12. Giới hạn đã biết

- Mỗi Driver chỉ xử lý một order tại một thời điểm.
- ETA không sử dụng AI và không phản ánh giao thông thời gian thực.
- OSRM public không có SLA cho production.
- GPS phụ thuộc thiết bị, quyền hệ điều hành và kết nối mạng.
- Redis không phải nguồn dữ liệu nghiệp vụ lâu dài.
- Supabase Realtime có thể gián đoạn.
- Web simulation chỉ phục vụ demo.
- Local GPS fallback hiện là best-effort cho đến khi có lưu tạm bền vững.
- Phiên bản hiện tại không triển khai thanh toán, COD, push notification, chat, multi-order hoặc VRP.

## 13. Tiêu chí hoàn thành phiên bản bảo vệ

Luồng bắt buộc:

```text
Customer tạo order
→ hệ thống chọn ứng viên phù hợp
→ Driver nhận offer và chấp nhận
→ Driver lấy hàng
→ Customer theo dõi GPS, route và ETA
→ Driver giao hàng
→ order chuyển delivered
→ Admin tra cứu được timeline
```

Phải chứng minh:

- Hai Driver cùng nhận một order thì chỉ một người thành công.
- Một Driver không thể có hai order active.
- Hai Driver có khoảng cách tương đương được xếp hạng theo rating.
- GPS stale không được dùng để phân công.
- ETA thay đổi theo vị trí hoặc trạng thái.
- Redis/OSRM/Realtime lỗi có hành vi fallback rõ ràng.
- Người dùng không thể tự nâng role hoặc sửa dữ liệu hệ thống.
- KYC và GPS không bị truy cập trái quyền.
- Database và demo có thể tái lập từ source.

Support không phải điều kiện chặn phiên bản bảo vệ nếu phần này chưa hoàn chỉnh.

## 14. Thứ tự ưu tiên

1. Sửa RLS và bảo vệ dữ liệu KYC/GPS.
2. Chuẩn hóa migrations và xử lý schema drift.
3. Thống nhất state machine và transaction order/status log.
4. Duy trì và bổ sung integration test cho constraint một Driver/một order đã triển khai.
5. Hoàn thiện assignment theo khoảng cách, rating và GPS freshness.
6. Hoàn thiện ETA end-to-end.
7. Hoàn thiện retry/recovery của GPS pipeline.
8. Bổ sung test, ADR, sơ đồ và demo runbook.
9. Đồng bộ README, AGENTS và tài liệu schema.
10. Chỉ sau đó mới phát triển Support tối thiểu.
