# ETA cố định khi nhận đơn — OSRM và LightGBM

Quy tắc đã được sửa theo yêu cầu cuối: các thành phần ETA chỉ được tính một
lần cho mỗi lần phân công tài xế. Đến lấy sớm, nhận hàng nhanh, đến giao sớm,
vị trí mới và giao thông thay đổi không làm tính lại hoặc rút ngắn dự báo.
Ngoại lệ duy nhất: GPS xác nhận xuất phát trong 5 phút đầu thì trừ đúng
5 phút chuẩn bị khỏi mốc dự kiến ban đầu, một lần.

Trước khi có tài xế, khách hàng chưa thấy số phút hoặc giờ giao dự kiến.
Khi có tài xế, lần tính hợp lệ đầu tiên lấy vị trí tài xế và hai tuyến OSRM,
chạy LightGBM rồi lưu kết quả trên đơn. Hai vai trò dùng cùng kết quả này.

Với mỗi chặng:

`T_chặng = OSRM.distance_meters / 1000 / 25 × 60 × K_LightGBM`

`T_ban_đầu = 5 phút chuẩn bị + T_tài_xế_đến_lấy + 5 phút nhận hàng + T_lấy_đến_giao + 5 phút bàn giao`

`Giờ_giao_ban_đầu = giờ nhận đơn trên server + T_ban_đầu`

OSRM cung cấp tuyến và khoảng cách đường bộ. Duration OSRM được lưu để
đối chiếu, không cộng thêm vào thời gian tính từ 25 km/h. Mốc dự kiến bám
thời điểm nhận đơn, không chuyển thành “giờ mở màn hình + toàn bộ thời gian”.

| Sự kiện | Hành vi ETA |
| --- | --- |
| Chờ sau khi nhận đơn | Giữ nguyên các giá trị 5/5/5 phút và thời gian hai chặng đã tính. Chỉ số phút còn lại giảm theo thời gian thực. |
| GPS xác nhận xuất phát trước mốc nhận đơn + 5 phút | Giờ giao dự kiến = giờ giao ban đầu − 5 phút. Các chặng, hệ số LightGBM, nhận hàng 5 phút và bàn giao 5 phút giữ nguyên. |
| Xuất phát từ phút thứ 5 trở đi | Không trừ 5 phút; mốc dự kiến ban đầu giữ nguyên. |
| Đến lấy, nhận hàng, đến giao, chờ lấy/giao | Không bỏ thành phần đã hoàn thành, không tính lại tuyến/model, không tự thêm thời gian. |
| Mở lại app, chuyển màn hình | Đọc lại dự báo đã lưu; không bắt đầu một phép tính mới. |
| Qua giờ dự kiến nhưng chưa giao xong | Giữ nguyên giờ dự kiến, báo **Đã quá giờ giao dự kiến**. Không tự kéo dài hoặc báo sắp đến. |
| Đã giao, hủy, chuyển luồng trả hàng | Ngừng hiển thị ETA giao của đơn đang hoạt động. |
| Phân công lại | Xóa ETA của lần phân công cũ, tạo mốc nhận đơn và phép tính riêng cho lần mới. |

Ví dụ: nhận đơn lúc 17:00, dự báo ban đầu 33 phút → 17:33. GPS xác nhận
xuất phát lúc 17:02 → trừ đủ 5 phút, mốc mới 17:28; tại 17:02 còn 26 phút.
Đến lấy sớm lúc 17:06 vẫn giữ 17:28. Mở lại app không trừ thêm 5 phút.
Nếu lần xác nhận xuất phát là 17:06 thì giữ 17:33.

Thời gian nhận hàng và bàn giao đã được điều chỉnh thành 5 phút mỗi phần
theo yêu cầu bổ sung ngày 10/10/2026. Áp dụng cho lần tính ETA đầu tiên sau
cập nhật; snapshot đã lưu giữ các giá trị cũ để bảo toàn dự báo tính một lần.

Bộ nhận diện xuất phát vẫn yêu cầu các mẫu GPS di chuyển liên tiếp, tổng
dịch chuyển ít nhất 30 m; loại mẫu cũ, sai số lớn và nhảy GPS. RPC chỉ cho
tài xế được phân công ghi mốc xuất phát theo giờ server. Bấm Start chưa phải
là bằng chứng di chuyển; mô phỏng phải tạo đủ mẫu hợp lệ. Các trạng thái,
bằng chứng lấy/giao và giám sát hành trình giữ luồng hiện có.

Tái sử dụng model `hcm_utraffic_lgbm_v2_road_profile`; không retrain và không
thu thập dataset mới. Tuyến được chia đoạn khoảng 250 m; model dùng vị trí,
đặc trưng đường, giờ và thứ trong tuần ở UTC+7. Hệ số tổng hợp theo chiều dài
nằm trong khoảng 1–2,2, chỉ nhân thời gian di chuyển. Dự báo giao thông cho
chặng lấy → giao dùng thời điểm bắt đầu chặng dự kiến trong phép tính ban
đầu. Khi trừ 5 phút, không chạy lại model theo thời điểm mới.

