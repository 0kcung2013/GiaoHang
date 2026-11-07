# Chế độ nhận đơn tài xế

Triển khai ngày 2026-11-05. Điểm vào: **Menu tài xế → Chế độ nhận đơn**,
đứng đầu danh sách chức năng; mở thành tab riêng, không còn nằm trên Tổng quan.

## Nghiệp vụ

- `nearby` (Gần tôi): chế độ mặc định cho tài xế hiện có; tiếp tục dùng bán kính
  phân công tự động trong business policy của đơn (mặc định hiện tại 2.000 m).
  Quãng đường bộ **điểm lấy → điểm giao** tùy chọn **dưới 5 km / dưới 10 km /
  không giới hạn**. Dùng bất đẳng thức nghiêm: 5.000 m không thuộc “dưới 5 km”.
  Mặc định không giới hạn, chỉ áp bộ lọc này khi mode là `nearby`.
- `area` (Vùng hoạt động): chọn tỉnh/thành rồi một vùng có tên. **Cả điểm lấy và
  điểm giao** phải nằm trong polygon vùng. Vẫn giữ giới hạn đến điểm lấy của đơn,
  điều kiện GPS, online, KYC, COD, khóa nhận đơn và workload hiện có.
- `destination` (Về điểm đến): chọn B bằng tìm địa điểm hoặc chạm bản đồ. A là GPS
  hiện tại ở server. Tài xế phù hợp hướng được ưu tiên trước `nearby`/`area`, dù
  tài xế kia gần điểm lấy hơn. Khoảng cách **đường bộ** tới điểm lấy tối đa 3.000 m.
  Chỉ yêu cầu sau khi giao quãng đường về B ngắn hơn từ vị trí hiện tại; không
  yêu cầu điểm giao gần B, bám polyline hoặc giới hạn đường vòng. Ví dụ đang cách
  B 10 km thì điểm giao còn dưới 10 km là phù hợp. B giữ nguyên qua nhiều đơn,
  GPS hiện tại thay đổi theo mỗi chặng; hoàn thành một đơn không kết thúc chế độ.
  Nhiều tài xế cùng chế độ: gần điểm lấy trước; khoảng cách bằng nhau giữ rating,
  thời gian và ID làm tiêu chí phụ hiện có.
- Một chế độ tại một thời điểm. FreePick tiếp tục luồng hiển thị/nhận đơn theo
  vị trí hiện tại và bán kính riêng; không áp bộ lọc vùng cho thao tác tự chọn đó.
- Gửi lời mời để tài xế nhận; không tự nhận thay tài xế. Từ chối/hết hạn tiếp tục
  pipeline hiện có, gồm quy tắc đếm từ chối. Không gọi lời mời cho tài xế bị lọc.
- Đang có lời mời còn hiệu lực thì không đổi chế độ. Đơn đã nhận không thay đổi.
- Chế độ về B có hiệu lực 8 giờ theo server, không tự chuyển thành chế độ khác.
  Khi GPS trong 300 m quanh B hoặc hết hiệu lực, không phát thêm lời mời theo chế
  độ này. Tài xế dùng “Kết thúc về điểm đến” để trở lại Gần tôi. Cần bật trạng thái
  hoạt động như bình thường; lưu chế độ không tự bật online.

### Kiểm tra thuận đường

OSRM tính các quãng đường A→điểm lấy, điểm lấy→điểm giao, điểm giao→B và A→B.
Đơn phù hợp khi:

1. A→điểm lấy ≤ 3.000 m.
2. Điểm giao→B **nhỏ hơn** A→B, không cần giảm ít nhất 100 m.
3. A→B phải lớn hơn 300 m; giữ cơ chế kết thúc nhận lời mời gần B như trước.

