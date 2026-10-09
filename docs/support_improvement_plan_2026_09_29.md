# Kế hoạch cải thiện CSKH — làm tiếp ngày 29/09/2026

Ngày ghi nhận: 28/09/2026.

**Cập nhật 30/09/2026:** Đã triển khai phần giao diện/hướng dẫn được mô tả trong
[báo cáo triển khai](support_improvement_implementation_2026_09_30.md).
Các checklist bên dưới giữ trạng thái nghiệm thu xuyên suốt: chưa đánh dấu hoàn
tất Bước 1 hoặc toàn bộ luồng vì chưa kiểm thử bằng phiên đăng nhập thực tế.

Tài liệu ghi lại ý tưởng và thứ tự thực hiện cho buổi làm việc tiếp theo. Tại thời điểm lập tài liệu, các mục đề xuất bên dưới **chưa được triển khai**; việc lưu tài liệu không có nghĩa đã phê duyệt thêm thay đổi database. Tiến độ triển khai mới nhất xem báo cáo cập nhật ở trên.

## 1. Mục tiêu và quyết định đã thống nhất

CSKH cần giải quyết được vấn đề của khách hàng và tài xế, với ít thao tác và đủ thông tin để ra quyết định.

- Giữ ba trạng thái chính: **Mới → Đang xử lý → Kết thúc**.
- Nhận xử lý chỉ xác định người phụ trách; không đồng nghĩa đã phản hồi.
- Phản hồi không đồng nghĩa đã giải quyết xong. Chỉ kết thúc sau khi hoàn thành công việc nghiệp vụ còn lại và ghi kết quả.
- Có thể mở lại cùng hồ sơ, giữ lịch sử trao đổi và kết quả các lần xử lý trước.
- “Cần khách phản hồi”, “Cần xác minh”, “Chờ bàn giao” là thông tin việc còn phải làm, không bổ sung thành một chuỗi trạng thái chính phức tạp.
- Ưu tiên tái sử dụng bảng, RPC và dữ liệu hiện có. Không tạo bảng chỉ để phục vụ tab, nhãn hoặc checklist trên UI.

## 2. Điểm xuất phát: đã làm gì?

Chi tiết hiện trạng: [support_workflow_changes.md](support_workflow_changes.md).

| Hạng mục | Tình trạng khi lập tài liệu |
|---|---|
| Ba trạng thái hiển thị, nhận xử lý, kết thúc, mở lại | Đã sửa mã |
| Hàng đợi, hội thoại, thông tin đơn, liên kết yêu cầu–sự cố | Đã sửa mã |
| Phân biệt người nhận với ghi chú nội bộ | Đã sửa mã |
| Thông báo mới liên kết đúng hồ sơ | Đã sửa mã và backend |
| Migration `20260928124549_streamline_support_workflow.sql` | Đã áp dụng lên Supabase DATN |
| Test/analyze tập trung cho Flutter | Đã đạt |
| SQL: quyền truy cập, kết thúc/mở lại, chặn hoàn/bàn giao chưa xong | Đã đạt qua kiểm thử dữ liệu giả có rollback |
| Kiểm thử xuyên suốt bằng phiên đăng nhập CSKH–khách hàng–tài xế | **Chưa thực hiện đầy đủ** |
| Kiểm thử nhiều phiên thao tác đồng thời, tải lớn | **Chưa thực hiện** |

Không áp dụng lại migration đã triển khai. Dự án dùng Supabase đang kết nối; Docker không phải điều kiện bắt buộc để tiếp tục.

## 3. Ý tưởng trọng tâm: hướng dẫn theo từng vấn đề

Thêm khối **“Việc cần làm”** trong hồ sơ CSKH. Khi mở hồ sơ, nhân viên hiểu ngay:

1. Người dùng đang gặp vấn đề gì và đơn đang ở bước nào?
2. Đã có thông tin/bằng chứng nào, còn thiếu gì?
3. Cần liên hệ bên nào và được phép thực hiện hành động gì?
4. Điều kiện nào còn ngăn kết thúc?

