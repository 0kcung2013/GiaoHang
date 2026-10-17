# Đánh giá lại mô hình vận tốc — 2026-10-12

**Kết luận:** mô hình hiện tại chưa có đủ bằng chứng để biểu diễn tình trạng
giao thông hiện tại bằng màu bản đồ. Kết quả trên dataset cho thấy vận tốc dự
báo bị thu hẹp: nhóm vận tốc cao bị dự báo thấp, nhóm 1–2 km/h bị dự báo cao.
Lợi thế trung bình ở phép quy đổi `d/v` không chứng minh bản đồ hoặc ETA đơn
giao thực tế chính xác.

## Đã kiểm tra gì?

Chạy lại inference của artifact `road_time.joblib` trên đúng **15.886** quan sát
test theo thời gian. Không train, thay model, chọn lại cấu hình hoặc thay ngưỡng
màu. Sai lệch tối đa so với dự đoán lưu trước đó là **7,11 × 10⁻¹⁵ km/h**.
Payload cây, features, target và bounds vận tốc của bản export nghiên cứu,
Flutter và backend đang dùng khớp nhau. Cờ `runtime_approved` khác nhau là
metadata phê duyệt, không tham gia tính toán.

Train trước ngày 18/12/2020, validation từ 18 đến 27/12/2020, test từ
28/12/2020 đến 22/04/2021, theo UTC+7. Test này đã được xem trong benchmark
trước; đây là phân tích chẩn đoán sâu hơn, không phải một tập kiểm thử độc lập
mới để chọn mô hình.

Ảnh người dùng cung cấp là tuyến khoảng 8 km dự báo theo giờ hiện tại. Chưa có
tọa độ hai đầu, geometry hoặc snapshot thời điểm của tuyến đó nên **chưa replay
chính xác tuyến trong ảnh**. Các con số dưới đây thuộc dataset test, không phải
các đoạn trên tuyến 8 km.

## Vận tốc và màu bản đồ

Ngưỡng hiện có: đỏ ≤28, cam >28 đến 34, vàng >34 đến 40, xanh >40 km/h.
Đây là các dải hiển thị vận tốc, chưa phải bộ phân loại kẹt xe có nhãn LOS được
kiểm chứng. Phần không có AI được vẽ xanh dương và không được tính là dự báo đỏ.

| Chỉ số trên test | Kết quả |
| --- | ---: |
| Sai số vận tốc tuyệt đối trung bình | 16,87 km/h |
| Quan sát có nhãn ≤28 km/h | 73,44% |
| Dự đoán ≤28 km/h | 90,49% |
| Trong 4.220 nhãn >28, dự đoán ≤28 | 3.218 mẫu, **76,26%** |
| Trong 14.376 dự đoán ≤28, nhãn >28 | 3.218 mẫu, **22,38%** |
| Khớp chính xác một trong bốn dải hiển thị | 71,57% |
| Trung bình recall của bốn dải | 28,00% |

Tỷ lệ khớp dải 71,57% không thể coi là độ chính xác ETA hoặc vận tốc. Đối chứng
luôn dùng 25 km/h đạt 73,44% khớp dải chỉ vì mọi dự đoán của nó thuộc dải đỏ và
dataset có nhiều nhãn đỏ; trung bình recall của nó là 25%. Cần xem từng dải thay
vì dựa vào một tỷ lệ chung.

Ma trận dưới đây có hàng là **nhãn dataset**, cột là **dải dự báo**:

| Nhãn \ Dự báo | Đỏ | Cam | Vàng | Xanh |
| --- | ---: | ---: | ---: | ---: |
| Đỏ | 11.158 | 310 | 79 | 119 |
| Cam | 706 | 50 | 34 | 23 |
| Vàng | 593 | 67 | 42 | 29 |
| Xanh | 1.919 | 529 | 109 | 119 |

Đặc biệt, chỉ 119/2.676 mẫu có nhãn >40 km/h được dự báo >40 km/h (**4,45%**).

| Nhóm nhãn | Mẫu | Vận tốc nhãn trung bình | Dự báo trung bình | Sai số tuyệt đối trung bình |
| --- | ---: | ---: | ---: | ---: |
| 1–2 km/h | 6.474 | 1,12 | 15,67 | 14,56 km/h |
| 3–28 km/h | 5.192 | 12,71 | 15,83 | 9,05 km/h |
| >28 km/h | 4.220 | 52,08 | 22,41 | 30,05 km/h |
| >40 km/h, nằm trong nhóm >28 | 2.676 | 62,31 | 23,84 | 38,53 km/h |

Sai số có dấu toàn test chỉ -0,93 km/h dễ che hai chiều sai số bù nhau. Nhóm
1–2 bị dự báo cao khoảng 14,55 km/h; nhóm >28 bị dự báo thấp khoảng 29,67 km/h.
Vì vậy không nên sửa bằng một hệ số tăng vận tốc chung.

## Đối chứng ETA và phạm vi dữ liệu