Không có điều kiện giới hạn detour hoặc hành lang quanh polyline. Có thể phải
đi vòng để lấy/giao nhưng kết thúc đơn phải gần B hơn. Các chặng được hỏi bằng OSRM
Table theo batch tối đa 50 tọa độ; không lấy góc phương vị đường thẳng để gán đơn.
Lỗi routing cho nhóm về B loại nhóm đó khỏi lượt xét; tài xế thường có tuyến đến
điểm lấy hợp lệ vẫn có thể phục vụ. Lỗi tuyến đến điểm lấy giữ đơn chờ cron thử lại.

## Dữ liệu và quyền

Migration: `supabase/migrations/20261105062941_driver_dispatch_preferences.sql`.
Các cập nhật: `20261105143622_destination_quote_coordinate_precision.sql` và
`20261105151931_simple_destination_and_delivery_limits.sql`.

- Tái sử dụng `drivers` để giữ mode, `operating_area_id`, tọa độ/nhãn B, hạn B.
  `nearby_delivery_limit_m` nullable giữ 5.000/10.000 hoặc NULL = không giới hạn.
  Chuyển sang chế độ khác giữ lựa chọn này nhưng không áp dụng bộ lọc của nó.
- Bảng mới `driver_operating_areas` là danh mục tham chiếu địa lý có polygon và
  phiên bản nguồn độc lập. Những bảng hiện có không chứa ranh giới quận/huyện;
  không thể kiểm tra tọa độ chính xác bằng các cột địa chỉ dạng chuỗi. Không tạo
  bảng riêng chỉ để giữ trạng thái màn hình hoặc lịch sử GPS.
- RLS bật. Client đã đăng nhập chỉ đọc danh mục đang bật và các cột tên/mã;
  geometry không cấp quyền đọc cho client. Nhãn và mã lấy từ danh mục đã nhập,
  không tin nhãn do client truyền khi xét vùng.
- RPC `set_driver_dispatch_preferences` xác định tài xế bằng `auth.uid()`;
  không nhận user ID đích. Client không được PATCH/INSERT trực tiếp các cột mới.
  App mới gửi đủ 6 tham số, gồm `p_nearby_delivery_limit_m`. Overload 5 tham số
  được giữ cho app cũ và không xóa lựa chọn giới hạn giao đã lưu. Overload mới
  tái sử dụng owner check, KYC, advisory lock và guard lời mời của bản 5 tham số.
- `road_dispatch_candidates` lọc vùng trước routing. `commit_road_driver_offer`
  khóa/recheck tài xế, vùng, GPS, khoảng cách, đích B và hạn B trước khi ghi lời mời.
  Quote cũ sau khi đổi B không còn hợp lệ. Các RPC nội bộ vẫn chỉ service role.
  Với nearby có giới hạn giao, server kiểm tra lại quote OSRM của điểm lấy→giao
  (tọa độ, hạn 30 giây và khoảng cách) trước khi ghi lời mời. Khi không lấy được
  quote này, chỉ bỏ qua tài xế cần bộ lọc; không coi thiếu tuyến là 0 m.
- Không sửa schema đơn hàng, chính sách khóa, monitoring, pipeline GPS/R2 hay Auth.

## Danh mục và giới hạn địa lý

- Tên/mã: snapshot API `https://provinces.open-api.vn/api/v1/?depth=2`, lấy ngày
  2026-11-05; danh mục địa giới cũ trước 07/2025.
- Polygon: geoBoundaries gbOpen VNM ADM1/ADM2, bản đại diện **2020**, commit
  `9469f09`, nguồn OCHA ROAP/Government of Viet Nam. Đây là vùng vận hành tham
  chiếu theo dữ liệu cũ, không phải tuyên bố địa giới hành chính hiện hành hoặc
  chứng nhận ranh giới pháp lý mới nhất. Tên khớp không bảo đảm mọi thay đổi ranh
  giới từ 2020 đã được phản ánh; cần đối soát trước khi mở rộng vận hành thực tế.
- Ghép tên đã chuẩn hóa + kiểm tra polygon thuộc tỉnh bằng điểm bên trong. Chỉ
  nhập khi có đúng một kết quả; không đoán bằng tìm chuỗi trong địa chỉ đơn.
