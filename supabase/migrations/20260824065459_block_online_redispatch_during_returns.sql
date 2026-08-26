-- Return missions are active work. Enforce the invariant at the offer write
-- boundary so both order-insert dispatch and Online redispatch skip drivers
-- who are returning an order.

CREATE OR REPLACE FUNCTION private.guard_offer_driver_active_return()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.offered_driver_id IS NULL
     OR NEW.offered_driver_id IS NOT DISTINCT FROM OLD.offered_driver_id THEN
    RETURN NEW;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.orders AS active_return
    WHERE active_return.id <> NEW.id
      AND active_return.driver_id = NEW.offered_driver_id
      AND active_return.status IN (
        'return_approved'::public.order_status,
        'returning'::public.order_status
      )
  ) THEN
    RAISE unique_violation USING MESSAGE = 'DRIVER_HAS_ACTIVE_RETURN';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS orders_10_guard_offer_driver_active_return
  ON public.orders;

CREATE TRIGGER orders_10_guard_offer_driver_active_return
BEFORE UPDATE OF offered_driver_id ON public.orders
FOR EACH ROW
EXECUTE FUNCTION private.guard_offer_driver_active_return();

REVOKE ALL ON FUNCTION private.guard_offer_driver_active_return()
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.set_driver_online_with_location(
  p_lat double precision,
  p_lng double precision
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_driver_user_id uuid := (SELECT auth.uid());
  v_now timestamptz := clock_timestamp();
BEGIN
  IF v_driver_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;
  IF p_lat IS NULL OR p_lat < -90 OR p_lat > 90 THEN
    RAISE EXCEPTION 'INVALID_DRIVER_LATITUDE';
  END IF;
  IF p_lng IS NULL OR p_lng < -180 OR p_lng > 180 THEN
    RAISE EXCEPTION 'INVALID_DRIVER_LONGITUDE';
  END IF;

  UPDATE public.drivers AS driver_profile
  SET
    current_lat = p_lat,
    current_lng = p_lng,
    location_updated_at = v_now,
    is_available = true,
    updated_at = v_now
  WHERE driver_profile.user_id = v_driver_user_id
    AND driver_profile.approval_status =
      'approved'::public.approval_status;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'APPROVED_DRIVER_REQUIRED';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.orders AS active_return
    WHERE active_return.driver_id = v_driver_user_id
      AND active_return.status IN (
        'return_approved'::public.order_status,
        'returning'::public.order_status
      )
  ) THEN
    RETURN NULL;
  END IF;

  RETURN private.dispatch_waiting_orders_for_driver(v_driver_user_id);
END;
$$;

REVOKE ALL ON FUNCTION public.set_driver_online_with_location(
  double precision,
  double precision
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.set_driver_online_with_location(
  double precision,
  double precision
) TO authenticated;
