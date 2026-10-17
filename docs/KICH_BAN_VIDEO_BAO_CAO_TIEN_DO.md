**Kịch bản video báo cáo tiến độ — GiaoHang**

Thời lượng gợi ý: 8–10 phút. Minh họa một đơn hàng từ tạo đơn đến giao thành
công, sau đó trình bày phần vận hành và những thay đổi kỹ thuật gần đây.
Phần ETA đã cập nhật theo bản mô phỏng mới, triển khai server accept v10 và refresh
v8. Profile v2 phân bổ thời gian chờ gần giao lộ/chỗ rẽ. Cần tạo đơn mới để demo
bản này; ETA đơn đã nhận trước rollout giữ nguyên.
Cần chạy thử
luồng định quay trước khi ghi hình. Chức năng có trong mã nguồn không đồng nghĩa
mọi tình huống đã được kiểm tra trên thiết bị thật.

**Chuẩn bị trước khi quay**

- Mở sẵn hai phiên Delivery App bằng hai tài khoản riêng: khách hàng và tài xế.
  Mở Operations Web bằng tài khoản Admin hoặc CSKH.
- Khởi động lại app để nạp mã mới. Giữ một phiên hoạt động cho mỗi tài khoản
  tài xế, tránh các tab cũ gửi vị trí khác nhau.
- Tài xế đã được duyệt, đang Online, không bị khóa nhận đơn, không có đơn active
  hoặc lời mời khác. Chuẩn bị đủ số dư ví nếu đơn demo yêu cầu giữ tiền.
- Chọn GPS demo TP.HCM và đồng bộ vị trí thành công nếu quay bằng mô phỏng.
  Giới thiệu rõ chế độ này trong video.
- Dùng tuyến demo lấy tại Cửa hàng Thiên Anh, 19A Linh Đông, và giao tại
  Co.op Food, 103 Linh Đông. Chuẩn bị ảnh mẫu nếu bước nhận/giao cần bằng chứng.
- Chuẩn bị một yêu cầu hỗ trợ mẫu để mở trên Operations Web.
- Khi trình bày backend, chỉ quay dữ liệu demo; để ngoài khung hình các màn
  chứa token, khóa truy cập hoặc thông tin tài khoản thật.

| Thời gian | Nội dung | Màn hình |
| --- | --- | --- |
| 0:00–0:35 | Giới thiệu đề tài và tiến độ | Trang chủ app |
| 0:35–1:05 | Bốn vai trò và hai ứng dụng | Delivery App + Operations Web |
| 1:05–2:15 | Tạo đơn và minh họa dự đoán | Chọn địa chỉ, hai kịch bản giờ, phí/ETA |
| 2:15–3:05 | Phân công và nhận đơn | Lời mời trên app tài xế |
| 3:05–5:05 | Theo dõi và hoàn thành giao hàng | Bản đồ tài xế + khách hàng |
| 5:05–6:00 | Quản trị và chăm sóc khách hàng | Danh sách đơn, tài xế, yêu cầu hỗ trợ |
| 6:00–7:30 | Tối ưu GPS, Redis và lưu lịch sử | Redis, bảng drivers, sơ đồ hoặc ghi chú |
| 7:30–8:30 | Kết quả hiện tại và công việc tiếp theo | Danh sách tiến độ ngắn |

**0:00–0:35 — Giới thiệu**

Hình ảnh: trang chủ ứng dụng và tên đề tài. Nói:

> Em chào thầy cô. Trong video này, em báo cáo tiến độ đề tài xây dựng ứng dụng
> quản lý giao hàng thông minh, hỗ trợ theo dõi vị trí và dự đoán thời gian giao
> hàng. Hiện tại, em đã xây dựng các luồng cho khách hàng, tài xế, nhân viên chăm
> sóc khách hàng và quản trị viên. Em sẽ minh họa một đơn hàng từ lúc tạo đơn
> đến khi giao thành công, sau đó trình bày phần tối ưu GPS em vừa thực hiện.

**0:35–1:05 — Tổng quan hệ thống**

Hình ảnh: chuyển nhanh giữa Delivery App và Operations Web. Nói:

> Hệ thống có hai ứng dụng dùng chung backend. Delivery App dành cho khách hàng
> đặt đơn và tài xế thực hiện giao hàng. Operations Web dành cho chăm sóc khách
> hàng và quản trị viên. Em sử dụng Flutter cho giao diện, Supabase cho xác
> thực và dữ liệu nghiệp vụ, OpenStreetMap để hiển thị bản đồ và OSRM để tính
> tuyến đường. Redis lưu vị trí mới nhất và hàng đợi GPS; R2 lưu lịch sử hành trình.

