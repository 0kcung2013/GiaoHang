# GH-10225 không có lời mời — 2026-10-12

Các phần dưới ghi lịch sử chẩn đoán của tuyến 3,5 km, 1,9 km và 600 m Phạm Văn Đồng. Demo hiện dùng [tuyến địa điểm thật 585 m trên Linh Đông](SHORT_DEMO.md), tài xế mẫu `(10.84923,106.747293)` cách điểm lấy 426 m theo OSRM. Cần hot restart các phiên app để đồng bộ điểm mẫu mới; không đổi pipeline hoặc bán kính phân công.

Nguyên nhân là vị trí tài xế mẫu chọn khi rút tuyến 3,5 km: `(10.8340,106.6953)` cách điểm lấy 1,42 km theo GPS nhưng **2.628,8 m theo OSRM**. Bộ lọc `rankDriversByRoadDistance` chỉ cho tự động mời trong 2.000 m đường bộ. Test cũ chỉ xét đường chim bay nên cho kết quả sai.

Query chỉ đọc xác nhận GH-10225 có đúng pickup/delivery tuyến 3,5 km, trạng thái pending, chưa có tài xế/lời mời; tài xế mẫu online, approved, GPS mới và lock đã hết hạn. Replay OSRM qua chính module production trả `eligible:false`. Test mới kiểm tra road-distance fixture thất bại với 2.628,8 m trước khi sửa.

Bản sửa đầu chuyển tài xế lên cùng chiều đường trước điểm lấy: OSRM **504,2 m**, `eligible:true`. Người dùng hot restart hai phiên Flutter và tìm lại tài xế qua luồng khách hiện có. Query sau đó xác nhận GH-10225 đã assigned và delivering, snapshot ETA v5, model UTraffic. Không dùng SQL để ép nhận đơn, đổi deadline hoặc thay trạng thái.

Sau phản hồi tiếp theo về GPS chạy 8–15 km/h, snapshot GH-10225 xác nhận approach AI 7,85–15,07 km/h, effective speed 12,96; delivery effective speed 18,10 km/h. Chọn [tuyến mới 1,9 km](SHORT_DEMO.md) có vận tốc cao hơn ở cả approach và delivery. Điểm tài xế hiện tại `(10.827950,106.720965)` đến pickup mới bằng OSRM **412,7 m**, đủ điều kiện. GH-10225 đang giao giữ nguyên profile đã cấp.

Hồi quy mới `traffic_demo_driver_availability_test.dart` gắn tọa độ source với replay OSRM, kiểm tra đường bộ ≤2 km và snap ≤100 m; Node replay dùng module phân công production. Các tests GPS/device-mode vẫn xác nhận chỉ chế độ Demo TP.HCM dùng tọa độ mẫu. Source backend, schema, RLS, migrations, bán kính phân công và pipeline GPS/R2 giữ nguyên.

38 Flutter tests và 10 Node tests tập trung qua sau cập nhật tuyến cuối; analyze 8 file không có issue. Có ảnh widget fixture 320/390/1024 px. Công cụ browser không thấy tab Chrome/Edge được kết nối nên phần xác minh live GH-10225 dựa trên phản hồi người dùng và query server; chưa có E2E tự động trên đơn mới 1,9 km.

## GH-10226: lời mời xuất hiện sau 4 phút 20 giây

Đối soát chỉ đọc ngày 2026-10-12, giờ TP.HCM:

- Tạo đơn lúc 09:00:19.475; dispatcher trả HTTP 200 lúc 09:00:19.880, `offered:0, waiting:1`. Các lần chạy tiếp theo cách nhau khoảng 5 giây cũng chưa có ứng viên được cấp lời mời. Không có lỗi HTTP, timeout hoặc chờ tới hết 15 phút mới bắt đầu phân công.
- Cấp lời mời lúc 09:04:39.088, nhật ký ghi OSRM 413 m. Khoảng cách này khớp vị trí demo mới. GH-10225 đã delivered lúc 08:43:49, nên đơn cũ không giữ tài xế bận tại thời điểm này.
- Lời mời 45 giây hết hạn lúc 09:05:24.165; hệ thống ghi nhận một lượt bỏ qua và đưa tài xế vào `rejected_by` của GH-10226. Không xóa lượt, không ép cấp lại lời mời hoặc sửa trạng thái bằng SQL.
- GPS latest trên server lại ở điểm cũ `(10.8340,106.6953)` tại 09:05:33 và 09:06:32. Replay chính `rankDriversByRoadDistance` bằng OSRM table cho điểm cũ đến pickup mới **5.620 m, eligible:false**; điểm mới `(10.827950,106.720965)` **412,7 m, eligible:true**. Đây là lỗi không đồng bộ phiên demo/client; dữ liệu GPS latest không giữ lịch sử chờ đơn nên chưa thể xác định tab phát GPS cũ hoặc dựng lại mọi mẫu của bốn phút đầu.
- Tải source `ingest-driver-location` đang triển khai vào `.tmp/gh10226_remote` để đọc: function ghi tọa độ request, không chứa điểm demo cũ và không đổi tọa độ về điểm đó. Không sửa hay deploy function.
- Sau khi người dùng đóng các tab tài xế khác, hot restart phiên tài xế và chọn Demo TP.HCM + Online, query xác nhận hai heartbeat mới tại 09:09:33 và 09:10:33 cùng giữ đúng `(10.827950,106.720965)`, online, approved, không có đơn active hoặc khóa nhận đơn đang hiệu lực.