- Có **638 vùng / 63 tỉnh theo danh mục cũ**, 58 vùng chưa đối chiếu được nằm
  trong `supabase/data/dispatch_areas/coverage.json` và không xuất hiện để chọn.
  Bình Dương có đủ 9 vùng, gồm Thủ Dầu Một, Thuận An, Tân Uyên, Dĩ An, Bến Cát,
  Bàu Bàng, Dầu Tiếng, Phú Giáo, Bắc Tân Uyên.
- Simplify giữ topology với tolerance 0.00005 độ (khoảng vài mét), làm tròn 7 chữ
  số rồi `ST_MakeValid` và chỉ giữ polygon. Điểm sát ranh có thể chịu sai số GPS và
  dữ liệu tham chiếu. `ST_Covers` bao gồm đường ranh; không suy ra vùng từ tên phố.
- Danh mục nằm ở Supabase, cache trong Riverpod trong phiên app; không gọi API
  công cộng mỗi lần mở list. Không cần secret hoặc dịch vụ lưu trữ mới.

## Setup/deploy

1. Áp dụng ba migration theo thứ tự ở mục Dữ liệu và quyền. Migration đầu giữ
   `nearby` cho tài xế cũ; migration mới đặt giới hạn giao NULL = không giới hạn.
2. Nhập lần lượt `supabase/data/dispatch_areas/*.sql` bằng PostgreSQL hoặc CLI:

   ```powershell
   Get-ChildItem supabase/data/dispatch_areas -Filter '*.sql' | Sort-Object Name | ForEach-Object {
     supabase db query --linked --file $_.FullName
     if ($LASTEXITCODE -ne 0) { throw "Import failed: $($_.Name)" }
   }
   ```

   Các batch idempotent theo mã vùng. Sau nhập: count=638, ST_IsValid=true.
3. Deploy **chỉ** `dispatch-road-orders`:

   ```powershell
   supabase functions deploy dispatch-road-orders --use-api
   ```

   Hoặc deploy qua Supabase MCP. Giữ `verify_jwt=false` tại gateway: function
   kiểm tra `x-road-dispatch-secret` với Vault qua RPC service-role hiện có.
   Giữ nguyên cron. Các secrets hiện có: `SUPABASE_URL`,
   `SUPABASE_SERVICE_ROLE_KEY`, `UPSTASH_REDIS_REST_URL`,
   `UPSTASH_REDIS_REST_TOKEN`, `OSRM_BASE_URL` (tùy chọn), Vault
   `road_dispatch_secret`. Không có secret mới; không ghi giá trị vào tài liệu.
4. Cập nhật app tài xế từ monorepo. Không thêm Flutter dependency.

Tại phiên triển khai 2026-11-05, các migration, 638 vùng và Edge Function version 5
đã áp dụng cho project DATN `erlpzwfbpjogvaulcxni` qua kết nối đã được cấp quyền.
CLI deploy trả 403 với credential của CLI; deploy qua MCP thành công. Khi bàn
giao, người vận hành cần tài khoản Supabase có quyền deploy; không dùng service
role key làm access token của CLI.

### Tái tạo danh mục

Không cần chạy phần này khi setup thông thường; SQL đã chứa dữ liệu.
`scripts/build_dispatch_area_catalog.py` cần Python và `shapely` (đã dùng 2.2.0).
Chuẩn bị các input trong `artifacts/`:

- `dispatch_provinces.json`: API v1 depth=2 ở trên.
- `dispatch_adm1.geojson`, `dispatch_adm2.geojson`: các file
  `releaseData/gbOpen/VNM/ADM1/geoBoundaries-VNM-ADM1.geojson` và
  `releaseData/gbOpen/VNM/ADM2/geoBoundaries-VNM-ADM2.geojson` từ
  `https://github.com/wmgeolab/geoBoundaries/raw/9469f09/`.

Chạy `python scripts/build_dispatch_area_catalog.py`, xem thay đổi coverage và
đối soát tọa độ trước khi import. Không tự động tải/chuyển sang v2 vì sẽ thay đổi
ý nghĩa vùng đã lưu. Giữ attribution tại `supabase/data/dispatch_areas/SOURCES.md`.

