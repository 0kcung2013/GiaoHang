-- FIX: trigger đang insert type='order_accepted' → vi phạm notifications_type_check
-- và LÀM FAIL cả lệnh UPDATE nhận đơn (transaction rollback).
-- Chạy file này trong Supabase SQL Editor (bắt buộc).

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
