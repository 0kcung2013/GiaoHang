# Kịch bản kiểm thử ETA tính một lần

Kịch bản này thay thế bản trước: không rút ngắn ETA khi tài xế đến sớm hoặc
hoàn thành bước sớm. Các thời gian và hệ số chỉ tính một lần ban đầu.
Ngoại lệ duy nhất là trừ đủ 5 phút khi GPS xác nhận xuất phát trong 5 phút
đầu, một lần. Đây là kết quả mong đợi, chưa phải biên bản đạt trên thiết bị.

Chuẩn bị hai phiên đăng nhập riêng: khách hàng `khachhang@gmail.com` và tài
xế đã được duyệt, bật nhận đơn, có GPS hợp lệ. Chọn điểm lấy trong phạm vi
nhận đơn hiện tại. Giữ mạng ở cả hai phía và mở **Chi tiết thời gian**.
Chọn tuyến trong vùng dữ liệu TP.HCM của model nếu muốn trình diễn LightGBM.

Ở lần nhận đơn, ghi lại mốc giao dự kiến ban đầu E0 và chụp chi tiết các
thành phần. Chờ khoảng một chu kỳ đồng bộ 20 giây cộng thời gian mạng để
đối chiếu hai phía. Nếu chưa có ETA sau khoảng một phút với GPS/mạng hợp
lệ, ghi nhận lỗi gọi backend hoặc tuyến trước khi kiểm tra các bước sau.

| Mã | Thao tác | Kết quả mong đợi |
| --- | --- | --- |
| ETA-01 | Tạo đơn, chưa có tài xế nhận. | Chưa có số phút/giờ giao dự kiến; có thông báo chờ tài xế. |
| ETA-02 | Tài xế nhận đơn, đứng yên và chưa bấm Start. Ghi E0. | Tính và lưu ETA ban đầu một lần: 5 phút chuẩn bị + tài xế → lấy + 5 phút nhận hàng + lấy → giao + 5 phút bàn giao. Chi tiết ghi **Ước tính khi nhận đơn**. |
| ETA-03 | Chờ khoảng 2 phút, mở lại màn hình/app trong khi vẫn đứng yên. | Giờ E0 không đổi. Các dòng chi tiết vẫn là giá trị ban đầu, gồm 5 phút chuẩn bị; số phút còn lại giảm khoảng 2 phút theo thời gian trôi qua. Không có phép tính lại. |
| ETA-04 | Trước khi hết 5 phút đầu, di chuyển thật hoặc bấm Start và chờ đủ mẫu GPS di chuyển hợp lệ. | Mốc mới E1 = E0 − đúng 5 phút. Chi tiết bỏ dòng chuẩn bị và có **Đã trừ 5 phút chuẩn bị**; hai chặng và 5/5 phút xử lý không đổi. Không chỉ trừ phần chuẩn bị chưa dùng. |
| ETA-05 | Tiếp tục di chuyển, mở lại app và đổi giữa tab bản đồ/chi tiết. | Giữ E1, không trừ thêm 5 phút và không cập nhật thời gian chặng theo vị trí mới. |
| ETA-06 | Đến điểm lấy sớm, xác nhận đã đến rồi chờ tại điểm lấy. | Vẫn giữ E1; chặng đến lấy và 5 phút nhận hàng vẫn giữ trong chi tiết ban đầu, không rút ngắn hoặc cộng thêm ngân sách. |
| ETA-07 | Xác nhận nhận hàng nhanh hơn 5 phút, tiếp tục di chuyển. | Vẫn giữ E1 và các giá trị ban đầu. Không tính lại tuyến tài xế hiện tại → giao để thay ETA toàn đơn. |
| ETA-08 | Đến điểm giao sớm và xác nhận đã đến, chưa giao xong. | Vẫn giữ E1. Không đổi ETA thành “hiện tại + 5 phút”, không bỏ thời gian chặng đã hoàn thành. |
| ETA-09 | Hoàn tất giao hàng. | Đơn kết thúc theo luồng hiện có; panel ETA đang hoạt động biến mất. |

Chạy các ca bổ sung trên những đơn riêng:

| Mã | Thao tác | Kết quả mong đợi |
| --- | --- | --- |
| ETA-10 | Nhận đơn, đứng yên hơn 5 phút rồi mới di chuyển. | Giữ E0; không áp dụng giảm 5 phút sau khi cửa sổ chuẩn bị đã hết. Chi tiết giữ các giá trị ban đầu. |
| ETA-11 | Chờ lâu ở điểm lấy/giao và qua giờ dự kiến, chưa giao xong. | Không tự kéo dài ETA, không tự hoàn tất. Giữ giờ đã dự báo, hiển thị **Đã quá giờ giao dự kiến**. |
| ETA-12 | Sau khi đã có ETA, dừng mọi nguồn gửi GPS hơn 3 phút, giữ khách hàng online. | ETA cố định vẫn giữ; không gọi lại tuyến/model và không coi dự báo ban đầu là lỗi chỉ vì GPS đã cũ. Tracking vị trí vẫn phản ánh tình trạng GPS theo luồng hiện có. |
| ETA-13 | Ngắt mạng của màn hình đang quan sát rồi kết nối lại. | Khi đồng bộ thất bại, có nhãn chưa cập nhật trên ETA đang giữ trong phiên. Kết nối lại đọc dự báo đã lưu, không tính một ETA mới. Không giả định lưu offline sau khi đóng app hoàn toàn. |
| ETA-14 | So sánh khách hàng/tài xế sau khi đồng bộ; đổi dashboard, tracking, bản đồ và chi tiết. | Cùng mốc dự kiến cho cùng đơn. Số phút có thể lệch 1 phút ở ranh giới làm tròn khi quan sát khác thời điểm. |
| ETA-15 | Kiểm tra tuyến có model và tuyến hoàn toàn ngoài vùng dữ liệu model. | Trong vùng có nhãn hiệu chỉnh giao thông lịch sử nếu dùng model. Ngoài vùng có nhãn tuyến 25 km/h, hệ số 1. Kết quả đã tính không thay đổi theo giờ quan sát sau đó. |
| ETA-16 | Hủy một đơn theo thao tác được phép. | Ngừng hiển thị ETA giao đang hoạt động. Các điều kiện hủy hiện có vẫn áp dụng. |
| ETA-17 | Mở chi tiết trên màn hình hẹp và chữ lớn. | Giờ dự kiến, chi tiết ban đầu, nhãn giảm 5 phút và trạng thái quá giờ đọc được, không tràn hoặc che thao tác. |

Ví dụ kiểm thử với đầu vào có kiểm soát: nhận đơn lúc 17:00; tài xế → lấy
1 km, lấy → giao 5 km; tốc độ nền 25 km/h; hệ số hai chặng 1,5 và 1,2.

`T_đến_lấy = 1 / 25 × 60 × 1,5 = 3,6 phút`

`T_đến_giao = 5 / 25 × 60 × 1,2 = 14,4 phút`

`T_ban_đầu = 5 + 3,6 + 5 + 14,4 + 5 = 33 phút → E0 = 17:33`

GPS xác nhận xuất phát lúc 17:02 → E1 = 17:28, lúc đó còn 26 phút.
Đến lấy lúc 17:06 → vẫn E1 = 17:28, lúc đó còn 22 phút.
Nhận hàng sớm hoặc đến giao sớm → tiếp tục giữ 17:28.
Nếu lần xác nhận xuất phát là 17:06 → không giảm 5 phút, giữ 17:33.

Các dòng chi tiết làm tròn lên riêng, nên không dùng tổng các số nguyên trên
UI để kiểm tra phép tính chính xác. Đối chiếu dữ liệu chưa làm tròn trong
`orders.delivery_eta` ở chế độ chỉ đọc: `initial_total_minutes`,
`initial_predicted_at`, `predicted_at`, `preparation_removed_minutes`,
`approach`, `delivery` và các thời gian 5/5/5. `computed_at` phải giữ mốc
của phép tính đầu; `predicted_at` chỉ được thay đổi đúng một lần bởi ngoại lệ
5 phút trong cùng lần phân công.

Các ca kiểm thử có kiểm soát trong code:

| Mã | Điều kiện | Kết quả mong đợi |
| --- | --- | --- |
| ETA-A01 | Giữ đầu vào, thay OSRM duration; kiểm tra chặng đến lấy 100 m và 1 km. | ETA dùng distance / 25 × 60; không cộng duration OSRM lần nữa và không ép khoảng cách thành 2 km. |
| ETA-A02 | Đã lưu ETA rồi thay vị trí, thời điểm, trạng thái lấy/giao và hệ số model. | Không gọi lại OSRM/LightGBM; toàn bộ snapshot giữ nguyên. |
| ETA-A03 | Xuất phát tại phút 2; gọi lại RPC nhiều lần; thử ranh giới phút 5 và phút 6. | Chỉ phút 2 được giảm đủ 5 phút, đúng một lần. Từ phút 5 trở đi không giảm. |
| ETA-A04 | GPS xác nhận xuất phát trong lúc phép tính OSRM đầu tiên chưa trả xong. | Lưu kết quả gốc rồi áp dụng ngoại lệ; không mất mốc GPS, không tính lại các chặng. |
| ETA-A05 | Chưa có ETA, GPS thiếu/cũ hoặc OSRM timeout/không có tuyến. | Chờ dữ liệu hợp lệ, không tạo ETA từ khoảng cách chim bay. Sau lần tính thành công thì giữ kết quả đó. |
| ETA-A06 | Cùng thời điểm UTC/UTC+7; hai tuyến mẫu đông/thông thoáng tại giờ cố định. | Dùng cùng thời điểm Việt Nam; model phân biệt hai tuyến mẫu. Không đổi giờ máy để ép kết quả của đơn live. |
| ETA-A07 | Kết quả tính khác về sau, kể cả computed_at mới hơn; phản hồi của lần phân công cũ. | Kết quả đầu tiên được lưu giữ; từ chối sai lần phân công. |
| ETA-A08 | Khách hàng/tài xế khác ghi xuất phát; client ghi snapshot trực tiếp. | Không được phép. Tài xế được phân công được ghi mốc xuất phát, service role được commit kết quả đầu. |
| ETA-A09 | Lưu ETA, giảm 5 phút và đồng bộ nhiều lần. | Lần lưu đầu cấp hạn = initial_predicted_at + 25 phút. Giảm 5 phút và đồng bộ lại không đổi hạn; không thêm bảng/cột, không ghi tọa độ hoặc lịch sử GPS vào ETA. |

Nguồn kiểm thử:

- [Node: ETA, OSRM và LightGBM](../supabase/functions/_shared/delivery_eta_test.mjs).
- [Flutter: hiển thị và nhận diện di chuyển](../apps/delivery_app/test/order_eta_test.dart).
- [SQL: lưu một lần, ngoại lệ 5 phút, quyền và phản hồi đồng thời](../supabase/tests/staged_delivery_eta.sql).
- [Hợp đồng ETA đã sửa](staged_delivery_eta.md).

24 test Node và 45 test Flutter tập trung đã đạt; analyze không có issue.
SQL regression mới đã đạt khi chạy trong transaction và rollback toàn bộ
fixture. Các ca thủ công chưa được đánh dấu đạt trên thiết bị thật. Lượt
HTTP smoke trước đó bị timeout, nên cần kiểm tra ETA-02 để xác nhận luồng
đăng nhập → Edge → OSRM trên thiết bị.

Lượt điều chỉnh nhận hàng/bàn giao thành 5 phút mỗi phần đã đạt 37 test Node,
17 test Flutter ETA và SQL regression; Edge `refresh-order-eta` phiên bản 3
đang ACTIVE. Dùng đơn chưa có snapshot ETA để kiểm tra chính sách mới.
Đơn đã chốt snapshot theo chính sách cũ giữ nguyên các thời gian đã tính.

Ghi mỗi ca bằng mã đơn, thời điểm, các bước đã làm, kết quả thực tế và ảnh
hai phía. Có thể dùng bảng mẫu:

| Mã ca | Mã đơn / thời điểm | E0 / E1 đã ghi | Kết quả thực tế | Đạt / không đạt / chưa chạy | Bằng chứng |
| --- | --- | --- | --- | --- | --- |
| ETA-02 | | | | Chưa chạy | |
| ETA-03 | | | | Chưa chạy | |
| ETA-04 | | | | Chưa chạy | |
| ETA-06 | | | | Chưa chạy | |
| ETA-08 | | | | Chưa chạy | |
| ETA-10 | | | | Chưa chạy | |

Lượt demo cho giám khảo nên cho thấy dự báo ban đầu → xuất phát sớm làm
giảm đúng 5 phút → đến lấy/giao sớm nhưng dự báo giữ nguyên → hoàn tất đơn.
Mô phỏng dùng để chứng minh luồng; tốc độ mô phỏng không phải tốc độ nền
25 km/h và không chứng minh MAE/RMSE thời gian giao hàng thực tế.
