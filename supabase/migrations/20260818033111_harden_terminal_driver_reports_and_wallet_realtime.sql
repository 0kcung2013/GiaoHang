-- Một đơn đã được Driver xác nhận giao thành công là trạng thái cuối đối với
-- Driver. Customer vẫn có quyền tạo khiếu nại nếu thực tế chưa nhận hàng.
CREATE OR REPLACE FUNCTION private.reject_driver_report_after_delivery()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  order_status public.order_status;
BEGIN
  IF NEW.reporter_role_snapshot = 'driver' THEN
    SELECT delivery.status
    INTO order_status
    FROM public.orders AS delivery
    WHERE delivery.id = NEW.order_id;

    IF order_status = 'delivered'::public.order_status THEN
      RAISE EXCEPTION 'DRIVER_REPORT_AFTER_DELIVERY'
        USING ERRCODE = '23514';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.reject_driver_report_after_delivery()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS reject_driver_report_after_delivery
  ON public.risk_reports;
CREATE TRIGGER reject_driver_report_after_delivery
BEFORE INSERT ON public.risk_reports
FOR EACH ROW
EXECUTE FUNCTION private.reject_driver_report_after_delivery();

COMMENT ON FUNCTION private.reject_driver_report_after_delivery() IS
  'Rejects new Driver reports after delivered while preserving Customer complaints.';

-- Thu nhập hôm nay lấy từ ledger để bao gồm cả thu nhập chặng hoàn và dùng
-- đúng ngày nghiệp vụ Việt Nam.
CREATE OR REPLACE FUNCTION public.get_driver_wallet_summary()
RETURNS TABLE(
  available_balance bigint,
  held_balance bigint,
  today_income bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_driver_user_id uuid := (SELECT auth.uid());
BEGIN
  IF v_driver_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM public.drivers AS driver
    WHERE driver.user_id = v_driver_user_id
  ) THEN
    RAISE EXCEPTION 'DRIVER_PROFILE_NOT_FOUND';
  END IF;

  RETURN QUERY
  SELECT
    COALESCE(sum(tx.available_delta) FILTER (
      WHERE tx.status = 'completed'
    ), 0)::bigint,
    COALESCE(sum(tx.held_delta) FILTER (
      WHERE tx.status = 'completed'
    ), 0)::bigint,
    COALESCE(sum(tx.amount) FILTER (
      WHERE tx.status = 'completed'
        AND tx.transaction_type IN (
          'prepaid_earning',
          'cod_settlement',
          'return_earning'
        )
        AND (
          COALESCE(tx.completed_at, tx.created_at)
            AT TIME ZONE 'Asia/Ho_Chi_Minh'
        )::date = (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
    ), 0)::bigint
  FROM public.driver_wallet_transactions AS tx
  WHERE tx.driver_id = v_driver_user_id;
END;
$$;

-- Bật Postgres Changes cho ledger để màn ví tự refetch khi RPC giao/hoàn đơn
-- ghi thêm bút toán. Khối điều kiện giữ migration chạy lại an toàn.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'driver_wallet_transactions'
  ) THEN
    ALTER PUBLICATION supabase_realtime
      ADD TABLE public.driver_wallet_transactions;
  END IF;
END;
$$;
