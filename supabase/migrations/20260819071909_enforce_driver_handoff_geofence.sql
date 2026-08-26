-- A handoff transition is valid only when its proof was captured within
-- 100 meters of the corresponding pickup or delivery point. Keeping this
-- check in a trigger makes it authoritative for the RPC and any direct
-- order status update performed by the assigned driver.

CREATE OR REPLACE FUNCTION private.enforce_driver_handoff_geofence()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  proof public.order_delivery_proofs%ROWTYPE;
  handoff_stage text;
  target_lat double precision;
  target_lng double precision;
BEGIN
  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;

  -- Staff/system recovery workflows are handled by their own authorization
  -- rules. This guard targets status changes initiated by the assigned driver.
  IF OLD.driver_id IS NULL OR auth.uid() IS DISTINCT FROM OLD.driver_id THEN
    RETURN NEW;
  END IF;

  IF OLD.status = 'picking_up'::public.order_status
     AND NEW.status = 'delivering'::public.order_status THEN
    handoff_stage := 'pickup';
    target_lat := OLD.pickup_lat;
    target_lng := OLD.pickup_lng;
  ELSIF OLD.status = 'delivering'::public.order_status
        AND NEW.status = 'delivered'::public.order_status THEN
    handoff_stage := 'delivery';
    target_lat := OLD.delivery_lat;
    target_lng := OLD.delivery_lng;
  ELSE
    RETURN NEW;
  END IF;

  SELECT handoff_proof.*
  INTO proof
  FROM public.order_delivery_proofs AS handoff_proof
  WHERE handoff_proof.order_id = OLD.id
    AND handoff_proof.driver_id = OLD.driver_id
    AND handoff_proof.stage = handoff_stage
  FOR UPDATE;

  IF NOT FOUND OR proof.captured_lat IS NULL
     OR proof.captured_lng IS NULL THEN
    IF handoff_stage = 'pickup' THEN
      RAISE EXCEPTION 'PICKUP_PROOF_LOCATION_REQUIRED'
        USING ERRCODE = '23514';
    END IF;
    RAISE EXCEPTION 'DELIVERY_PROOF_LOCATION_REQUIRED'
      USING ERRCODE = '23514';
  END IF;

  IF NOT public.ST_DWithin(
    public.ST_SetSRID(
      public.ST_MakePoint(proof.captured_lng, proof.captured_lat),
      4326
    )::public.geography,
    public.ST_SetSRID(
      public.ST_MakePoint(target_lng, target_lat),
      4326
    )::public.geography,
    100
  ) THEN
    IF handoff_stage = 'pickup' THEN
      RAISE EXCEPTION 'PICKUP_OUTSIDE_GEOFENCE'
        USING ERRCODE = '23514';
    END IF;
    RAISE EXCEPTION 'DELIVERY_OUTSIDE_GEOFENCE'
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.enforce_driver_handoff_geofence()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS enforce_driver_handoff_geofence_before_status_update
  ON public.orders;
CREATE TRIGGER enforce_driver_handoff_geofence_before_status_update
BEFORE UPDATE OF status ON public.orders
FOR EACH ROW
EXECUTE FUNCTION private.enforce_driver_handoff_geofence();
-- A handoff transition is valid only when its proof was captured within
-- 100 meters of the corresponding pickup or delivery point. Keeping this
-- check in a trigger makes it authoritative for the RPC and any direct
-- order status update performed by the assigned driver.

CREATE OR REPLACE FUNCTION private.enforce_driver_handoff_geofence()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  proof public.order_delivery_proofs%ROWTYPE;
  handoff_stage text;
  target_lat double precision;
  target_lng double precision;
BEGIN
  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;

  -- Staff/system recovery workflows are handled by their own authorization
  -- rules. This guard targets status changes initiated by the assigned driver.
  IF OLD.driver_id IS NULL OR auth.uid() IS DISTINCT FROM OLD.driver_id THEN
    RETURN NEW;
  END IF;

  IF OLD.status = 'picking_up'::public.order_status
     AND NEW.status = 'delivering'::public.order_status THEN
    handoff_stage := 'pickup';
    target_lat := OLD.pickup_lat;
    target_lng := OLD.pickup_lng;
  ELSIF OLD.status = 'delivering'::public.order_status
        AND NEW.status = 'delivered'::public.order_status THEN
    handoff_stage := 'delivery';
    target_lat := OLD.delivery_lat;
    target_lng := OLD.delivery_lng;
  ELSE
    RETURN NEW;
  END IF;

  SELECT handoff_proof.*
  INTO proof
  FROM public.order_delivery_proofs AS handoff_proof
  WHERE handoff_proof.order_id = OLD.id
    AND handoff_proof.driver_id = OLD.driver_id
    AND handoff_proof.stage = handoff_stage
  FOR UPDATE;

  IF NOT FOUND OR proof.captured_lat IS NULL
     OR proof.captured_lng IS NULL THEN
    IF handoff_stage = 'pickup' THEN
      RAISE EXCEPTION 'PICKUP_PROOF_LOCATION_REQUIRED'
        USING ERRCODE = '23514';
    END IF;
    RAISE EXCEPTION 'DELIVERY_PROOF_LOCATION_REQUIRED'
      USING ERRCODE = '23514';
  END IF;

  IF NOT public.ST_DWithin(
    public.ST_SetSRID(
      public.ST_MakePoint(proof.captured_lng, proof.captured_lat),
      4326
    )::public.geography,
    public.ST_SetSRID(
      public.ST_MakePoint(target_lng, target_lat),
      4326
    )::public.geography,
    100
  ) THEN
    IF handoff_stage = 'pickup' THEN
      RAISE EXCEPTION 'PICKUP_OUTSIDE_GEOFENCE'
        USING ERRCODE = '23514';
    END IF;
    RAISE EXCEPTION 'DELIVERY_OUTSIDE_GEOFENCE'
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.enforce_driver_handoff_geofence()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS enforce_driver_handoff_geofence_before_status_update
  ON public.orders;
CREATE TRIGGER enforce_driver_handoff_geofence_before_status_update
BEFORE UPDATE OF status ON public.orders
FOR EACH ROW
EXECUTE FUNCTION private.enforce_driver_handoff_geofence();
