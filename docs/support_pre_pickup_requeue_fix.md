# Sửa luồng CSKH hủy tài xế trước nhận hàng và tự tìm tài xế mới

Ngày 2026-10-08. Trạng thái: **đã được duyệt riêng, áp dụng Supabase và khôi phục GH-10181**.

Migration: [support_pre_pickup_auto_requeue](../supabase/migrations/20261008141500_support_pre_pickup_auto_requeue.sql).

## Lỗi đã xác nhận

GH-10181 đang `risk_hold`, `driver_id=NULL`, chưa nhận hàng.
Can thiệp là `held_before_pickup`, đã ghi nhận giải phóng tài xế; hồ sơ đã
`resolved`. Hạn tìm tài xế vẫn là 11:05 ngày 08/10/2026 (giờ Việt Nam), trước
thời điểm CSKH hủy lúc 12:27. Đơn không có bút toán ví của tài xế.

Trước bản sửa, `hold_risk_order_before_pickup` dừng ở tạm giữ. `resume_risk_held_order`
chỉ đổi sang `confirmed`; không đặt lại hạn tìm, không loại tài xế cũ,
không gọi dispatcher. Nó cũng xóa participant tài xế cũ, có thể làm mất dữ
liệu Realtime phục vụ thông báo hủy.

Đã tái hiện bằng SQL fixture trong transaction rollback. Kiểm thử yêu cầu
đơn về tìm tài xế mới thất bại trên RPC hiện tại; không có dữ liệu kiểm thử
hoặc thay đổi RPC nào được lưu trong lần tái hiện đó.

## Bản sửa cụ thể

[SQL đã duyệt của hai RPC](sql/support_pre_pickup_requeue_draft.sql).

- Giữ chữ ký RPC và thao tác Flutter đang gọi; không thêm bảng/cột, RLS,
  trigger hoặc Edge Function.
- Chỉ gỡ trực tiếp khi `assigned` hoặc `picking_up` chưa có xác nhận lấy hàng.
  Đơn đã nhận hàng tiếp tục dùng quy trình hoàn/bàn giao.
- RPC hủy gỡ tài xế và mở lượt tìm trong cùng transaction. Trạng thái cuối là
  `pending` (Đang tìm tài xế), bỏ liên kết tạm giữ.
- Cấp lượt tìm mới 15 phút theo giờ server; xóa trạng thái quá hạn và lời mời
  cũ. Xóa mốc đến điểm lấy và ETA của tài xế cũ.
- Giữ danh sách tài xế đã từ chối và thêm tài xế vừa hủy để không mời lại người đó.
  Gọi dispatcher hiện có, giữ các điều kiện online/KYC/vị trí/ví/khóa nhận đơn.
- Không có tài xế phù hợp: đơn tiếp tục tìm trong lượt mới; không chuyển lại
  thành tạm giữ vì sự cố.
- Can thiệp chuyển `released` và giữ participant của tài xế trước nhận hàng
  để RLS/Realtime vẫn gửi được thông báo hủy. Luồng bàn giao hàng thực tế giữ
  cách xóa participant hiện có.
- Giữ kiểm tra Support/Admin, chủ hồ sơ, custody và khóa đơn. Bổ sung kiểm tra
  chủ hồ sơ vào RPC phân công lại.
- Ghi nhật ký, audit và thông báo khách đang tìm tài xế mới. Retry không mở lại
  lượt tìm, không tạo audit/notice trùng và không gỡ tài xế mới đã nhận.
- Không thay tổng tiền, phương thức thanh toán hoặc bút toán ví của đơn hủy
  trước nhận hàng.

## Khôi phục GH-10181 đã thực hiện

Đọc và khóa lại đơn cùng can thiệp trước khi xử lý. Chỉ khôi phục đúng đơn
GH-10181 nếu vẫn chưa nhận hàng, đang tạm giữ, không có tài xế, có xác nhận
CSKH đã giải phóng tài xế và không có quyết định custody khác đang chờ.