**1:05–2:15 — Khách hàng tạo đơn và phần dự đoán**

Thao tác: mở tạo đơn; bấm **Tuyến mẫu Linh Đông**, sau đó chuyển giữa **Cao điểm ·
18:00** và **Ngoài cao điểm · 12:00**; cho thấy màu tuyến. Có thể đổi điểm giao,
giữ giờ đã chọn rồi so sánh hai giờ trên cùng tuyến mới. ETA hiển thị sau nhận đơn;
chọn một kịch bản, nhập thông tin hàng và tạo một đơn mới. Nói:

> Khách hàng chọn điểm lấy, điểm giao, nhập thông tin hàng hóa và xem phí trước
> khi đặt. ETA chính thức được chốt khi tài xế nhận đơn. Em dùng OSRM lấy đường đi và
> thời gian cơ sở, sau đó LightGBM dự đoán hệ số điều chỉnh để tính ETA cả tuyến.
> Model học trên 115.200 chuyến mô phỏng từ đường Việt Nam. Có thể chọn tuyến
> khác trong vùng TP.HCM, không chỉ dùng những tuyến mẫu đã tạo.
>
> Hai kịch bản này giữ nguyên tuyến đường và thay đổi khung giờ để minh họa
> đầu ra dự đoán khác nhau. Thời gian chạy được mô phỏng theo giờ, đường nhỏ,
> giao lộ và đèn. Trên 426 tuyến chưa học, sai số trung bình khoảng 21 giây trong
> mô phỏng. Hệ thống phân bổ phần thời gian chờ gần giao lộ và chỗ rẽ, rồi dùng
> thời gian từng đoạn để tô màu tuyến và chạy GPS demo. Đây là minh họa mô phỏng,
> chưa đo tắc đường hiện tại. Sau đây em tạo một đơn để tiếp tục luồng giao hàng.

Mốc màu của demo mới thể hiện thời gian chậm thêm so với OSRM: xanh dưới 25%,
vàng từ 25% đến dưới 50%, cam từ 50% đến dưới 75%, đỏ từ 75% trở lên.

Không gọi độ phủ dự đoán 100% trên tuyến demo là độ chính xác 100%. Tuyến hiện
tại ngắn nên chênh lệch thời gian tổng có thể nhỏ; cho thấy số thực tế trên
giao diện, không phóng đại khác biệt. Khả năng dự đoán trên tuyến được chọn
không chứng minh chất lượng ETA của mọi đơn thực tế.

**2:15–3:05 — Hệ thống phân công, tài xế nhận đơn**

Thao tác: chuyển sang app tài xế; mở lời mời, cho thấy điểm lấy và khoảng cách,
rồi nhận đơn. Nói:

> Khi có đơn mới, backend kiểm tra các tài xế đủ điều kiện: đã được duyệt,
> đang sẵn sàng, có GPS còn mới và không có đơn đang giao hoặc hoàn. PostGIS
> lọc các ứng viên gần điểm lấy; OSRM tính tuyến từ tài xế đến điểm lấy để
> xếp hạng theo quãng đường bộ. Hệ thống gửi lời mời đến tài xế phù hợp.
>
> Tài xế xem thông tin rồi nhận hoặc chuyển lời mời. Việc xác nhận nhận đơn
> được kiểm tra ở máy chủ để tránh hai tài xế cùng nhận một đơn. Phần tìm tài
> xế hiện tại dùng truy vấn database và định tuyến; Redis chưa phải nơi trực
> tiếp truy vấn ứng viên để phân công.

Nếu còn thời gian và đã chuẩn bị hai tài xế, có thể quay thêm khoảng 30 giây:
tài xế đầu chuyển lời mời **trước khi nhận**, tài xế tiếp theo nhận được lời mời.
Đây là cảnh bổ sung, không bắt buộc trong video chính.

**3:05–5:05 — Giao hàng và theo dõi vị trí**

Thao tác: đặt màn hình tài xế và khách hàng cạnh nhau nếu có thể. Bắt đầu mô
phỏng di chuyển đến điểm lấy; xác nhận lấy hàng; di chuyển đến điểm giao và
hoàn tất các bước xác nhận giao. Cho khách xem trạng thái hoàn thành. Nói:

