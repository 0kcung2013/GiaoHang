# Luồng CSKH đơn giản hóa

## Hành vi

- Ba trạng thái hiển thị: **Mới → Đang xử lý → Kết thúc**. Các giá trị trạng thái cũ được ánh xạ để tiếp tục đọc dữ liệu hiện có.
- Nhận xử lý không được tính là đã phản hồi khách hàng. Ghi chú nội bộ cũng không được tính là phản hồi công khai.
- Kết thúc cần kết quả xử lý. Có thể mở lại cùng yêu cầu và giữ lịch sử; người yêu cầu phải nhập lý do khi mở lại.
- Chặn kết thúc yêu cầu khi sự cố liên quan chưa kết thúc hoặc đơn còn chờ hoàn/bàn giao hàng. Quyền xử lý sự cố nghiêm trọng và quyền người phụ trách vẫn được giữ.
- Hàng đợi có bộ lọc đang xử lý, của tôi, cần phản hồi, chưa phân công và kết thúc. Hồ sơ có URL riêng, hội thoại và ngữ cảnh đơn hàng, liên kết giữa yêu cầu hỗ trợ và sự cố.
- Tìm người dùng bằng tên/số điện thoại và đơn hàng bằng mã vận đơn thay cho nhập UUID.
- Hội thoại chỉ rõ người nhận; ghi chú nội bộ tách khỏi phản hồi công khai. Thông báo mới chứa liên kết đến đúng hồ sơ.

## Backend đã triển khai

Migration: `supabase/migrations/20260928124549_streamline_support_workflow.sql`.
Kịch bản kiểm thử rollback: `supabase/tests/support_workflow_regression.sql`.

Tái sử dụng bảng hiện có; bổ sung hai khóa liên kết hồ sơ vào `notifications`, điều chỉnh RPC/trigger, thêm RPC mở lại yêu cầu. Đã áp dụng lên Supabase DATN (`erlpzwfbpjogvaulcxni`) ngày 28/09/2026 sau khi người dùng chấp thuận. Phiên bản migration từ server: `20260928124549`.

Đã thực thi migration và fixture giả trong một transaction rollback trên Supabase trước khi triển khai; sau khi áp dụng chính thức đã chạy lại kịch bản rollback thành công. Không tạo nhánh trả phí và không cần Docker. Đã sửa lỗi cú pháp biểu thức CASE được phát hiện khi thực thi SQL.

Các tình huống SQL đã đạt: tiếp nhận không tính là phản hồi; ghi chú nội bộ không tính là phản hồi; phản hồi công khai cập nhật thời gian; yêu cầu kết quả khi kết thúc; mở lại đúng người yêu cầu (đã thử cả customer và driver); từ chối mở lại của người khác; người yêu cầu không đọc/ghi ghi chú nội bộ; thông báo gắn đúng hồ sơ; chặn kết thúc khi sự cố còn mở hoặc còn `return_required`/`handoff_required`; cho kết thúc sau khi custody hoàn tất. Xác minh không còn fixture người dùng, RLS vẫn bật và anon không có quyền gọi RPC mở lại.

Security advisor còn các cảnh báo tồn tại trước thay đổi, và cảnh báo chung cho RPC SECURITY DEFINER dành cho authenticated, bao gồm RPC mở lại mới. RPC này đã kiểm tra đăng nhập, role, quyền requester và khóa hồ sơ; không cấp cho anon. Chưa kiểm thử tải hoặc các thao tác đồng thời từ nhiều phiên.

## Kiểm tra và giới hạn

- Đã chạy test tập trung cho hàng đợi, hội thoại, nhận/kết thúc/mở lại, quyền người phụ trách, policy sự cố, điều hướng, thông báo và model hỗ trợ.
- Đã kiểm tra widget ở kích thước web và viewport ngắn 540×640 với text scale 1.6; sửa tràn nội dung bằng bố cục cuộn.
- Chưa kiểm tra giao diện trong trình duyệt với phiên đăng nhập thực tế; chưa chạy full suite hoặc build phát hành.
- Hàng đợi đọc từng trang theo khóa chính để không bỏ sót hồ sơ sau 200 bản ghi, rồi lọc trên client. Khi dữ liệu lớn cần chuyển bộ lọc/phân trang lên server.
- Thông báo cũ chưa có liên kết hồ sơ giữ cách mở cũ; không suy đoán hoặc backfill sai hồ sơ.
