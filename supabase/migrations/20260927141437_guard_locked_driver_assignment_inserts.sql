-- Protect assignment inserts as well as reassignment updates.
CREATE OR REPLACE FUNCTION private.guard_order_driver_cancellation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_locked_until timestamptz;
BEGIN
  IF current_user IN ('anon', 'authenticated') THEN
    IF TG_OP = 'INSERT' AND NEW.driver_id IS NOT NULL THEN
      RAISE EXCEPTION 'ORDER_OFFER_SERVER_OWNED';
    END IF;
    IF (TG_OP = 'INSERT' AND NEW.pickup_arrived_at IS NOT NULL)
      OR (TG_OP = 'UPDATE' AND NEW.pickup_arrived_at IS DISTINCT FROM OLD.pickup_arrived_at) THEN
      RAISE EXCEPTION 'PICKUP_ARRIVAL_SERVER_OWNED';
    END IF;
    IF TG_OP = 'UPDATE' AND OLD.driver_id = auth.uid()
      AND NEW.status = 'cancelled' AND NEW.status IS DISTINCT FROM OLD.status THEN
      RAISE EXCEPTION 'DRIVER_CANCELLATION_COMMAND_REQUIRED';
    END IF;
  END IF;
  IF NEW.driver_id IS NOT NULL
    AND (TG_OP = 'INSERT' OR NEW.driver_id IS DISTINCT FROM OLD.driver_id) THEN
    SELECT acceptance_locked_until INTO v_locked_until
    FROM public.drivers WHERE user_id = NEW.driver_id FOR UPDATE;
    IF v_locked_until > clock_timestamp() THEN
      RAISE EXCEPTION 'DRIVER_ACCEPTANCE_LOCKED';
    END IF;
  END IF;
  IF TG_OP = 'UPDATE' AND NEW.driver_id IS DISTINCT FROM OLD.driver_id THEN
    NEW.pickup_arrived_at := NULL;
  END IF;
  RETURN NEW;
END;
$$;