Cửa sổ tìm tài xế của GH-10226 kết thúc 09:15:19.475. Để kiểm chứng thời gian cấp lời mời sau khởi động lại, dùng nút tìm lại tài xế của khách sau thời điểm này; chưa xác nhận lượt thử đó trong lần audit này. 15 phút là hạn tìm tài xế tối đa, không phải độ trễ cấp lời mời. Không thay đổi code runtime, bán kính, ETA/hạn giao, giám sát, schema, pipeline GPS/R2 hoặc Edge Functions trong lần audit này; chỉ đối soát server, replay OSRM và bổ sung tài liệu.

## GH-10228/GH-10229: khoảng cách 0.0 km và chặng đến lấy còn fallback

Người dùng xác định phần thiếu dự đoán nằm ở tài xế → điểm lấy, không phải tuyến preview lấy → giao. Ảnh GH-10228 ghi “0.0 km” vì 30 m bị làm tròn một chữ số theo km. Utility hiển thị khoảng cách được sửa: dưới 1 km dùng mét; ví dụ đến lấy 30 m, giao 600 m, tổng 630 m. Giữ nguyên dữ liệu khoảng cách OSRM.

Một lần query chỉ đọc GH-10229 thành công lúc 10:05:37 xác nhận đơn mới dùng điểm lấy/giao 600 m, assigned và ETA v5, nhưng GPS latest trên server vẫn `(10.827950,106.720965)`, cập nhật lúc 10:05:21. Ảnh navigation cho thấy chặng đến lấy dài hơn 30 m và có đoạn xanh dương. Không lấy được toàn bộ snapshot ETA: các truy vấn sau bị CLI từ chối HTTP 403 ở bước khởi tạo login role. Không kết luận số mét fallback hoặc điểm neo của snapshot khi chưa đọc được nó.

Replay OSRM thật qua chính roadRoute và calculateEta production với điểm mẫu mới `(10.832997,106.727469)` trả approach 30 m / delivery 600 m, cả hai `all_sections_ai:true`, độ phủ 1.0, không fallback. Dữ liệu node/geometry thực tế vẫn đạt matching dù URL backend không có steps=true. Đây là bằng chứng bộ matcher có thể dự đoán đầy đủ khi backend nhận đúng điểm xuất phát.

Bản sửa Flutter:

- Hai lối nhận lời mời (thẻ đơn và overlay) dùng chung driverOfferAcceptanceProvider.
- Riêng đơn AI demo trong mode Demo TP.HCM với tài khoản có GPS mẫu: publish điểm mẫu bằng ingest hiện có với force + prioritySync, rồi đọc lại GPS bằng RPC profile hiện có; chỉ gọi nhận đơn nếu điểm server cách điểm mẫu không quá 0,5 m. prioritySync sử dụng nhánh force latest PostgreSQL đã tồn tại trong navigation, tránh Redis đã cập nhật nhưng drivers bị throttle 8 giây.
- Nếu ghi bị lỗi hoặc bị ghi đè, không gọi nhận đơn từ tọa độ cũ. Không tự chuyển/từ chối lời mời. Luồng GPS thật, demo vị trí hiện tại và đơn thông thường giữ nguyên.
- Không thay đổi code pipeline ingest/history/R2, backend, schema, RLS, database fields, bán kính, deadline, Start/Stop hoặc snapshot của đơn đã nhận.

Hồi quy stale GPS tái hiện thất bại trước sửa: callback nhận đơn dùng tọa độ cũ trước khi write hoàn tất; write không thành công vẫn gọi nhận. Sau sửa, kiểm thử chờ write/read, từ chối vị trí cũ và giữ ba luồng không cần GPS mẫu đều qua. Hai test widget kiểm tra cả thẻ đơn/overlay đi qua gate này. Kiểm thử định dạng, loading, retry, 320/390/1280 px và text scale 1.0/1.6 tập trung; không chạy full suite hoặc release build.

21 Flutter tests tập trung qua; analyze 9 file production/tests sạch, kiểm tra lại 3 file capture sau khi sửa harness. Đã render và xem [thẻ quãng đường 30 m / 600 m](../../output/utraffic_speed/ui_driver_offer/short_pickup_390.png) ở 390 px; đây là fixture widget, không phải ảnh phiên đăng nhập thật. Font chỉ bổ sung cho capture test trong thư mục tạm, không đổi assets sản phẩm.

Người dùng hot restart phiên tài xế, chọn Demo TP.HCM + Online, tạo và nhận đơn mới rồi xác nhận **“đã ok, không còn đường Ngoài vùng”** ở chặng tài xế → điểm lấy. Không được cung cấp mã đơn mới; chưa đối soát snapshot của lượt thành công trên server. GH-10229 giữ snapshot đã cấp.
