# CSKH xem ảnh lấy / giao / hoàn hàng

Trạng thái: người dùng đã duyệt và đã áp dụng database ngày 2026-10-19.
Migration: `20261019101210_support_order_proof_read_access.sql`.

## Nguyên nhân trước khi sửa

Tab Tra cứu đơn chưa đọc `order_delivery_proofs`. SELECT policy của bảng chỉ
cho khách tạo đơn và tài xế hiện tại; CSKH/Admin không nhận được dòng ảnh.
Bucket legacy `delivery-proofs` cũng chưa có SELECT policy cho nhân viên.
R2 Gateway đã kiểm tra JWT và cho vai trò support/admin đọc ảnh private qua
download ticket, nên không cần sửa Worker hoặc pipeline lưu ảnh.

## Giao diện

Chi tiết đơn có ảnh lấy hàng, giao hàng và hoàn hàng (khi có), thời gian chụp,
xem ảnh lớn với zoom, tải lại danh sách và thử lại khi tải ảnh lỗi. URL private
được ký trong 5 phút, lấy mới khi mở trình xem hoặc thử lại. Đọc đồng thời ảnh
R2 và ảnh cũ Supabase Storage; không lưu URL có hạn vào database.

## Phạm vi đã được duyệt

Hai policy chỉ SELECT, dùng vai trò trong `public.users`. Không cấp quyền ghi,
không thay đổi schema, RPC, nghiệp vụ giao hàng hoặc dịch vụ lưu trữ.
Policy Storage chỉ cho đọc object đã đăng ký trong `order_delivery_proofs`.

Hai policy trong migration:

```sql
CREATE POLICY order_delivery_proofs_select_staff
ON public.order_delivery_proofs FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users actor
    WHERE actor.id = (SELECT auth.uid())
      AND actor.role IN ('support', 'admin')
  )
  AND EXISTS (
    SELECT 1 FROM public.orders proof_order
    WHERE proof_order.id = order_delivery_proofs.order_id
  )
);

CREATE POLICY delivery_proofs_select_registered_staff
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'delivery-proofs'
  AND EXISTS (
    SELECT 1 FROM public.users actor
    WHERE actor.id = (SELECT auth.uid())
      AND actor.role IN ('support', 'admin')
  )
  AND EXISTS (
    SELECT 1 FROM public.order_delivery_proofs proof
    WHERE proof.storage_path = storage.objects.name
  )
);
```

Regression `supabase/tests/support_order_proof_read_access.sql` đã chạy trên
database sau khi áp dụng: cả support/admin đọc được metadata và object ảnh cũ
đã đăng ký; khách/tài xế chỉ đọc được ảnh của đơn liên quan; anon không có quyền
đọc bảng ảnh. Kiểm tra dùng transaction chỉ đọc và rollback, không tạo dữ liệu.

## Xác minh giao diện

- 18 test tập trung: repository ảnh, danh sách/trình xem ảnh, Tra cứu đơn và
  tải liên hệ đơn đều đạt; analyze feature và các test đã sửa không có lỗi.
- Render đã kiểm tra ở 1366×768 và 375×568 với chữ 160%; ảnh dùng PNG fixture,
  không phải ảnh nghiệp vụ. Trình xem có thể phóng to và đóng ở cả hai viewport.
- Chưa kiểm tra end-to-end bằng phiên đăng nhập CSKH thật trên trình duyệt.
