# Cải thiện CSKH — cập nhật 30/09/2026

Thực hiện theo `support_improvement_plan_2026_09_29.md`, tiếp nối code CSKH có sẵn
trong working tree. Không tạo hoặc áp dụng migration, không sửa RPC/RLS, không
thay đổi cấu hình Supabase/R2.

## Đã triển khai

- Tài xế chọn vấn đề trước khi mở chat: không liên hệ được người nhận, giao chậm,
  hàng hóa, thanh toán hoặc trao đổi khác. Luồng báo cáo sự cố riêng vẫn được giữ.
- Mở lại hội thoại đang xử lý của đúng người gửi và cùng chủ đề; vấn đề khác không
  bị gộp. Phía CSKH cũng chỉ tự mở kênh liên hệ cùng chủ đề, không chọn tùy tiện
  một hồ sơ khác của cùng đơn. Khi tạo kênh mới, gợi ý chủ đề nhưng để nhân viên
  tự soạn nội dung; không sao chép chat hoặc ghi chú nội bộ.
- Chat mới có gợi ý thông tin cần cung cấp theo vấn đề, không bắt buộc ảnh.
- Hồ sơ CSKH có khối **Việc cần làm**: thông tin cần xác minh, trạng thái đơn đã
  đọc được, hướng phối hợp hai bên và điều kiện trước khi kết thúc.
- Kiểm tra trước khi kết thúc từ `orders`, `risk_reports` và
  `risk_report_interventions`: hiển thị lý do và liên kết xử lý khi sự cố chưa
  kết thúc hoặc hàng chờ hoàn/bàn giao. Lỗi tải dữ liệu cũng ngăn kết thúc cho đến
  khi kiểm tra lại được. Kiểm tra lại tại thao tác kết thúc; RPC hiện có vẫn là
  lớp quyết định cuối cùng nếu dữ liệu thay đổi đồng thời.
- Không bắt mọi yêu cầu phải đợi đơn giao xong. Hướng dẫn về kết quả giao/hoàn/
  bàn giao của tình huống không liên hệ người nhận là hướng dẫn nghiệp vụ, không
  suy đoán hoàn thành từ nội dung chat.
- Mẫu trả lời theo vấn đề và vai trò người nhận được đưa vào ô soạn để sửa, chỉ
  gửi khi nhân viên bấm gửi. Không ghi đè bản nháp, không chèn vào ghi chú nội bộ.
- Giữ bản nháp khi đổi bố cục rộng/hẹp hoặc chuyển tab thông tin; nút tải lại
  kết nối lại các stream và tải lại hội thoại/hồ sơ. Lỗi hội thoại độc lập với lỗi
  hồ sơ, không bị xóa bởi một lần tải hồ sơ thành công.
- Bỏ nhãn realtime luôn sáng ở CSKH; phía mobile hiển thị trạng thái đồng bộ dữ
  liệu, không coi một HTTP fetch thành công là xác nhận kết nối realtime.
- Gợi ý kết quả xử lý gồm việc đã làm, kết quả và bên đã được thông báo.

Cấu hình tình huống dùng chung nằm tại
`packages/giaohang_domain/lib/src/support_issue.dart`. Hướng dẫn dựa trên chủ đề
được chọn; không phân tích nội dung chat để tự kết luận lỗi, hoàn tiền hoặc đổi
trạng thái đơn. Các chủ đề cũ/tự nhập chưa khớp dùng hướng dẫn chung.

## Kiểm tra

Kết quả cuối: **25 test tập trung đạt** (12 Operations, 11 Delivery, 2 domain).
Analyze các phạm vi Flutter bên dưới không có vấn đề. `git diff --check` không
phát hiện lỗi khoảng trắng trong các file đã kiểm tra.

Các lệnh tập trung được sử dụng:

```text
# apps/operations_web
flutter test --no-pub test/support_guidance_test.dart test/support_workflow_test.dart test/support_case_conversation_test.dart
flutter analyze --no-pub lib/features/support test/support_guidance_test.dart test/support_case_conversation_test.dart

# apps/delivery_app
flutter test --no-pub test/driver_support_action_test.dart test/customer_order_help_flow_test.dart
flutter analyze --no-pub lib/features/order_help lib/features/driver/screens/navigation/widgets/driver_support_action.dart test/driver_support_action_test.dart

# packages/giaohang_domain
dart test test/support_issue_test.dart
```

Kiểm tra tập trung bao gồm điều kiện chặn và kiểm tra lại, lỗi tải dữ liệu, giữ
bản nháp, mẫu không tự gửi, đổi người phụ trách, nhận/kết thúc/mở lại, phân biệt
chủ đề, cập nhật hội thoại và đường vào báo cáo an toàn. Bố cục được kiểm tra
bằng widget test ở web rộng và viewport 540×640 với chữ 160%.

Đã đọc schema và policy trên Supabase để xác nhận các cột dùng cho truy vấn và
quyền đọc can thiệp của CSKH/Admin. Đây là kiểm tra chỉ đọc; không thay thế kiểm
thử RPC, notification và phân quyền bằng phiên người dùng thật.

## Chưa nghiệm thu

- Chưa có phiên/tài khoản kiểm thử được cung cấp; chưa chạy luồng Customer →
  CSKH → Driver xuyên suốt trên server, thông báo hoặc mất mạng thực tế.
- Không có browser kết nối trong phiên. Thử chụp render từ widget test bị lỗi
  tải font; chưa dùng ảnh này để kết luận chất lượng hình thức cuối cùng.
- Chưa kiểm thử nhiều phiên thao tác đồng thời hoặc tải lớn; không chạy full
  suite/build phát hành. Chưa chạy lại SQL regression có fixture trên server.
- Hàng đợi giữ cơ chế đọc từng trang rồi lọc client. Chưa có số liệu tải để đề
  xuất phân trang/lọc server. Bản nháp được giữ trong hồ sơ đang mở, chưa có kho
  lưu bản nháp qua đóng trang hoặc thay toàn bộ route.
- Không lưu checklist/lý do chờ xuống backend. Không thêm cơ chế liên kết hai
  ticket độc lập cùng sự cố ngoài quan hệ đơn/sự cố hiện có.

Bước tiếp theo là kiểm thử các tài khoản được phép theo Bước 1 của kế hoạch,
đặc biệt kết thúc/mở lại, quyền ghi chú nội bộ, thông báo và hoàn/bàn giao thực tế.