Khối này gợi ý bước tiếp theo từ loại vấn đề, trạng thái đơn, quyền nhân viên và trạng thái can thiệp hiện có. Không tự kết luận lỗi tài xế, tự hoàn tiền hoặc tự đổi trạng thái đơn chỉ dựa vào nội dung chat.

### Các nhóm tình huống nên làm trước

| Tình huống | CSKH cần xác minh | Hướng thao tác | Điều kiện kết thúc đề xuất |
|---|---|---|---|
| Không liên hệ được người nhận | Đúng địa chỉ/số liên hệ, các lần liên hệ, hàng đã được lấy chưa | Liên hệ khách; hướng dẫn tài xế; dùng luồng hoàn/bàn giao hiện có nếu phù hợp | Có phương án xử lý và phần giao/hoàn/bàn giao liên quan đã hoàn tất |
| Giao chậm | Trạng thái đơn, mốc thời gian, vị trí mới nhất, nguyên nhân tài xế cung cấp | Thông báo tình hình cho khách; xác minh với tài xế; chuyển sự cố nếu cần can thiệp | Vấn đề được giải quyết hoặc đã có kết quả xử lý rõ; không còn việc nghiệp vụ bắt buộc |
| Hàng hư hỏng hoặc thiếu | Ảnh nhận/giao, mô tả, bên báo cáo và thời điểm phát hiện | Thu thập bằng chứng từ hai bên; chuyển xử lý sự cố theo quyền | Có kết luận dựa trên bằng chứng và kết quả được thông báo |
| Thanh toán hoặc phí | Phương thức thanh toán, phí đơn, giao dịch hiện có | Giải thích theo dữ liệu; chuyển đúng người có quyền nếu cần điều chỉnh | Đã đối soát và xử lý yêu cầu; không ghi “đã hoàn tiền” khi chưa có giao dịch xác nhận |
| An toàn hoặc sự cố nghiêm trọng | Tình trạng hiện tại, nhu cầu hỗ trợ khẩn cấp, vị trí/bằng chứng phù hợp | Ưu tiên hồ sơ; chỉ dẫn theo quy trình được duyệt; chuyển Admin theo quyền hiện có | Theo quy tắc sự cố nghiêm trọng; không cho CSKH vượt quyền |

Đây là khung đề xuất để đối chiếu với code và nghiệp vụ. Không mặc định mọi loại yêu cầu phải chờ đơn giao xong mới được kết thúc; điều kiện phải gắn với chính vấn đề đang xử lý.

## 4. Cải thiện đường vào hỗ trợ của khách hàng và tài xế

- Từ chi tiết đơn, người dùng chọn vấn đề cụ thể thay vì bắt đầu bằng một ô chat trống.
- Tự gắn mã đơn, người gửi và trạng thái đơn. Không yêu cầu nhập lại thông tin hệ thống đã biết.
- Chỉ hỏi thêm dữ liệu phù hợp: mô tả, ảnh hoặc thông tin còn thiếu. Không bắt mọi trường hợp phải gửi ảnh.
- Hiển thị hướng dẫn ngắn để tự xử lý nếu phù hợp; vẫn có đường rõ ràng để gửi yêu cầu CSKH.
- Nếu có hồ sơ đang xử lý cho cùng vấn đề, ưu tiên mở lại hội thoại đó. Không gộp mọi vấn đề của cùng một đơn thành một yêu cầu duy nhất.
- Với sự cố an toàn, tránh bắt người dùng đi qua nhiều bước hướng dẫn trước khi tiếp cận hỗ trợ.

## 5. Bố cục làm việc của CSKH

Trên web rộng, đề xuất bố cục ba vùng:

| Vùng | Nội dung chính |
|---|---|
| Trái: hàng đợi | Hồ sơ cần xử lý, người gửi, vấn đề, thời gian chờ, người phụ trách |
| Giữa: trao đổi | Hội thoại đang chọn, người nhận rõ ràng, ô trả lời và ghi chú nội bộ |
| Phải: thông tin và hành động | Đơn hàng, bên liên quan, bằng chứng, “Việc cần làm”, kết quả xử lý |