## Kiểm tra và khôi phục

- Node: `node --test supabase/functions/_shared/destination_dispatch_test.mjs supabase/functions/_shared/road_distance_test.mjs`.
- Flutter (từ `packages/giaohang_mobile`):
  `flutter test --no-pub test/driver_dispatch_preferences_test.dart` và analyze
  thư mục feature, `driver_data_body.dart`, `driver_drawer.dart`,
  `driver_shell_screen.dart` và file test vừa thêm. Test menu/shell:
  `flutter test --no-pub test/driver_drawer_free_pick_test.dart test/driver_shell_screen_test.dart`.
- SQL: `supabase/tests/driver_dispatch_preferences.sql` và
  `supabase/tests/driver_rating_tiebreak_regression.sql`,
  `supabase/tests/destination_quote_coordinate_precision.sql`,
  `supabase/tests/simple_destination_and_delivery_limits.sql`. Hai script đầu dùng 2 tài xế nhàn rỗi,
  mọi fixture/notification được rollback. Không tạo đơn giao thật.
- QA tay: chọn Bình Dương→Thủ Dầu Một, thử đơn cả hai đầu trong vùng và một đầu
  Thuận An; chọn B, thử điểm lấy 2.8 km/3.1 km, từ chối lời mời, đổi chế độ lúc
  đang có lời mời, hết hạn B, offline và GPS lỗi. Chưa kiểm tra ngoài đường bằng
  điện thoại thật; widget screenshot không thay thế kiểm tra này.
- Thiếu list: kiểm tra migration/grant, catalog import, `enabled` và coverage.
  Không bypass bằng nhập tên vùng thủ công.
- Không có đơn về B: kiểm tra GPS dưới 3 phút, COD/lock/workload, hạn B,
  khoảng cách lấy, quãng đường còn lại tới B, cron/OSRM/Redis. Đến B/hết hạn sẽ giữ chế độ nhưng
  ngừng phát lời mời; kết thúc chế độ để nhận quanh vị trí hiện tại.
- Khôi phục an toàn: chuyển tài xế về `nearby` bằng RPC sau khi xử lý lời mời
  còn hiệu lực. Với khôi phục toàn bộ qua vận hành, cập nhật đồng thời mode và
  xóa tất cả cột vùng/B để thỏa constraint. Giữ bảng/migration; không drop dữ liệu
  hoặc rollback các migration không liên quan. Sau đó mới khôi phục function cũ
  nếu cần. Không xóa lời mời/đơn đang giao để ép đổi mode.
- Security advisors đã kiểm tra: RPC mới chỉ cấp authenticated và kiểm tra owner;
  cảnh báo SECURITY DEFINER callable by authenticated là có chủ đích cho RPC này.
  Các cảnh báo sẵn có ngoài phạm vi tính năng chưa được thay đổi.

### Kết quả kiểm tra khi bàn giao

- 25 Node tests: đạt (routing/FreePick, tiến gần B, biên dưới 5/10 km và lỗi routing).
- 12 Flutter tests: đạt trong ba file feature/menu/shell; gồm chọn vùng/lưu,
  đổi tỉnh xóa vùng, tìm tiếng Việt không dấu, hủy chọn giữ giá trị cũ, lưu giới
  hạn giao, lỗi lời mời chờ, vị trí menu và model JSON. Bố cục 320/1024 px ở text
  scale 1.6 và 390 px ở 1.0; nút lưu cố định và nội dung cuộn.
- Analyze tập trung feature + các điểm tích hợp dashboard/menu/shell + test: không có vấn đề.
- Bốn SQL regression scripts nêu trên: đạt, rollback fixture. Có kiểm tra tại
  `commit_road_driver_offer`: tài xế gần hơn nhưng vượt giới hạn giao bị bỏ qua;
  lựa chọn không giới hạn vẫn nhận được đơn dài. Đối chiếu mẫu GPS
  Thủ Dầu Một (10.98,106.65) và Thuận An (10.905,106.70) cho kết quả thuộc hai
  vùng riêng. Toàn bộ 638 polygon hợp lệ.