> Sau khi nhận đơn, tài xế thấy tuyến đến điểm lấy và tuyến giao hàng. Trên
> ứng dụng khách hàng, vị trí tài xế và trạng thái đơn được cập nhật để khách
> theo dõi tiến trình. Thời gian dự kiến và hạn giao của phân công được backend cấp.
>
> Trong video này em sử dụng GPS mô phỏng để trình diễn hành trình. Tài xế
> đến điểm lấy, xác nhận nhận hàng, tiếp tục đến điểm giao và xác nhận giao
> thành công. Khách hàng nhận được trạng thái mới và có thể xem lại đơn.

Trong cảnh nhận/giao, đọc đúng nhãn nút đang hiển thị và thực hiện đầy đủ
validation của app. Có thể cắt ngắn đoạn di chuyển, giữ lại thao tác và kết
quả trước/sau; chú thích nếu tăng tốc video.

Không giới thiệu ETA là liên tục tính lại theo mọi mẫu GPS. Bản hiện tại sử
dụng snapshot ETA do backend cấp cho phân công; có quy tắc điều chỉnh riêng
khi xuất phát sớm hợp lệ. Nút Start/Stop của mô phỏng không tự tính lại snapshot.

**5:05–6:00 — Quản trị và chăm sóc khách hàng**

Thao tác: trên Operations Web, mở danh sách đơn và tìm đơn vừa giao; mở quản
lý tài xế; sau đó mở yêu cầu hỗ trợ mẫu đã chuẩn bị. Nói:

> Quản trị viên có thể tra cứu đơn, theo dõi trạng thái và quản lý hồ sơ tài
> xế. Nhân viên chăm sóc khách hàng có giao diện tiếp nhận yêu cầu, xem thông
> tin liên quan và trao đổi với người yêu cầu. Phân quyền được kiểm tra ở cả
> giao diện và backend để mỗi vai trò truy cập đúng dữ liệu.
>
> Đây là một yêu cầu hỗ trợ mẫu. Em đã xây dựng luồng tiếp nhận và hội thoại
> để hỗ trợ xử lý các tình huống phát sinh trong quá trình giao hàng.

Không cần quay hết mọi tab. Chọn một màn quản trị và một hồ sơ hỗ trợ để
chứng minh hai vai trò này đã có luồng sử dụng.

**6:00–7:30 — Phần tối ưu vừa hoàn thành**

Hình ảnh: vị trí mới nhất của tài xế trên Redis và các cột vị trí của bảng
`drivers`, hoặc bảng tóm tắt bên dưới. Nói:

> Phần em vừa tối ưu là nhịp ghi GPS. Vị trí hiển thị trên bản đồ tài xế được
> cập nhật theo GPS của thiết bị. Khi đang giao hàng, app gửi mẫu mới nhất lên
> Redis theo nhịp khoảng 5 giây. Backend giới hạn ghi GPS định kỳ vào bảng
> drivers tối đa một lần trong 10 giây; các mốc nghiệp vụ cần đồng bộ ngay được
> xử lý riêng. Nhờ đó, mỗi thay đổi vị trí trên bản đồ không tạo thêm một lần
> ghi vị trí vào database.
>
> Khách hàng nhận vị trí qua Broadcast, tức kênh truyền tin trực tiếp đến các
> màn hình đang theo dõi. Nhịp Broadcast được giữ nguyên và hoạt động độc lập
> với nhịp ghi database.
>
> Lịch sử GPS của đơn được gom thành các phần dữ liệu và lưu trên R2, phục vụ
> phát lại hành trình, đối chiếu sự cố và báo cáo. Em không lưu từng điểm lịch
> sử mới vào PostgreSQL. Lịch sử GPS trên R2 có thời hạn lưu mặc định 14 ngày.
>
> Em cũng đã bổ sung dọn vị trí Redis khi tài xế OFF đủ 30 phút và không còn
> đơn giao hoặc hoàn. Nếu online lại, lịch dọn được hủy. Nếu còn giữ đơn active,
> hệ thống giữ vị trí để tiếp tục theo dõi. Backend đã triển khai và cron đã
> chạy thành công; các trường hợp thời gian và cập nhật đồng thời được kiểm
> tra bằng test.

| Thành phần | Vai trò trong phần GPS |
| --- | --- |
| Bản đồ tài xế | Hiển thị vị trí theo mẫu GPS thiết bị hoặc vị trí mô phỏng |
| Redis | Vị trí mới nhất, GEO và hàng đợi lịch sử; nhận mẫu active khoảng 5 giây |
| Broadcast | Truyền vị trí đến khách đang theo dõi, giữ nhịp hiện tại |
| Bảng drivers | Vị trí mới nhất lâu dài; giới hạn ghi GPS định kỳ 10 giây |
| R2 | Lịch sử hành trình được gom theo đơn; retention GPS 14 ngày |

