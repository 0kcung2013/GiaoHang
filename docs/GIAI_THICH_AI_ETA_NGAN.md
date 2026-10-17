# Cách trình bày AI và ETA

**AI dự đoán tốc độ xe. Hệ thống dùng quãng đường và tốc độ đó để tính ETA.**

Mô hình LightGBM đã học 216.000 mẫu tốc độ mô phỏng trên đường OSM thật.
Đầu vào gồm loại đường, độ cong, giao lộ, đèn tín hiệu, mức cao điểm và cuối tuần.
Khi chọn tuyến mới, mô hình dự đoán tốc độ trên các phần của tuyến; cùng kết quả
dùng cho ETA, màu đường và xe mô phỏng. Tốc độ di chuyển tối thiểu 15 km/h.

Trên app chỉ cần nhìn ba số: **quãng đường — tốc độ trung bình — thời gian**.
Ví dụ tuyến 3 km có tốc độ trung bình dự kiến 30 km/h: đi mất 6 phút.
Thời gian chuẩn bị, nhận hàng và bàn giao được cộng riêng.

## Lời trình bày khoảng 30 giây

“Em dùng LightGBM dự đoán tốc độ di chuyển từ đặc điểm đường và khung giờ.
Dữ liệu huấn luyện là tốc độ giao thông mô phỏng trên mạng đường thật.
Hệ thống tính thời gian đi theo quãng đường và tốc độ AI dự đoán, rồi cộng
thời gian chuẩn bị, nhận và bàn giao thành ETA. Màu đường và chuyển động
tài xế cũng dùng cùng tốc độ nên thống nhất với ETA.”

## Nếu giám khảo hỏi thêm

- **AI đóng góp gì?** Dự đoán tốc độ; tốc độ quyết định thời gian di chuyển.
- **Dữ liệu thật hay giả?** Đường thật từ OSM, tốc độ là dữ liệu mô phỏng.
- **Tuyến mới có chạy không?** Có, khi OSRM định tuyến được trong vùng demo;
  mô hình học đặc điểm đường để áp dụng cho tuyến mới.
- **Tốc độ trung bình tuyến lấy ở đâu?** Tổng quãng đường chia tổng thời gian
  di chuyển AI dự đoán; không cộng thời gian dừng vào tốc độ này.
- **Tại sao xe chậm lại khi rẽ?** Mô hình được train với mẫu trước cua, tại cua
  và sau cua. App nhận diện góc rẽ trên đường đi rồi đưa mức ảnh hưởng của cua
  vào AI. Một ví dụ đã kiểm tra: 48 → 34 → 21 → 34 → 49 km/h.
- **Đường thẳng chỉ chạy 30 km/h?** Bản mới có đường lớn thông thoáng khoảng
  46–50, đường dân cư thẳng 35–40, hẻm 21–25 km/h ngoài cao điểm. Tốc độ
  trung bình cả tuyến có thể vẫn quanh 30 vì gồm cả đoạn hẻm và cua.

Dữ liệu dễ xem: `output/eta_simulation/segment_ai/route_average_speeds.csv`.
80 tuyến chưa dùng train, 240 trường hợp thời gian, có tốc độ trung bình mẫu,
tốc độ trung bình AI và thời gian dự đoán để đối chiếu.