- Đã xem ảnh render `artifacts/driver_dispatch_area_390.png` và bản 320 px.
  Chưa kiểm tra dẫn đường ngoài đường bằng điện thoại thật; chưa chạy full
  test suite, release build hoặc end-to-end toàn ứng dụng.

### UI và hành vi lưu

- Tab Chế độ nhận đơn là mục đầu trong menu, sau khối trạng thái online; những
  index tab cũ giữ nguyên, tab mới index 5. Lời mời toàn màn hình vẫn hoạt động
  khi tài xế đang ở tab này. Không còn card cũ trên Tổng quan.
- Ba lựa chọn chế độ bằng icon và nhãn; form theo chế độ được tách thành widget.
  Tỉnh/vùng mở sheet tìm kiếm, hỗ trợ nhập không dấu, hiển thị mục đã chọn. Đổi
  tỉnh xóa vùng cũ; đóng sheet không làm mất lựa chọn.
- Nút lưu cố định cuối màn hình; nội dung cuộn khi máy ngắn/chữ lớn/bàn phím.
  Tab giữ mở sau khi lưu thành công, hiển thị xác nhận và đọc lại trạng thái server.
- Chỉ thay đổi presentation của feature và điểm vào menu; không đổi tokens chung,
  không thêm dependency, secrets, cron hoặc dịch vụ mới. Cần chạy lại/hot restart
  bản Flutter đã cập nhật để thấy tab và form mới.

## Sửa lỗi lời mời về điểm đến bị loại sau khi tính tuyến

Ngày 2026-11-05, GH-10537 có tài xế online, GPS mới, đủ ví, không bận; điểm lấy
khoảng 220 m đường bộ và đơn thuận đường về B. OSRM và lọc ứng viên đều hợp lệ,
nhưng `private.driver_destination_quote_matches` trả false: bốn phép so tọa độ
dùng bằng nhau tuyệt đối trong khi JSON làm tròn float8 khoảng 1e-14–1e-13 độ.
Test trước đó dùng tọa độ tròn nên không phát hiện trường hợp này.

Migration `20261105143622_destination_quote_coordinate_precision.sql` đổi bốn
phép so thành `abs(delta) <= 1e-9`, cùng mức bù biểu diễn với kiểm tra tọa độ
điểm lấy hiện có (nhỏ hơn 0.2 mm). Hạn phiên điểm đến vẫn so tuyệt đối; đổi B hoặc
điểm giao thực sự vẫn làm quote cũ mất hiệu lực. Không thay đổi giới hạn 3 km,
điều kiện thuận đường, cơ chế lời mời/từ chối, giao diện hoặc pipeline GPS.

Đã áp migration trên DATN. Cron tự phát lời mời GH-10537 lúc 14:36:24 UTC
(21:36:24 giờ Việt Nam), log khoảng cách OSRM 220 m. Không gán tay và không xóa
lượt từ chối/lời mời để vượt điều kiện phân công. Lời mời vẫn hết hạn theo 45 giây
nếu tài xế không nhận.

Regression mới: `supabase/tests/destination_quote_coordinate_precision.sql`.
Đã chạy trước sửa và thấy lỗi, sau sửa đạt: kiểm tra độc lập cả bốn tọa độ bị làm
tròn, tình huống tuyến báo lỗi, thay đổi tọa độ thật, đổi hạn phiên và giá trị NaN.
Chạy lại hai SQL regression phân công/rating và 23 Node tests: đều đạt.
Security advisors không báo hàm vừa sửa; ACL vẫn chặn client gọi hàm private.
Không chạy lại Flutter analyze/test hoặc build vì lần sửa này chỉ đổi SQL.
Không cần deploy lại Edge Function hoặc cập nhật app để nhận bản sửa này.
