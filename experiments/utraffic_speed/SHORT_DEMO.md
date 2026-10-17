# Tuyến demo địa điểm thật, phủ AI đầy đủ — 2026-10-12

Demo hiện dùng tuyến **584,6 m**, hiển thị **0,6 km**, trên **Linh Đông**. Hai nút giữ cùng điểm lấy/giao và geometry, chỉ đổi giờ model 18:00/12:00 ngày 16/12/2020. Thay tuyến 600 m Phạm Văn Đồng vì các điểm cắt trên polyline nằm giữa lòng đường và tài xế chỉ cách điểm lấy 30 m.

- Điểm lấy **Cửa hàng Thiên Anh · 19A Linh Đông**: (10.8456193, 106.7459414), [ghim địa điểm OSM](https://www.openstreetmap.org/node/4698366796).
- Điểm giao **Co.op Food · 103 Linh Đông**: (10.850616, 106.747684), tọa độ GeoCoordinates của [listing địa điểm](https://www.foody.vn/ho-chi-minh/co-op-food-linh-dong). Địa chỉ cũng có trong [danh sách cửa hàng của Bộ Công Thương](https://moit.gov.vn/upload/2005517/fck/files/DANH_S__CH_C__C_C___A_H__NG_TI___N_L___I___ANG_HO___T______NG_190721_e7fcf.pdf).
- Tài xế mẫu taixe@gmail.com ở **Cửa hàng Thu Thảo · 68A Linh Đông**: (10.84923, 106.747293), [ghim OSM](https://www.openstreetmap.org/node/4698366795); approach **425,8 m**, đủ điều kiện lời mời trong 2 km đường bộ. Các tài xế mẫu khác giữ vị trí cũ.

Đối chiếu địa điểm công khai với dữ liệu đường OSM hiện tại, rồi thử OSRM trên Võ Văn Ngân, Lê Đức Thọ và Linh Đông. Chỉ chọn khi cả preview, approach và delivery sau dịch thời gian theo ETA đều phủ AI đầy đủ. Ghim lấy/giao/tài xế cách điểm OSRM snap vào tim đường lần lượt 6,79 / 4,74 / 7,45 m; giữ riêng tọa độ địa điểm và geometry lái xe. Đây là ghim địa điểm công khai, chưa phải đo đạc GPS cửa ra vào hoặc xác minh hoạt động cửa hàng tại hiện trường. Không suy từ tên cửa hàng rằng có giao dịch thật.

**Mọi đoạn chặng đến lấy, chặng giao và preview đều ghép được với một segment UTraffic và có dự đoán hợp lệ bằng matcher production hiện tại.** Replay trực tiếp bằng roadRoute + calculateEta production ở cả hai giờ cũng cho 100% trên cả hai chặng. Không đổi model, probe 20 m, ngưỡng matching/màu, fallback của tuyến khác hoặc Edge Functions; không tô lại các đoạn thiếu dự đoán.

| Đầu ra profile | Cao điểm 18:00 | Ngoài cao điểm 12:00 |
| --- | ---: | ---: |
| Thời gian chạy chặng giao | 1,209 phút | 0,907 phút |
| Vận tốc AI | 10,33–36,36 km/h | 19,02–44,09 km/h |
| Vận tốc hiệu dụng | 29,02 km/h | 38,68 km/h |
| Độ phủ dự đoán chặng giao / đến lấy | 100% / 100% | 100% / 100% |
| Đỏ | 90 m | 30 m |
| Cam | 228 m | 0 m |
| Vàng | 267 m | 288 m |
| Xanh lá | 0 m | 267 m |
| Fallback / xanh dương | 0 m | 0 m |

Approach ở 18:05/12:05 mất 0,902 / 0,642 phút, tốc độ 27,74–32,69 / 39,19–44,14 km/h. Chặng giao kiểm tra lại tại origin + 10 phút + approach_minutes, đúng hợp đồng ETA. Tổng ETA ban đầu **17,110 / 16,549 phút**, gồm 15 phút thao tác, làm tròn **18 / 17 phút**. Quy tắc ETA cố định, hạn giao +25 phút, xuất phát sớm, Start/Stop và giám sát giữ nguyên. Tài xế bắt đầu ngoài geofence 100 m điểm lấy; tổng hai chặng **1.010,4 m**.

Một đoạn gần điểm giao dài khoảng **29,75 m** có vận tốc 10,33 km/h lúc cao điểm và 19,02 km/h ngoài cao điểm. Giữ nguyên đầu ra này, không ép vận tốc hoặc màu; 95% chặng giao còn lại có tốc độ cao hơn 15 km/h lúc cao điểm. Test tránh tốc độ thấp kéo dài dùng giới hạn 35 m cho fixture địa điểm thật, thay tiêu chí tỷ lệ 1% của tuyến cắt trước đó. Không đổi giới hạn trong model/runtime.

100% ở đây là độ phủ matching và dự đoán, không phải mọi đoạn/giờ đều có nhãn quan trắc. Tập train trên các segment chặng giao tại cùng giờ có **0 dòng ở cả 18h và 12h**; model dùng đặc trưng đường và thời gian để dự đoán. Không dùng tuyến demo chọn lọc này để kết luận độ chính xác ETA thực tế.

Python/JavaScript khớp section, segment ID, cờ AI, vận tốc và thời gian. Dart kiểm tra 2720 dự đoán đóng băng và 16 route/time fixtures: 10 tuyến hồi quy cũ, 2 preview và 4 assignment legs mới. **45 Flutter tests và 12 Node tests qua; analyze 6 file sạch.** Bao gồm hồi quy đồng bộ GPS trước nhận đơn, kiểm tra ghim địa điểm, khoảng cách approach >100 m, ETA/màu/GPS và Start/Stop. Không chạy full suite hoặc build phát hành; chưa thử đơn thật sau lần đổi sang Linh Đông.

Kiểm chứng live trước lần đổi này: trên tuyến Phạm Văn Đồng 600 m, người dùng tạo/nhận đơn mới và xác nhận chặng tài xế → lấy không còn “Ngoài vùng” sau [bản sửa đồng bộ GPS trước nhận đơn](DISPATCH_FIX.md). Khoảng cách lời mời dưới 1 km hiển thị bằng mét. Không có mã đơn mới để đối soát snapshot lượt thành công.

Đã render fixture 390/1024 px, cùng control sheet 320 px ở text scale 1,6, và xem hai bản 390 px. Ảnh dùng tile trong suốt: [18h](../../output/utraffic_speed/ui_real_places/390_congested.png), [12h](../../output/utraffic_speed/ui_real_places/390_clear.png). Địa chỉ mới đọc được, màu khác nhau và không có đoạn xanh dương. Không coi đây là ảnh app đã đăng nhập hoặc bản đồ nền thật.

Tái lập từ repository root sau khi đã có exports/caches nghiên cứu:

    node experiments/utraffic_speed/confirm_real_places_demo.mjs
    node experiments/utraffic_speed/probe_demo_dispatch.mjs
    node --test experiments/utraffic_speed/test_demo.mjs supabase/functions/_shared/road_distance_test.mjs

Các fixture demo hiện tại đã nằm trong `packages/giaohang_mobile/test/fixtures/`; các script chọn tuyến và installer một lần của các tuyến cũ đã được dọn. `confirm_real_places_demo.mjs` chỉ đối chiếu tuyến địa điểm hiện tại và ghi báo cáo vào `output/`, không sửa app/backend. Hot restart cả hai phiên Flutter, đóng các tab tài xế cũ, tải lại và chọn Demo TP.HCM + Online. Tạo đơn demo mới; đơn đã phân công giữ snapshot đã cấp.

[Chẩn đoán các đoạn thiếu dự đoán trên tuyến cũ](COVERAGE_AUDIT.md) · [Lỗi lời mời và cách kiểm tra](DISPATCH_FIX.md).