Có thể minh họa giảm số lần ghi vị trí: ghi mỗi giây là 60 lần/phút/tài xế;
ghi định kỳ 10 giây là khoảng 6 lần/phút. Đây là tính toán nhịp ghi GPS của
`drivers`, không phải số đo tải toàn hệ thống; không tính các mốc đồng bộ ngay,
ghi giám sát hoặc dữ liệu nghiệp vụ khác. Chưa có kết quả kiểm thử 1.000 tài xế
đồng thời để công bố hệ thống đã đáp ứng mức tải đó.

Không cần chờ 30 phút trong video. Trình bày quy tắc và kết quả kiểm thử, hoặc
chèn cảnh trước/sau đã quay theo thời gian thực và ghi rõ thời điểm. Cron chạy
mỗi phút, xử lý tối đa 100 tài xế đến hạn mỗi lượt; với lượng nhỏ thường dọn
trong khoảng 30–31 phút. Cache OFF cũ thiếu mốc bắt đầu đếm từ lúc được quan sát.

**7:30–8:30 — Tiến độ và kế hoạch tiếp theo**

Hình ảnh: danh sách các hạng mục đã triển khai và công việc kế tiếp. Nói:

> Đến hiện tại, em đã triển khai luồng tạo đơn, phân công, nhận và giao hàng;
> theo dõi vị trí; các giao diện quản trị và chăm sóc khách hàng; tích hợp mô
> hình dự đoán ETA toàn tuyến trên dữ liệu mô phỏng; và tối ưu nhịp ghi cùng cơ chế dọn GPS
> Redis. Trong đợt sửa GPS vừa rồi, 40 test backend và 22 test Flutter tập
> trung đã qua, cùng kiểm tra phân tích mã nguồn.
>
> Công việc tiếp theo là kiểm thử toàn bộ quy trình trên các thiết bị thật,
> kiểm tra mất mạng và đóng app đột ngột, đánh giá sai số ETA bằng các chuyến
> thử nghiệm, và cập nhật tài liệu để khớp với phiên bản hiện tại. Trường hợp
> chỉ đóng app khi trạng thái vẫn Online hiện chưa được tự dọn GPS theo quy
> tắc OFF 30 phút. Em sẽ bổ sung xử lý tình huống này.
>
> Đây là tiến độ hiện tại của đề tài. Em mong nhận góp ý của thầy cô về các
> chức năng cần ưu tiên và cách đánh giá kết quả trong giai đoạn tiếp theo.
> Em cảm ơn thầy cô đã theo dõi.

**Các điểm cần nói đúng khi báo cáo**

- Phân công: PostGIS lọc ứng viên, OSRM xếp theo đường bộ, PostgreSQL xác nhận
  nhận đơn. Không nói bản hiện tại tìm tài xế trực tiếp bằng Redis GEO.
- AI: LightGBM học hệ số thời gian cả tuyến từ dữ liệu mô phỏng trên OSM Việt
  Nam. Sai số 21 giây chỉ là benchmark mô phỏng; chưa kiểm chứng ETA thực tế.
  Màu từng đoạn là phân bổ thời gian, không phải AI học nhãn vận tốc từng đoạn.
- Demo: chuyển động mô phỏng cần được gọi đúng tên; chưa thay thế kiểm tra
  GPS ngoài thực địa hoặc theo dõi nền trên Android/iOS.
- Redis: server/Edge Functions cập nhật Redis và database. Redis không tự
  gửi vị trí sang bảng drivers hoặc tự cấp GPS cho Broadcast.
- Mỗi tài xế xử lý một đơn active; VRP nhiều đơn và retrain từ GPS thu thập
  chưa thuộc chức năng đã hoàn thành hiện tại.
- Video là báo cáo tiến độ. Trình bày rõ chức năng đã triển khai, phần được
  minh họa trong video và phần còn cần đo/kiểm thử, không dùng tỷ lệ hoàn
  thành khi chưa có danh sách hạng mục để tính.

Tài liệu đối chiếu: `supabase/functions/README_ROAD_DISPATCH.md`,
`supabase/functions/README_GPS_PIPELINE.md`, `docs/driver_monitoring.md`,
`docs/ETA_MO_PHONG_LIGHTGBM.md` và
`experiments/eta_simulation/README.md`. Bài thuyết trình đề cương cũ và
ROADMAP ngày 01/08/2026 có nội dung chưa khớp triển khai hiện tại.