Ngoài vùng dữ liệu model, dùng hệ số 1 và công khai ước tính tuyến ở 25 km/h.
Không cộng thêm hệ số giờ cao điểm khác. Đây là dự báo giao thông lịch sử,
không phải quan trắc kẹt xe realtime.

Chỉ tái sử dụng `orders.delivery_eta` (JSONB), không thêm bảng hoặc cột.
Snapshot phiên bản 2 có `calculation_mode=assignment_once_v1`, mốc nhận/
xuất phát, `computed_at` của lần tính đầu, hai chặng và hệ số đã tính,
`initial_total_minutes`, `initial_predicted_at`, `predicted_at` và
`preparation_removed_minutes` bằng 0 hoặc 5. Trường `remaining_minutes`
trong snapshot giữ tổng thời lượng kế hoạch sau ngoại lệ; số phút còn lại
trên UI được tính từ `predicted_at` và giờ server, không lấy trực tiếp trường
này. Không lưu tọa độ, polyline hay lịch sử GPS trong snapshot và không đổi
pipeline R2.

Trigger giữ snapshot khi đổi trạng thái lấy/giao. RPC commit chỉ chấp nhận
kết quả đầu tiên trong cùng lần phân công; những phép tính về sau không ghi
đè, kể cả có `computed_at` mới hơn. Nếu GPS xác nhận xuất phát trong lúc
OSRM đang chạy, commit áp dụng ngoại lệ lên kết quả gốc. Lặp RPC xuất phát
không đổi mốc và không trừ thêm. Đổi tài xế/lần phân công hoặc kết thúc đơn
vẫn ngăn phản hồi cũ ghi sai ngữ cảnh.

Client tiếp tục đồng bộ mỗi 20 giây khi quan sát đơn để nhận ngoại lệ 5 phút
và hiệu chỉnh đồng hồ. Khi đã có snapshot cố định, Edge trả ngay kết quả
đã lưu, không đọc GPS, gọi OSRM hoặc LightGBM lần nữa. `computed_at` cũ
không làm một dự báo cố định bị coi là lỗi. GPS cũ hơn 3 phút hoặc OSRM lỗi
chỉ chặn phép tính đầu nếu chưa có ETA. Sau khi có ETA, mất GPS không đổi
dự báo. Mất kết nối đồng bộ được báo riêng trên dự báo đang giữ trong phiên.

`orders.estimated_delivery_at` là hạn nghiệp vụ do backend cấp cho quy
tắc giao muộn hiện có. Theo chính sách ngày 11/10/2026, hạn bằng
`initial_predicted_at + 25 phút`, lưu cùng transaction với ETA đầu tiên.
Không nhân 1.3 hoặc cộng thêm 15 phút theo công thức cũ. LightGBM đã nằm
trong ETA, không áp dụng lần hai. Trừ 5 phút chuẩn bị không đổi hạn này.
Chưa có ETA thì chưa cấp hạn; refresh có thể thử lại khi GPS/OSRM phục hồi. Xem
[công thức hạn giao](driver_delivery_deadline.md).

Kiểm chứng ngày 10/10/2026: 24 kiểm thử Node; 45 kiểm thử Flutter tập trung
cho ETA, dashboard, tracking, chat và luồng tài xế đã đạt. Analyze feature
ETA và test không có issue. SQL regression đã kiểm tra lưu một lần, đến
sớm không đổi dự báo, trừ đủ 5 phút đúng một lần, ranh giới phút thứ 5,
xuất phát đồng thời với phản hồi tuyến, phân công lại, quyền RPC và bảo
toàn hạn giao; fixture được rollback.

Đã kiểm tra ảnh render bằng font thiết kế ở 320 dp với chữ 160%, 390 dp và
1024 dp; cả trạng thái đủ 5 phút và đã trừ 5 phút hiển thị rõ. Số bảng public
trước/sau là 25; không còn đơn fixture `TEST-ETA`, không tạo lại `driver_locations`.

Migration đầu `20261010135805_staged_delivery_eta.sql` đã thêm cột ETA.
Migration `20261010145042_fixed_assignment_eta.sql` đã áp dụng để sửa các hàm
trên cột có sẵn. Edge `refresh-order-eta` phiên bản 3 đang ACTIVE, kiểm tra JWT
vẫn bật. SQL regression đã đạt trước và sau triển khai, rollback fixture. Xem
[kịch bản kiểm thử đã chỉnh](staged_delivery_eta_test_plan.md) để kiểm tra
trên thiết bị thật. Các test logic/mô hình không thay thế số liệu MAE/RMSE
của ETA giao hàng thực tế; chưa chạy full suite hoặc giao đơn thật để xác
nhận toàn bộ luồng.

Lượt điều chỉnh nhận hàng/bàn giao thành 5 phút mỗi phần: 37 kiểm thử Node
(25 ETA và 12 hạn giao), 17 kiểm thử Flutter trong `order_eta_test.dart` và
SQL regression ETA đã đạt. Snapshot cũ giữ các thời gian đã chốt; dự báo mới
dùng 5/5/5 phút cho chuẩn bị/nhận hàng/bàn giao. Không đổi schema hoặc
Edge cấp hạn giao trong lượt điều chỉnh này.