Dùng RPC phân công lại đã sửa trong ngữ cảnh nhân viên phụ trách hồ sơ, có audit;
giữ hồ sơ đã đóng, mã đơn, khách và các khoản tiền. Đơn chuyển về `pending`,
mở lượt tìm 15 phút và gửi lời mời mới nếu có tài xế phù hợp. Kiểm tra dữ liệu
sau thực thi; không sửa các đơn khác hoặc tạo đơn thay thế.

Đã khôi phục lúc 21:16:24 ngày 08/10/2026 (giờ Việt Nam). Kết quả đọc lại:
`pending`, không còn tài xế hoặc liên kết tạm giữ; can thiệp `released`,
hồ sơ vẫn `resolved`. Hạn tìm mới 21:31:24. Tổng tiền 138.000đ,
`payment_status=not_required`, chưa nhận hàng và không có bút toán ví.
Tài xế cũ có trong danh sách loại khỏi lời mời. Dispatcher chưa tìm được
tài xế phù hợp tại thời điểm khôi phục, nên đơn tiếp tục tìm.

Khôi phục chạy RPC trong ngữ cảnh chủ hồ sơ; audit riêng với `actor_id=NULL`,
`operation=approved_order_recovery`, `executed_via=administrative_maintenance`
ghi rõ thao tác bảo trì đã được duyệt. Transaction kiểm tra toàn bộ dữ liệu
đơn ngoài các trường điều phối được phép đổi và kiểm tra bút toán ví giữ nguyên
trước khi commit.

## Kiểm tra

[12 tình huống SQL](../supabase/tests/support_pre_pickup_requeue_regression.sql):
đã phân công, đang đến lấy, bàn giao cũ chưa nhận hàng, đã nhận hàng, đang giao,
quyết định hoàn, tài xế không khớp, custody khác đang chờ, pickup thắng trước,
đơn cũ đã đóng hồ sơ nhưng còn tạm giữ, không có tài xế phù hợp và đơn tiền cọc.

Kiểm tra quyền chủ hồ sơ, thời hạn mới, dispatcher chọn tài xế khác, ví và
thanh toán giữ nguyên, retry sau tài xế mới nhận, tài xế cũ đọc được thông báo
qua RLS, tiền cọc chỉ giữ khi tài xế mới xác nhận lấy hàng.

Kiểm thử 12 tình huống đã pass với DDL dự thảo trong transaction rollback,
sau đó pass lại trên backend đã áp dụng migration. Bộ kiểm thử cũ
[9 tình huống gỡ tài xế](../supabase/tests/support_pre_pickup_driver_release_regression.sql)
được cập nhật trạng thái cuối theo nghiệp vụ mới và cũng pass. Fixture,
thông báo và bút toán thử đều rollback.

Flutter: `support_risk_workspace_test.dart` và `risk_intervention_actions_test.dart`
pass toàn bộ 19 test, gồm viewport 375×568 với text scale 1.6 và web 1280×850.
`flutter analyze lib/features/risk_reports/constants/risk_report_strings.dart`
không có lỗi. Nội dung xác nhận CSKH đã nói rõ đơn tự tìm tài xế mới.

Hai RPC giữ `SECURITY DEFINER`, `search_path=''`, cấm `anon` và cho phép
`authenticated`; quyền Support/Admin và chủ hồ sơ được kiểm thử trong SQL.
Security advisors giữ nguyên 6 cảnh báo đã tồn tại trước bản sửa, không phát sinh
cảnh báo mới; các cảnh báo cũ nằm ngoài phạm vi thay đổi này.
Chưa kiểm tra hai request đồng thời từ kết nối độc lập, chưa kiểm tra thủ công
trên thiết bị thật; không chạy full suite hoặc build app.

Quy định: [AGENTS.md](../AGENTS.md), mục Supabase MCP —
“không thay đổi Supabase schema, RLS policies, migrations, Edge Functions, hoặc
database fields nếu chưa được hỏi và chấp thuận riêng.”