Khi màn hình hẹp, chuyển vùng thông tin sang tab/panel có thể mở; giữ hội thoại và hành động chính dễ truy cập. Tiếp tục dùng `DESIGN.md`, skill `giaohang-flutter-ui` và token hiện có; không đổi design system toàn dự án.

Các điểm cần rà soát khi thực hiện:

- Nút chính theo ngữ cảnh: **Nhận xử lý**, hành động nghiệp vụ phù hợp, hoặc **Kết thúc**.
- Khi chưa được kết thúc, nêu lý do cụ thể và đường đến việc cần hoàn tất; không chỉ hiện lỗi chung sau khi bấm.
- Cho xem bằng chứng và đơn hàng mà không mất nội dung đang soạn.
- Thể hiện lỗi/mất kết nối và cách thử lại; không luôn hiển thị như đang kết nối realtime bình thường.

## 6. Trao đổi với nhiều bên nhưng giữ đúng quyền riêng tư

Một sự việc có thể cần CSKH hỏi riêng khách hàng và tài xế. Các cuộc trao đổi được liên kết về sự việc để nhân viên tổng hợp, nhưng người dùng chỉ thấy kênh họ được phép truy cập.

- Nhãn người nhận phải rõ, ví dụ “Gửi khách hàng — Nguyễn A” hoặc “Gửi tài xế — Trần B”.
- Ghi chú nội bộ tách rõ khỏi phản hồi gửi người dùng.
- Không tự sao chép toàn bộ chat khách hàng sang tài xế hoặc ngược lại.
- Khi sự cố có kết quả, CSKH có thể soạn phản hồi phù hợp cho từng bên; không tự phát tán kết luận/ghi chú nội bộ.
- Kiểm tra lại kênh liên quan khi hồ sơ không gắn đơn hàng.

## 7. Hỗ trợ thao tác nhanh

- Mẫu trả lời theo tình huống, cho nhân viên xem và sửa trước khi gửi. Không gửi tự động.
- Gợi ý thông tin cần bổ sung thay vì yêu cầu nhân viên tự nhớ toàn bộ quy trình.
- Tóm tắt kết quả trước khi kết thúc: đã làm gì, kết quả ra sao, bên nào đã được thông báo.
- Hàng đợi phân biệt hồ sơ chưa có người nhận và hồ sơ người dùng đang chờ phản hồi.
- Ưu tiên theo mức ảnh hưởng thực tế: an toàn, hàng đang chờ xử lý, thời gian chờ. Không dùng mức ưu tiên như kết luận lỗi hoặc điểm phạt.

Giai đoạn đầu có thể dùng cấu hình Dart và trạng thái suy ra từ dữ liệu hiện có. Nếu cần lưu checklist, lý do chờ hay mẫu trả lời dùng chung, phải đánh giá cấu trúc hiện có trước khi đề xuất thay đổi backend.

## 8. Thứ tự làm tiếp

### Bước 1 — kiểm tra bản hiện tại bằng các vai trò thực tế

- [ ] Mở app từ mã mới với các tài khoản kiểm thử được phép sử dụng.
- [ ] Khách tạo yêu cầu → CSKH nhận → phản hồi → khách nhận thông báo và mở đúng hồ sơ.
- [ ] Làm tương tự với tài xế; kiểm tra ghi chú nội bộ không xuất hiện ở phía người dùng.
- [ ] CSKH kết thúc → người dùng mở lại → lịch sử còn nguyên và trạng thái đồng bộ.
- [ ] Kiểm tra sự cố liên quan, hoàn/bàn giao chưa xong và thông báo giải thích lý do bị chặn.
- [ ] Ghi lại lỗi tái hiện được trước khi mở rộng thiết kế.

### Bước 2 — hoàn thiện một tình huống từ đầu đến cuối

Ưu tiên **“Không liên hệ được người nhận”** vì thể hiện rõ phối hợp khách hàng–tài xế–CSKH và có thể tái sử dụng luồng hoàn/bàn giao hiện có.

