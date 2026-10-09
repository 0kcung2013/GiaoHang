# Công tắc nhận đơn mới khi đang giao hàng

## Hành vi

- Menu hiển thị **Trạng thái hoạt động** và công tắc nhận đơn mới.
- Công tắc phản ánh `drivers.is_available`, không bị ép bật/khóa bởi đơn hiện tại.
- Tắt phải xác nhận. Sau khi tắt, đơn hiện tại và tracking tiếp tục hoạt động.
- Bật lại vẫn đi qua PIN, GPS và kiểm tra khóa nhận đơn hiện có.
- Khóa nhận đơn 30 phút ngăn bật nhận đơn, nhưng vẫn cho phép tắt.

## Thay đổi server đã được chấp thuận và áp dụng

Đã kiểm tra RPC trên Supabase: `public.set_driver_availability(boolean)` đang
trả lỗi `DRIVER_HAS_ACTIVE_ORDER` khi tài xế có đơn hoạt động.
Chỉ bỏ điều kiện này trong RPC tắt nhận đơn. Tái sử dụng `drivers.is_available`
và RPC hiện có; không thêm bảng/cột, không đổi RLS hay luồng PIN bật nhận đơn.
Không thay đổi dữ liệu hoặc trạng thái đơn đang giao.

Người dùng đã chấp thuận cập nhật RPC. Migration
`20260927151222_allow_driver_off_during_active_delivery.sql` đã áp dụng lên Supabase.
SQL bên dưới là bản sửa đã duyệt và áp dụng:

```sql
CREATE OR REPLACE FUNCTION public.set_driver_availability(
  p_is_available boolean
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_driver_user_id uuid := (SELECT auth.uid());
  v_updated boolean;
BEGIN
  IF v_driver_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;
  IF p_is_available IS NULL THEN
    RAISE EXCEPTION 'DRIVER_AVAILABILITY_REQUIRED';
  END IF;
  IF p_is_available THEN
    RAISE EXCEPTION 'DRIVER_ONLINE_REQUIRES_PIN_AND_LOCATION';
  END IF;

  UPDATE public.drivers AS driver
  SET
    is_available = false,
    updated_at = clock_timestamp()
  WHERE driver.user_id = v_driver_user_id
  RETURNING driver.is_available INTO v_updated;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'APPROVED_DRIVER_REQUIRED';
  END IF;
  RETURN v_updated;
END;
$$;

REVOKE ALL ON FUNCTION public.set_driver_availability(boolean)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_driver_availability(boolean)
  TO authenticated;

COMMENT ON FUNCTION public.set_driver_availability(boolean) IS
  'Stops new order intake for the signed-in driver, including during an active delivery. Going Online requires the PIN-protected location command.';
```

## Kết quả kiểm tra

- Kiểm thử `supabase/tests/driver_availability_regression.sql` đã đạt trên Supabase,
  dùng transaction và rollback để xác nhận RPC cho phép tắt khi có đơn
  `assigned`, `picking_up`, `delivering`, `return_approved`, `returning`.
- Xác nhận đơn vẫn giữ nguyên tài xế và trạng thái, dữ liệu kiểm thử được rollback.
- Xác nhận RPC vẫn chặn bật trực tiếp, tham số null, người chưa đăng nhập và
  tài khoản không có hồ sơ tài xế; gọi tắt lặp lại vẫn an toàn.
- Tài xế bị khóa nhận đơn vẫn tắt được, hạn khóa không thay đổi.
- Kiểm tra quyền thực thi RPC chỉ dành cho `authenticated`.
- 13 kiểm thử Flutter trong `driver_drawer_availability_test.dart` và
  `driver_home_compact_ui_test.dart` đạt; analyze sáu file liên quan không có lỗi.

Nguồn: [Supabase Database Functions](https://supabase.com/docs/guides/database/functions).
