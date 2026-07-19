-- Backup: tự tạo notification cho khách khi đơn chuyển sang assigned
-- (phòng client fail / quên gọi RPC). Idempotent theo title+order gần nhất không bắt buộc.

CREATE OR REPLACE FUNCTION public.notify_customer_on_order_assigned()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_code text;
BEGIN
  IF TG_OP = 'UPDATE'
     AND NEW.status = 'assigned'
     AND (OLD.status IS DISTINCT FROM 'assigned' OR OLD.driver_id IS DISTINCT FROM NEW.driver_id)
     AND NEW.customer_id IS NOT NULL
  THEN
    v_code := COALESCE(NULLIF(btrim(NEW.tracking_code), ''), left(NEW.id::text, 8));
    IF v_code NOT LIKE 'GH-%' AND length(v_code) <= 12 THEN
      v_code := 'GH-' || v_code;
    END IF;

    -- Tránh trùng nếu app đã insert qua RPC vài giây trước.
    IF NOT EXISTS (
      SELECT 1
      FROM public.notifications n
      WHERE n.user_id = NEW.customer_id
        AND n.order_id = NEW.id
        AND n.type = 'order_update'
        AND n.title = 'Tài xế đã nhận đơn'
        AND n.created_at > now() - interval '2 minutes'
    ) THEN
      INSERT INTO public.notifications (user_id, title, body, type, is_read, order_id, created_at)
      VALUES (
        NEW.customer_id,
        'Tài xế đã nhận đơn',
        format('Đơn %s đã có tài xế nhận. Theo dõi tiến trình trên app.', v_code),
        'order_update',
        false,
        NEW.id,
        now()
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_notify_customer_on_order_assigned ON public.orders;
CREATE TRIGGER trg_notify_customer_on_order_assigned
  AFTER UPDATE OF status, driver_id ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_customer_on_order_assigned();