| Phương án cố định trước đánh giá test | MAE vận tốc | MAE thời gian `d/v` mỗi quan sát | MAE `d/v` khi mỗi đoạn có trọng số bằng nhau |
| --- | ---: | ---: | ---: |
| 25 km/h | 21,05 km/h | 61,34 s | **13,31 s** |
| Trung bình lịch sử từ train | 17,64 km/h | 56,25 s | 15,88 s |
| LightGBM đang dùng | **16,87 km/h** | **55,29 s** | 16,05 s |

LightGBM cải thiện MAE `d/v` theo quan sát 9,86% so với 25 km/h. Khi mỗi đoạn
được tính ngang nhau, nó kém đối chứng này. Khoảng 95% theo cụm ngày của lợi
thế so với trung bình lịch sử là [-3,09; 5,60] giây, bao gồm 0. Các metric này
dùng `length_m * 3.6 / velocity_dataset`, không có nhãn thời gian giao đơn thật.

Dataset có 120 ngày không liên tục trong 2020–2021, median 5 nhãn/đoạn. Tỷ lệ
nhãn 1–2 km/h là 20,75% ở train, 37,01% ở validation và 40,75% ở test. Khác biệt
phân bố cần được phân tích; không tự coi mọi nhãn thấp là lỗi rồi xóa chúng.
Đơn vị km/h vẫn là giả định làm việc, chưa được nhà xuất bản xác nhận tường minh.

Mô hình có đầu vào giờ, thứ/ngày cuối tuần và thuộc tính tĩnh của đường. Nó
không nhận lưu lượng xe, sự cố, tín hiệu đèn hoặc vận tốc đang quan sát năm 2026.
Việc truyền thời điểm hiện tại vào model không biến dữ liệu huấn luyện thành
dữ liệu giao thông hiện tại.

## Cách đánh giá tiếp theo

1. **Xác minh dataset:** xác nhận đơn vị vận tốc và ý nghĩa nhãn 0/1/2; kiểm tra
   độ phủ theo đoạn/giờ và cách tạo quan sát. Ghi rõ tiêu chí chất lượng trước
   khi lọc dữ liệu, giữ bản gốc để đối soát.
2. **Đánh giá khả năng suy rộng:** báo cáo riêng đường đã/chưa có mẫu train,
   từng khung giờ và từng dải vận tốc. Nếu phát triển một candidate mới, chọn
   cấu hình bằng validation theo thời gian và giữ một tập test mới chưa dùng
   để tinh chỉnh. Không chọn lại model hoặc ngưỡng dựa vào việc tuyến demo có
   đủ màu. Việc so sánh L1/L2 là thí nghiệm cần đánh giá, chưa phải cách sửa đã
   được chứng minh.
3. **Xác minh đúng tuyến:** lưu đầu ra dự báo có thời điểm, vận tốc từng đoạn,
   nguồn AI/fallback, support và matching; kiểm tra đúng đường, chiều đi và
   các đoạn có tốc độ thấp. Độ phủ AI không phải độ chính xác dự đoán.
4. **Đối chiếu thực tế:** chọn trước nhiều tuyến/khung giờ và so dự báo với thời
   gian chạy thật, tách thời gian di chuyển khỏi chuẩn bị/nhận/giao hàng. Báo
   cáo MAE theo phút và tỷ lệ sai số nằm trong ngưỡng đã đặt trước. GPS mô phỏng
   dùng chính vận tốc AI không phải dữ liệu kiểm chứng độc lập.

Bước 4 hiện chưa có bộ nhãn. Việc bổ sung pipeline hoặc dùng GPS nghiệp vụ để
huấn luyện lại nằm ngoài phạm vi hiện tại và cần được duyệt riêng theo AGENTS.md.
Đánh giá này chưa đổi app, ngưỡng màu, model, database hay Edge Functions.

## Tái lập và nguồn

```powershell
& .\experiments\utraffic_speed\.venv\Scripts\python.exe experiments/utraffic_speed/reassess.py
```

- [reassess.py](reassess.py): đọc artifact cố định, kiểm tra nguồn test,
  chạy inference và tính metric/ma trận dải vận tốc; không gọi `fit`.
- [reassessment.json](../../output/utraffic_speed/reassessment/reassessment.json):
  số liệu chi tiết, breakdown theo giờ/support, kiểm tra model và SHA-256 đầu vào.
- [method_summary.csv](../../output/utraffic_speed/reassessment/method_summary.csv)
  và [speed_band_confusion.csv](../../output/utraffic_speed/reassessment/speed_band_confusion.csv).
- [AUDIT.md](AUDIT.md), [BENCHMARK.md](BENCHMARK.md): nguồn và giới hạn nghiên cứu.
- [Scikit-learn: kiểm định dữ liệu theo thời gian](https://scikit-learn.org/stable/modules/generated/sklearn.model_selection.TimeSeriesSplit.html):
  giữ thứ tự thời gian để tránh học từ tương lai khi đánh giá quá khứ. Quan sát
  UTraffic không cách đều, nên pipeline hiện chia theo ngày và không gọi trực
  tiếp `TimeSeriesSplit` theo chỉ số dòng.
- [LightGBM: objectives](https://lightgbm.readthedocs.io/en/latest/Parameters.html#objective):
  `regression_l1` tối ưu L1; `regression` tối ưu L2. Model đang dùng là raw L1,
  chọn theo MAE `d/v` validation; chưa có thí nghiệm mới ở đánh giá này.
