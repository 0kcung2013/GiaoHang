-- Chặn client giả mạo trạng thái đã thanh toán để tạo đơn người gửi trả phí.
-- RPC SECURITY DEFINER chạy dưới owner của function; REST trực tiếp chạy dưới
-- role authenticated và không được phép quản lý các trường kích hoạt payment.
CREATE OR REPLACE FUNCTION private.enforce_order_payment_activation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.delivery_fee_payer = 'sender' THEN
      IF current_user NOT IN ('postgres', 'service_role', 'supabase_admin') THEN
        RAISE EXCEPTION 'ORDER_PAYMENT_ACTIVATION_FORBIDDEN';
      END IF;
      IF NEW.payment_status <> 'paid' OR NEW.paid_at IS NULL THEN
        RAISE EXCEPTION 'ORDER_PAYMENT_REQUIRED';
      END IF;
    ELSIF NEW.payment_status <> 'not_required' OR NEW.paid_at IS NOT NULL THEN
      RAISE EXCEPTION 'ORDER_PAYMENT_NOT_REQUIRED';
    END IF;
  ELSIF (
    NEW.delivery_fee_payer IS DISTINCT FROM OLD.delivery_fee_payer
    OR NEW.payment_status IS DISTINCT FROM OLD.payment_status
    OR NEW.paid_at IS DISTINCT FROM OLD.paid_at
  ) AND current_user NOT IN ('postgres', 'service_role', 'supabase_admin') THEN
    RAISE EXCEPTION 'ORDER_PAYMENT_FIELDS_SERVER_MANAGED';
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.enforce_order_payment_activation()
  FROM PUBLIC, anon, authenticated;

CREATE TRIGGER orders_enforce_payment_activation
BEFORE INSERT OR UPDATE OF delivery_fee_payer, payment_status, paid_at
ON public.orders
FOR EACH ROW
EXECUTE FUNCTION private.enforce_order_payment_activation();
