# Audit UTraffic, 2026-10-12

Nguồn công khai là [Traffic Flow Data in Ho Chi Minh City, Vietnam](https://www.kaggle.com/datasets/thanhnguyen2612/traffic-flow-data-in-ho-chi-minh-city-viet-nam), bản local version 6 từ bàn giao. Metadata nhà xuất bản được lưu tại [sources/kaggle_metadata.json](../../output/utraffic_speed/sources/kaggle_metadata.json). Kết quả máy đọc được nằm trong [audit.json](../../output/utraffic_speed/audit/audit.json).

## Nhãn và đơn vị

Nhãn là `segment_status.velocity`, thời điểm là `segment_status.updated_at`. Dùng `segment_id` join segments → start/end nodes → streets. Không dùng LOS làm nhãn vận tốc, không lấy velocity/LOS của chính quan sát làm feature, không trộn SmartTraffic và không dùng GPS ứng dụng để huấn luyện.

Đơn vị làm việc là **km/h theo suy luận**, dựa vào thang `max_velocity` và quan hệ vận tốc/vận tốc tối đa được mô tả trong data card. Data card đọc được **không ghi đơn vị velocity một cách tường minh**. Audit và artifact đều đánh dấu `publisher_explicit_unit_verified: false`; không nhân dữ liệu velocity thêm 3,6. Công thức đổi thời gian là `length_m * 3.6 / velocity` giây nếu velocity đang ở km/h. Việc triển khai phải nhìn nhận đây là giả định đơn vị, không phải kết quả xác nhận từ nhà xuất bản.

`max_velocity` là thuộc tính tốc độ tối đa của dataset, chưa được xác nhận là giới hạn tốc độ pháp lý. Không dùng nó để tự gán nhãn vận tốc hoặc chặn nhãn thấp.

## Network và chất lượng join

| Dữ liệu | Số dòng |
| --- | ---: |
| nodes | 577.967 |
| streets | 5.553 |
| segments | 84.633 |
| segments đủ geometry/attributes | 84.479 |
| segments thiếu max_velocity | 74.762 |

Không có ID trùng ở ba bảng network, không thiếu start/end node hoặc street khi join. Có 154 đoạn không đạt yêu cầu attributes, chủ yếu chiều dài không dương. `created_at`/`updated_at` của network được giữ dưới tên riêng để không lẫn timestamp nhãn.

Metadata thiếu được biểu diễn bằng giá trị 0 và cờ missing riêng; không loại nhãn chỉ vì thiếu tốc độ tối đa. Trong 90.533 nhãn giữ lại, 81.976 nhãn thiếu thuộc tính tốc độ tối đa. `type_code` và ID encoding được tạo từ static network, không dùng nhãn hoặc thống kê tương lai. Model được chọn không dùng ID features hoặc tên đường.

## Lọc quan sát

| Quy tắc, theo thứ tự | Số dòng loại |
| --- | ---: |
| Timestamp hoặc velocity không hữu hạn | 0 |
| Velocity ngoài miền phân tích 0–90 | 243 |
| Trùng chính xác segment/time/velocity | 0 |
| Cùng segment/time nhưng nhãn mâu thuẫn | 0 |
| Không join được segment | 0 |
| Geometry/attributes đường không hợp lệ | 162 |
| **Tổng loại** | **405** |
| **Giữ lại từ 90.938 dòng gốc** | **90.533** |

Miền 0–90 là quy tắc phân tích đã khai báo, không phải chứng minh rằng mọi nhãn vượt 90 đều lỗi cảm biến. Raw data được giữ nguyên để đối soát.

Giữ 23.865 nhãn vận tốc 1–2 và 446 nhãn bằng 0. Nhãn 0 vẫn tham gia học vận tốc, chỉ không tham gia metric `d/v` vì thời gian không hữu hạn. Runtime floor 1 km/h, cap 90 km/h cho đầu ra hợp lệ; không đổi các nhãn 0 trong tập train thành 1. Model lỗi hoặc trả vận tốc không hợp lệ dùng fallback 25 km/h theo từng phần tuyến.

## Coverage và chia thời gian

Có nhãn cho 9.959 đoạn trên 120 ngày có quan sát, từ `2020-07-03T14:55:31.869Z` tới `2021-04-22T06:53:27.300Z`. Đây không phải 120 ngày liên tục. Median 5 nhãn/đoạn; 2.708 đoạn chỉ có một nhãn; đoạn nhiều nhất có 2.149 nhãn. Cả giờ 07 và 14 chỉ xuất hiện trên 223 đoạn. Độ phủ không đủ để coi mọi đoạn/giờ là đã được quan sát trực tiếp.

| Split theo ngày UTC+7 | Dòng | Ngày có mẫu | Đoạn | Dòng thuộc đoạn chưa có trong train |
| --- | ---: | ---: | ---: | ---: |
| Train, trước 18/12/2020 | 62.970 | 70 | 6.977 | 0 |
| Validation, 18–27/12/2020 | 11.677 | 10 | 2.391 | 2.682 |
| Test, từ 28/12/2020 | 15.886 | 40 | 3.593 | 5.398 |

Mục tiêu tỷ lệ 70/15/15 theo tích lũy quan sát được làm tròn tới nguyên ngày địa phương. Không random split. Không có ngày giao nhau, train timestamp cuối < validation đầu < test đầu. Early stopping và lựa chọn cấu hình dùng validation; model bị cố định trước đánh giá test. Không refit trên train+validation trong artifact đang đề xuất.

Model học các thuộc tính static của network xuất bản trong dataset, không có snapshot network lịch sử theo từng ngày. Không sử dụng timestamp sửa network làm feature. Baseline trung bình segment/hour chỉ được tính từ train; không đưa trung bình chứa nhãn/future vào model.

Runtime export giữ 56.857 driving edges hợp lệ trong ranh giới demo đang có. 6.722 đoạn trong phạm vi đó có nhãn train, 9.315 đoạn có nhãn ở bất kỳ split nào. Đoạn chưa có nhãn train vẫn có thể được model suy rộng qua features, không phải số đo trực tiếp. Geometry matching là heuristic có quyền từ chối, không phải ground truth map matching.

## Dấu vết nguồn

| File local | SHA-256 |
| --- | --- |
| `nodes.csv` | `f405138088328c60208a484f9215e224610525347b46bb5bdea9a82fde6d326d` |
| `segments.csv` | `ffca2198455225baed8dd59e9ca6123779e16d9d55f50453bba3579ba67c03aa` |
| `streets.csv` | `a4c565f89e16ae3cd3c801aa00fdc537cee0454bd22506cda732d4ad6d794664` |
| `segment_status.csv` | `c7338da7648d43628044a2d1458d2639411fff5eb85ec599b0bbc2b2554af678` |
| `train.csv` | `c42bc62d368acc047537bfdee1f8b9bb22f24500dcdcaffb7d2b0c69e06482b1` |

`train.csv` được hash để đối soát bộ nguồn; nó không được dùng làm nhãn/features cho thí nghiệm này. Không tải thêm dữ liệu nghiệp vụ, tạo bảng, lưu lịch sử GPS hoặc thay đổi pipeline R2.
