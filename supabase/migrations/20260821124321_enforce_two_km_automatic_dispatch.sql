-- Keep every automatic offer inside the default two-kilometer radius.
-- FreePick remains a separate, explicit driver action for orders outside it.
ALTER FUNCTION private.dispatch_next_order_offer(uuid, double precision)
  RENAME TO dispatch_next_order_offer_unbounded;

CREATE OR REPLACE FUNCTION private.dispatch_next_order_offer(
  p_order_id uuid,
  p_radius_meters double precision DEFAULT 2000
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN private.dispatch_next_order_offer_unbounded(
    p_order_id,
    LEAST(GREATEST(p_radius_meters, 1), 2000)
  );
END;
$$;

REVOKE ALL ON FUNCTION private.dispatch_next_order_offer(
  uuid,
  double precision
) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.dispatch_order_offer_after_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  PERFORM private.dispatch_next_order_offer(NEW.id, 2000);
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.dispatch_order_offer_after_insert()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS orders_dispatch_first_offer ON public.orders;
CREATE TRIGGER orders_dispatch_first_offer
AFTER INSERT ON public.orders
FOR EACH ROW
WHEN (
  NEW.driver_id IS NULL
  AND NEW.status IN (
    'pending'::public.order_status,
    'confirmed'::public.order_status
  )
)
EXECUTE FUNCTION private.dispatch_order_offer_after_insert();
