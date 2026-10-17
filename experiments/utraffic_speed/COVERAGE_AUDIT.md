# Các đoạn “Ngoài vùng” trên tuyến demo — 2026-10-12

Đây là audit tuyến 1,933 km trước khi đổi demo. Sau yêu cầu bỏ hẳn các đoạn chưa có dự đoán và chọn địa điểm thật, app hiện dùng [tuyến 585 m trên Linh Đông phủ AI đầy đủ](SHORT_DEMO.md); không áp dụng thay đổi probe 5 m nghiên cứu dưới đây. Fixture demo hiện tại đã thay bằng tuyến mới; các số đo bên dưới ghi nhận trạng thái tuyến cũ tại thời điểm audit.

Nhãn `Ngoài vùng` trong `delivery_traffic_map_layer.dart` áp dụng cho mọi `DeliveryTrafficLevel.unavailable`. Nó bao gồm cả thiếu matching trong phạm vi dữ liệu, không chỉ tọa độ ngoài bounds. Các đoạn fallback vẫn dùng chung 25 km/h cho ETA và GPS; màu xanh dương biểu thị không có dự đoán AI.

Audit `utraffic_demo.json` và `utraffic_demo_assignment.json` xác nhận:

- Chặng giao 1.933 m có 91,553 m fallback (4,736%): 81,953 m `no_directed_geometry_match` và 9,599 m `ambiguous_parallel_or_overlapping`. Không có đoạn `outside_scope` trong fixture tuyến này.
- Chặng đến lấy 412,7 m có 77,803 m fallback, đều `no_directed_geometry_match`.
- Các vị trí thiếu matching giống nhau ở Cao điểm/Ngoài cao điểm. Đây là vấn đề ghép geometry/direction/ambiguity, không phải model cho vận tốc không hợp lệ hoặc điểm nằm ngoài bounds.

Replay riêng trong `.tmp/utraffic_gap_resolution.mjs` dùng model, network, matcher và profile builder production. Chỉ đổi `probe_meters` trên matcher của tiến trình thử nghiệm; giữ nguyên các ngưỡng lệch ngang 8 m, lệch hướng 20 độ, slack đầu mút 3 m và ambiguity margin 3 m. Không đổi source runtime, assets hoặc Edge Functions.

| Probe | Độ phủ chặng giao | Fallback chặng giao | Độ phủ đến lấy |
| --- | ---: | ---: | ---: |
| 20 m, hiện tại | 95,264% | 91,553 m | 81,148% |
| 10 m | 97,679% | 44,858 m | 92,834% |
| 5 m | 98,710% | 24,931 m | 95,240% |
| 2 m | 96,263% | 72,228 m | 93,357% |
| 1 m | 95,463% | 87,704 m | 91,401% |

Probe nhỏ hơn giúp một mẫu không trùm qua ranh giới hai segment. Tuy nhiên probe quá nhỏ làm tăng số đoạn bị mơ hồ giữa các road candidates; không thể suy ra “càng nhỏ càng đúng”. Cải thiện độ phủ chưa chứng minh mọi matching mới đúng đường.

Phương án cần chuẩn bị nếu triển khai: dùng probe 5 m sau khi kiểm tra các matching mới và hồi quy đường ngược chiều/song song/giao nhau, đồng bộ Python/JS/Dart và assets; đổi nhãn tổng quát thành `Chưa có dự đoán`; giữ fallback cho phần chưa chắc chắn. Giữ dự báo theo thời điểm dọc tuyến và một profile chung cho ETA/polyline/GPS. Snapshot của đơn đã phân công không bị tính lại. Không retrain, thêm bảng hoặc nới ngưỡng chỉ để tô kín tuyến. Việc sửa và deploy Edge Functions cần được duyệt riêng theo AGENTS.md.

Đã chạy replay 30 trường hợp: mỗi mức probe chạy 2 preview và 4 assignment legs, không gọi dịch vụ ngoài. Chưa thay đổi code sản phẩm, chưa chạy hồi quy cho matcher ứng viên, chưa đánh giá độ đúng của các matching mới và chưa thử trực tiếp trên đơn thật. Số đo này là kết quả thử nghiệm trên tuyến demo hiện tại.
