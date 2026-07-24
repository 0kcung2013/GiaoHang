-- Đồng bộ total_deliveries khi đơn chuyển sang delivered + backfill dữ liệu cũ

-- Backfill từ orders đã delivered (orders.driver_id = users.id = drivers.user_id)
UPDATE public.drivers d
SET
  total_deliveries = COALESCE(sub.cnt, 0),
  updated_at = now()
FROM (
  SELECT o.driver_id AS user_id, COUNT(*)::integer AS cnt
  FROM public.orders o
  WHERE o.status = 'delivered'::public.order_status
    AND o.driver_id IS NOT NULL
  GROUP BY o.driver_id
) sub
WHERE d.user_id = sub.user_id;

-- Tài xế chưa có đơn delivered → 0
UPDATE public.drivers d
SET total_deliveries = 0
WHERE NOT EXISTS (
  SELECT 1
  FROM public.orders o
  WHERE o.driver_id = d.user_id
    AND o.status = 'delivered'::public.order_status
)
AND d.total_deliveries <> 0;

CREATE OR REPLACE FUNCTION public.tg_orders_increment_driver_deliveries()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  -- Chỉ khi chuyển sang delivered lần đầu (tránh +1 khi update lặp)
  IF NEW.status = 'delivered'::public.order_status
     AND (OLD.status IS DISTINCT FROM 'delivered'::public.order_status)
     AND NEW.driver_id IS NOT NULL
  THEN
    UPDATE public.drivers
    SET
      total_deliveries = COALESCE(total_deliveries, 0) + 1,
      updated_at = now()
    WHERE user_id = NEW.driver_id;
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_orders_increment_driver_deliveries ON public.orders;
CREATE TRIGGER trg_orders_increment_driver_deliveries
  AFTER UPDATE OF status ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_orders_increment_driver_deliveries();

-- Gắn actual_delivered_at nếu app chưa set
CREATE OR REPLACE FUNCTION public.tg_orders_set_delivered_at()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF NEW.status = 'delivered'::public.order_status
     AND (OLD.status IS DISTINCT FROM 'delivered'::public.order_status)
     AND NEW.actual_delivered_at IS NULL
  THEN
    NEW.actual_delivered_at := now();
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_orders_set_delivered_at ON public.orders;
CREATE TRIGGER trg_orders_set_delivered_at
  BEFORE UPDATE OF status ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_orders_set_delivered_at();

-- RPC tiện ích (admin/script): đồng bộ lại total_deliveries từ orders
CREATE OR REPLACE FUNCTION public.sync_driver_total_deliveries()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  UPDATE public.drivers d
  SET
    total_deliveries = COALESCE(sub.cnt, 0),
    updated_at = now()
  FROM (
    SELECT o.driver_id AS user_id, COUNT(*)::integer AS cnt
    FROM public.orders o
    WHERE o.status = 'delivered'::public.order_status
      AND o.driver_id IS NOT NULL
    GROUP BY o.driver_id
  ) sub
  WHERE d.user_id = sub.user_id;

  UPDATE public.drivers d
  SET total_deliveries = 0, updated_at = now()
  WHERE NOT EXISTS (
    SELECT 1 FROM public.orders o
    WHERE o.driver_id = d.user_id
      AND o.status = 'delivered'::public.order_status
  )
  AND COALESCE(d.total_deliveries, 0) <> 0;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.sync_driver_total_deliveries() TO authenticated;
