# Trao đổi trực tiếp với CSKH — phần server cần duyệt

## Frontend đã sửa

- Hỗ trợ chuyến đi → Trao đổi với CSKH mở thẳng form chat; không chọn lý do.
- Tái sử dụng hội thoại mới cập nhật nhất còn hoạt động của đúng tài xế/đơn,
  kể cả hội thoại cũ mang tiêu đề lý do. Chỉ tạo yêu cầu khi gửi tin đầu tiên.
- Tài xế nhập được bất kỳ nội dung không rỗng, không còn tối thiểu 10 ký tự
  hoặc cắt text ở 4.000 ký tự. Nội dung rỗng/khoảng trắng không gửi.
- Tin đầu tiên lấy từ trigger server hiện có. Khi Realtime xác nhận trước
  phản hồi HTTP, bỏ bong bóng đang gửi. So sánh ID mới, người gửi và nội dung;
  hai lần gửi có chủ ý với cùng nội dung vẫn được giữ riêng. Khi HTTP báo lỗi
  sau xác nhận Realtime, không phục hồi bản nháp để tránh gửi lại tin đã lưu.

## Bằng chứng trên server ngày 2026-10-08

Hội thoại GH-10180 có duy nhất một tin tài xế “hàng cồng kềnh” và một phản hồi
CSKH “xin chào”. Không xóa tin.

Hiện server vẫn giới hạn 4.000 ký tự tại hai CHECK constraint và RPC gửi tin.
RPC mở lại yêu cầu giới hạn 3–3.900 ký tự. Vì vậy frontend đã cho nhập tin dài,
nhưng server chưa nhận tin dài quá giới hạn cũ cho tới khi phần dưới được duyệt.

## Thay đổi đề nghị duyệt riêng

Tái sử dụng bảng/RPC hiện có, không thêm bảng/cột/dịch vụ và không đổi RLS,
phân quyền, trạng thái xử lý, audit, GPS hay R2.

Hai constraint chỉ giữ điều kiện nội dung không rỗng:

```sql
ALTER TABLE public.support_tickets
  DROP CONSTRAINT support_tickets_message_check,
  ADD CONSTRAINT support_tickets_message_check
    CHECK (char_length(trim(message)) >= 1);

ALTER TABLE public.support_ticket_messages
  DROP CONSTRAINT support_ticket_messages_body_check,
  ADD CONSTRAINT support_ticket_messages_body_check
    CHECK (char_length(trim(body)) >= 1);
```

Trong `public.post_support_ticket_message(uuid,text,text)`, thay duy nhất:

```sql
-- Cũ
IF char_length(normalized_body) NOT BETWEEN 1 AND 4000 THEN
  RAISE EXCEPTION 'Message must contain between 1 and 4000 characters'
    USING ERRCODE = '22023';
END IF;

-- Mới
IF normalized_body = '' THEN
  RAISE EXCEPTION 'Message must not be empty' USING ERRCODE = '22023';
END IF;
```

Trong `public.reopen_support_ticket(uuid,text)`, thay duy nhất điều kiện
`char_length(normalized) NOT BETWEEN 3 AND 3900` bằng `normalized = ''`.
Giữ nguyên xác thực, khóa transaction, kiểm tra người gửi, phân công CSKH,
visibility, tạo tin và thông báo. Các luồng khác vẫn giữ validation UI hiện có.

Sau khi duyệt, tạo migration qua CLI, kiểm tra quyền trước/sau, gửi tin 1 ký tự,
5.000 ký tự, mở lại bằng tin 1 ký tự, từ chối khoảng trắng và người không có
quyền, đồng thời xác nhận tin đầu chỉ có một dòng. Các phép thử ghi dùng dữ
liệu test và transaction rollback, không dùng đơn GH-10180 làm fixture ghi.

`AGENTS.md`, mục Supabase MCP, yêu cầu chấp thuận riêng trước khi thay đổi
schema/RPC/migrations. Chưa tạo hay chạy migration cho đề xuất này.
