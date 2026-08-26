-- Automatic offers remain exclusive and time-boxed. Once an offer is no
-- longer live, FreePick is the manual recovery path: a driver may search for
-- and claim the order even when an earlier automatic offer expired or was
-- transferred. The 50 km guard, active-offer reservation and accept_order
-- wallet checks remain authoritative.

CREATE OR REPLACE FUNCTION public.get_free_pick_orders_in_view(
  p_south double precision,
  p_west double precision,
  p_north double precision,
  p_east double precision,
  p_limit integer DEFAULT 50
)
RETURNS SETOF public.orders
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  driver_user_id uuid := auth.uid();
  driver_profile public.drivers%ROWTYPE;
BEGIN
  IF driver_user_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF p_south < -90 OR p_north > 90
     OR p_west < -180 OR p_east > 180
     OR p_south >= p_north OR p_west >= p_east THEN
    RAISE EXCEPTION 'FREE_PICK_VIEWPORT_INVALID';
  END IF;
  IF p_north - p_south > 1 OR p_east - p_west > 1 THEN
    RAISE EXCEPTION 'FREE_PICK_VIEWPORT_TOO_LARGE';
  END IF;

  SELECT * INTO driver_profile
  FROM public.drivers
  WHERE user_id = driver_user_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'DRIVER_PROFILE_NOT_FOUND'; END IF;
  IF driver_profile.approval_status IS DISTINCT FROM
     'approved'::public.approval_status THEN
    RAISE EXCEPTION 'DRIVER_NOT_APPROVED';
  END IF;
  IF driver_profile.is_available IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'DRIVER_OFFLINE';
  END IF;
  IF driver_profile.current_lat IS NULL
     OR driver_profile.current_lng IS NULL
     OR driver_profile.location_updated_at < now() - interval '3 minutes' THEN
    RAISE EXCEPTION 'DRIVER_LOCATION_STALE';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.orders AS active_order
    WHERE active_order.driver_id = driver_user_id
      AND active_order.status IN (
        'assigned'::public.order_status,
        'picking_up'::public.order_status,
        'delivering'::public.order_status
      )
  ) THEN RAISE EXCEPTION 'DRIVER_HAS_ACTIVE_ORDER'; END IF;
  IF EXISTS (
    SELECT 1 FROM public.orders AS active_offer
    WHERE active_offer.offered_driver_id = driver_user_id
      AND active_offer.driver_id IS NULL
      AND active_offer.offer_expires_at > now()
      AND active_offer.assignment_timed_out_at IS NULL
      AND active_offer.status IN (
        'pending'::public.order_status,
        'confirmed'::public.order_status
      )
  ) THEN RAISE EXCEPTION 'DRIVER_HAS_ACTIVE_OFFER'; END IF;

  RETURN QUERY
  SELECT free_order.*
  FROM public.orders AS free_order
  WHERE free_order.driver_id IS NULL
    AND free_order.status IN (
      'pending'::public.order_status,
      'confirmed'::public.order_status
    )
    AND free_order.payment_status IN ('not_required', 'paid')
    AND free_order.assignment_timed_out_at IS NULL
    AND free_order.assignment_expires_at > now()
    AND (
      free_order.offered_driver_id IS NULL
      OR free_order.offer_expires_at IS NULL
      OR free_order.offer_expires_at <= now()
    )
    AND free_order.pickup_lat BETWEEN p_south AND p_north
    AND free_order.pickup_lng BETWEEN p_west AND p_east
    AND public.ST_DWithin(
      public.ST_SetSRID(
        public.ST_MakePoint(
          driver_profile.current_lng,
          driver_profile.current_lat
        ),
        4326
      )::public.geography,
      public.ST_SetSRID(
        public.ST_MakePoint(free_order.pickup_lng, free_order.pickup_lat),
        4326
      )::public.geography,
      50000
    )
  ORDER BY free_order.created_at ASC, free_order.id ASC
  LIMIT LEAST(GREATEST(p_limit, 1), 50);
END;
$$;

REVOKE ALL ON FUNCTION public.get_free_pick_orders_in_view(
  double precision,
  double precision,
  double precision,
  double precision,
  integer
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_free_pick_orders_in_view(
  double precision,
  double precision,
  double precision,
  double precision,
  integer
) TO authenticated;

CREATE OR REPLACE FUNCTION public.claim_free_pick_order(p_order_id uuid)
RETURNS TABLE(order_id uuid, customer_id uuid, tracking_code text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  driver_user_id uuid := auth.uid();
  driver_profile public.drivers%ROWTYPE;
  free_order public.orders%ROWTYPE;
BEGIN
  IF driver_user_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  SELECT * INTO driver_profile
  FROM public.drivers
  WHERE user_id = driver_user_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'DRIVER_PROFILE_NOT_FOUND'; END IF;
  IF driver_profile.current_lat IS NULL
     OR driver_profile.current_lng IS NULL
     OR driver_profile.location_updated_at <
        clock_timestamp() - interval '3 minutes' THEN
    RAISE EXCEPTION 'DRIVER_LOCATION_STALE';
  END IF;

  SELECT * INTO free_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF free_order.driver_id IS NOT NULL
     OR free_order.status NOT IN (
       'pending'::public.order_status,
       'confirmed'::public.order_status
     )
     OR free_order.assignment_timed_out_at IS NOT NULL
     OR free_order.assignment_expires_at <= clock_timestamp() THEN
    RAISE EXCEPTION 'ORDER_NOT_AVAILABLE';
  END IF;
  IF free_order.offered_driver_id IS NOT NULL
     AND free_order.offered_driver_id IS DISTINCT FROM driver_user_id
     AND free_order.offer_expires_at > clock_timestamp() THEN
    RAISE EXCEPTION 'FREE_PICK_ORDER_RESERVED';
  END IF;
  IF NOT public.ST_DWithin(
    public.ST_SetSRID(
      public.ST_MakePoint(
        driver_profile.current_lng,
        driver_profile.current_lat
      ),
      4326
    )::public.geography,
    public.ST_SetSRID(
      public.ST_MakePoint(free_order.pickup_lng, free_order.pickup_lat),
      4326
    )::public.geography,
    50000
  ) THEN RAISE EXCEPTION 'FREE_PICK_OUT_OF_RANGE'; END IF;
  IF EXISTS (
    SELECT 1 FROM public.orders AS active_offer
    WHERE active_offer.id <> p_order_id
      AND active_offer.offered_driver_id = driver_user_id
      AND active_offer.driver_id IS NULL
      AND active_offer.offer_expires_at > clock_timestamp()
      AND active_offer.assignment_timed_out_at IS NULL
      AND active_offer.status IN (
        'pending'::public.order_status,
        'confirmed'::public.order_status
      )
  ) THEN RAISE EXCEPTION 'DRIVER_HAS_ACTIVE_OFFER'; END IF;

  UPDATE public.orders
  SET offered_driver_id = driver_user_id,
      offer_expires_at = LEAST(
        clock_timestamp() + interval '45 seconds',
        free_order.assignment_expires_at
      ),
      status_note = 'Tài xế đang nhận đơn qua FreePick.'
  WHERE id = p_order_id;

  RETURN QUERY
  SELECT accepted.order_id, accepted.customer_id, accepted.tracking_code
  FROM public.accept_order(p_order_id) AS accepted;
END;
$$;

REVOKE ALL ON FUNCTION public.claim_free_pick_order(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_free_pick_order(uuid)
  TO authenticated;
