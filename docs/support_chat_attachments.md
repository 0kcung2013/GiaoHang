# Ảnh đính kèm trong chat CSKH

Customer/Driver chọn tối đa 3 ảnh cho mỗi tin, mỗi tệp không quá 5 MB. Ảnh
được xử lý ngoài UI isolate, thu nhỏ tối đa 1600 px và chuyển JPEG trước khi gửi.
Người gửi có thể xem trước, bỏ ảnh hoặc gửi ảnh không kèm chữ.

Tái sử dụng R2 Gateway hiện có với `purpose=order_cargo`, `contextId=order_id`
và `stage=support-chat`. Object nằm trong vùng riêng tư của người gửi:
`users/{user_id}/order-cargo/{order_id}/support-chat/{filename}.jpg`.
Worker hiện tại cho chủ sở hữu và Support/Admin đọc qua ticket có hạn. Không
đổi bucket, Worker, quyền database hoặc tạo bảng metadata.

URI ổn định được ghi cuối `support_ticket_messages.body` theo định dạng:

```text
Nội dung tin nhắn

[Ảnh đính kèm](r2://media/users/USER/order-cargo/ORDER/support-chat/image.jpg)
```

`CaseMessageContent` trong package domain dùng chung xử lý định dạng này. Tin
thuần văn bản giữ nguyên. Chỉ các tham chiếu R2 thuộc vùng ảnh chat được nhận
diện; URL HTTP, KYC và URL có query token không được diễn giải thành ảnh.
Hai app dùng `ChatMessageBody` để hiển thị ảnh và mở trình xem có phóng to.
Ảnh được tải bằng quyền hiện có của phiên đăng nhập, không lưu download URL
có hạn vào database.

Giữ URI của ảnh đã upload trong bản nháp khi gửi thất bại để thử lại không
upload trùng. Nếu Realtime xác nhận trước khi HTTP lỗi, không khôi phục bản
nháp để gửi lần nữa. Khi mở yêu cầu mới, body chứa ảnh được dùng cho tin đầu
do trigger hiện có tạo; không gọi thêm post-message cho cùng nội dung.

Operations Web cần được cập nhật cùng Delivery App để nhận diện ảnh trong
body. Không áp dụng thời hạn GPS 14 ngày cho ảnh này; retention media vẫn theo
chính sách ảnh hiện có.