- [ ] Đối chiếu trạng thái, quyền và RPC hiện có.
- [ ] Xác định thông tin đầu vào tối thiểu và điều kiện kết thúc.
- [ ] Thêm hướng dẫn “Việc cần làm” cùng các nút hành động đúng ngữ cảnh.
- [ ] Kiểm thử từ gửi yêu cầu đến kết thúc, bao gồm lỗi, mất kết nối và mở lại.

### Bước 3 — mở rộng từ tình huống đã ổn định

- [ ] Áp dụng cấu trúc phù hợp cho giao chậm, hàng hư hỏng/thiếu và thanh toán.
- [ ] Bổ sung mẫu trả lời có thể chỉnh sửa.
- [ ] Tối ưu bố cục, bộ lọc và việc chuyển giữa các hồ sơ.
- [ ] Đánh giá nhu cầu đưa lọc/phân trang lên server khi hàng đợi lớn; hiện vẫn đọc từng trang rồi lọc trên client.

## 9. Ranh giới và tiêu chí nghiệm thu

- Không bổ sung chatbot AI, tự động bồi thường/hoàn tiền, hoặc nhiều tầng phê duyệt trong đợt đầu.
- Không mở rộng quyền CSKH để sửa đơn/giao dịch ngoài các lệnh nghiệp vụ đã được phép.
- Không xem các ý tưởng này là bản sao chính xác hệ thống nội bộ Grab/ShopeeFood.
- Thay đổi backend mới vẫn tuân thủ yêu cầu chấp thuận riêng trong `AGENTS.md`; việc đã duyệt migration trước không phải phê duyệt vô hạn.
- Chỉ báo hoàn tất một luồng khi UI, RPC, phân quyền, thông báo và tình huống thất bại tương ứng đều được kiểm tra; ghi rõ phần chưa kiểm thử.
- Chạy test/analyze tập trung, kiểm tra web rộng và viewport ngắn với chữ phóng to. Không tự chạy full suite/build phát hành sau mỗi chỉnh sửa nhỏ.

## 10. Điểm đọc code khi bắt đầu

- `apps/operations_web/lib/features/support/`: hàng đợi, hồ sơ, hội thoại và thông tin đơn.
- `apps/operations_web/lib/features/risk_reports/`: sự cố, can thiệp và quyền xử lý.
- `apps/operations_web/lib/features/returns/`: nghiệp vụ hoàn hàng hiện có.
- `apps/delivery_app/lib/features/order_help/`: tạo yêu cầu, hội thoại và tiến độ phía khách/tài xế.
- `apps/delivery_app/lib/features/notifications/`: mở hồ sơ từ thông báo.
- `packages/giaohang_domain/lib/src/support_ticket.dart`: model dùng chung.
- `supabase/tests/support_workflow_regression.sql`: kiểm thử SQL đã thực thi.

## 11. Nguồn tham khảo đã trao đổi

- [ShopeeFood — Trung tâm trợ giúp cho tài xế](https://driver.shopeefood.vn/tin-tuc/trung-tam-tro-giup-kenh-ho-tro-da-tinh-nang-nhanh-chong-thuan-tien-hieu-qua/): đường vào trợ giúp từ đơn hàng, hướng dẫn và báo cáo.
- [Grab — hướng dẫn liên hệ qua ứng dụng](https://www.grab.com/vn/en/blog/bi-thuat-dung-grab-bat-mi-tip-dung-grab-nhanh-de-xin/): gọi/trò chuyện qua Trung tâm trợ giúp.
- [Grab — hỗ trợ tài xế chờ đơn lâu](https://www.grab.com/vn/blog/driver/hotrochodonlau/): ví dụ tự động xử lý một tình huống có điều kiện rõ.

Các nguồn mô tả chức năng công khai ở thời điểm công bố, không xác nhận giao diện quản trị nội bộ hiện tại. Thiết kế trong tài liệu này là đề xuất riêng cho GiaoHang.

**Câu lệnh để bắt đầu buổi sau:** “Đọc docs/support_improvement_plan_2026_09_29.md, kiểm tra hiện trạng rồi thực hiện Bước 1. Ưu tiên sửa lỗi thực tế trước, sau đó làm tình huống không liên hệ được người nhận.”
