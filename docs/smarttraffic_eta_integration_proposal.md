# Đề xuất tích hợp SmartTraffic vào ETA demo

Ngày 2026-10-11. Kết quả đã chạy và artifact:
[`experiments/smarttraffic_eta/BENCHMARK.md`](../experiments/smarttraffic_eta/BENCHMARK.md).

Người dùng đã chấp thuận: **Cho phép tích hợp và triển khai**. Đã triển khai
ngày 2026-10-11; [biên bản kiểm chứng](../experiments/smarttraffic_eta/RUNTIME.md).

## Phạm vi đã được duyệt riêng

Thay phần suy luận AI trong Edge Functions tính ETA bằng model LightGBM
`time_only_lightgbm` đã huấn luyện trên SmartTraffic v1 (dữ liệu mô phỏng), kèm
kiểm thử và triển khai các function có import phần ETA dùng chung. Không tạo bảng,
không sửa schema, RPC, RLS, pipeline GPS/R2 hoặc thu thập thêm GPS huấn luyện.

AGENTS.md yêu cầu: “không thay đổi Supabase schema, RLS policies, migrations,
Edge Functions, hoặc database fields nếu chưa được hỏi và chấp thuận riêng.”

## Thay đổi cụ thể dự kiến

1. Xuất cây của model chỉ thời gian sang payload phục vụ Edge runtime; kiểm tra
   kết quả JavaScript khớp Python trên các mốc giờ và ranh giới ngày.
2. Thay logic dự đoán hệ số K ở
   `supabase/functions/_shared/delivery_eta_traffic.mjs` bằng dự đoán vận tốc.
   Model chỉ thời gian được chọn vì model đường + thời gian không cải thiện
   đáng kể, tọa độ nguồn chưa ánh xạ tin cậy vào đoạn OSRM.
3. Cập nhật `supabase/functions/_shared/delivery_eta.mjs`: từng chặng dùng tổng
   `km / vận tốc dự đoán × 60`, với thời điểm dự kiến đi vào từng phần tuyến.
   Giữ 25 km/h làm fallback có nhãn rõ nếu AI không khả dụng; không nhân thêm K cũ.
4. Thay payload ở `supabase/functions/_shared/delivery_eta_model_data.mjs` khi
   kiểm thử đạt. Lưu model cũ để rollback; cập nhật metadata nguồn thành mô phỏng.
5. Tính một lần cho phân công mới; 5 phút chuẩn bị + 5 nhận hàng + 5 bàn giao.
   Chỉ trừ khoản chuẩn bị một lần khi đủ điều kiện GPS đã thống nhất.
   Hạn giao tiếp tục lấy ETA ban đầu + 25 phút, không thay do đến sớm.
6. Không tính lại đơn đang chạy khi triển khai. Phạm vi AI demo ban đầu dùng
   vùng TP.HCM đã có trong ứng dụng; không tự mở rộng địa lý dựa trên tên dataset.
7. Hiển thị nguồn là “AI từ dữ liệu mô phỏng”; đồng bộ mọi bộ tính ETA phía client
   còn được sử dụng để tránh client và server dùng hai model khác nhau. Thay đổi
   trình bày sẽ theo skill UI của dự án sau khi duyệt tích hợp.

## Kiểm tra trước khi triển khai

- Parity Python/JavaScript, thời gian UTC ↔ Việt Nam, đi qua ranh giới giờ.
- Hai chặng, ba khoản thao tác, fallback khi lỗi, tốc độ không hợp lệ.
- ETA cố định theo phân công, trừ chuẩn bị một lần, deadline ETA ban đầu + 25.
- Mô hình/nguồn thể hiện chính xác trong thông tin ETA; không đổi đơn đang giao.
- Test tập trung phía server và client bị ảnh hưởng; chỉ triển khai sau khi đạt.

## Giới hạn được chấp nhận cho demo

Dữ liệu chỉ có một tuần mô phỏng. AI chủ yếu học quy luật theo giờ, chưa chứng
minh tác động riêng của đường hoặc thời tiết, chưa đo sai số giao hàng thực tế.
Kết quả tương đương bảng trung bình đường/giờ nên không tuyên bố AI vượt trội mọi
phương pháp. Bản xuất runtime đã được duyệt riêng; artifact nghiên cứu vẫn không
tự động cấp quyền triển khai model mới sau mỗi lần huấn luyện.
