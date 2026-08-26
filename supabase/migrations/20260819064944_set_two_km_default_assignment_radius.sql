-- The 2 km circle is reserved for automatic assignment. FreePick starts
-- strictly outside that circle and remains capped at 50 km.

CREATE OR REPLACE FUNCTION public.find_nearest_drivers(
  pickup_lat double precision,
  pickup_lng double precision,
  radius_meters double precision DEFAULT 2000,
  max_results integer DEFAULT 10
)
RETURNS TABLE(
  id uuid,
  user_id uuid,
  full_name text,
  vehicle_type text,
  license_plate text,
  current_lat double precision,
  current_lng double precision,
  distance_meters double precision,
  rating double precision,
  location_updated_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  WITH candidate_distances AS (
    SELECT
      driver_profile.id,
      driver_profile.user_id,
      driver_user.full_name,
      driver_profile.vehicle_type,
      driver_profile.license_plate,
      driver_profile.current_lat,
      driver_profile.current_lng,
      public.ST_Distance(
        public.ST_SetSRID(
          public.ST_MakePoint(
            driver_profile.current_lng,
            driver_profile.current_lat
          ),
          4326
        )::public.geography,
        public.ST_SetSRID(
          public.ST_MakePoint(pickup_lng, pickup_lat),
          4326
        )::public.geography
      ) AS distance_meters,
      COALESCE(driver_profile.rating, 0)::double precision AS rating,
      driver_profile.location_updated_at
    FROM public.drivers AS driver_profile
    JOIN public.users AS driver_user
      ON driver_user.id = driver_profile.user_id
    WHERE auth.uid() IS NOT NULL
      AND pickup_lat BETWEEN -90 AND 90
      AND pickup_lng BETWEEN -180 AND 180
      AND radius_meters > 0
      AND driver_profile.is_available = true
      AND driver_profile.approval_status =
        'approved'::public.approval_status
      AND driver_profile.current_lat IS NOT NULL
      AND driver_profile.current_lng IS NOT NULL
      AND driver_profile.location_updated_at >= now() - interval '3 minutes'
      AND NOT EXISTS (
        SELECT 1
        FROM public.orders AS active_order
        WHERE active_order.driver_id = driver_profile.user_id
          AND active_order.status IN (
            'assigned'::public.order_status,
            'picking_up'::public.order_status,
            'delivering'::public.order_status
          )
      )
      AND public.ST_DWithin(
        public.ST_SetSRID(
          public.ST_MakePoint(
            driver_profile.current_lng,
            driver_profile.current_lat
          ),
          4326
        )::public.geography,
        public.ST_SetSRID(
          public.ST_MakePoint(pickup_lng, pickup_lat),
          4326
        )::public.geography,
        LEAST(GREATEST(radius_meters, 1), 2000)
      )
  )
  SELECT
    candidate.id,
    candidate.user_id,
    candidate.full_name,
    candidate.vehicle_type,
    candidate.license_plate,
    candidate.current_lat,
    candidate.current_lng,
    candidate.distance_meters,
    candidate.rating,
    candidate.location_updated_at
  FROM candidate_distances AS candidate
  ORDER BY candidate.distance_meters ASC, candidate.user_id ASC
  LIMIT LEAST(GREATEST(max_results, 1), 50);
$$;

REVOKE ALL ON FUNCTION public.find_nearest_drivers(
  double precision,
  double precision,
  double precision,
  integer
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.find_nearest_drivers(
  double precision,
  double precision,
  double precision,
  integer
) TO authenticated;

CREATE OR REPLACE FUNCTION public.assign_order_to_nearest_driver(
  p_order_id uuid,
  p_radius_meters double precision DEFAULT 2000
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  assignment_order public.orders%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  SELECT * INTO assignment_order FROM public.orders WHERE id = p_order_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF auth.uid() IS DISTINCT FROM assignment_order.customer_id THEN
    RAISE EXCEPTION 'ORDER_ASSIGNMENT_FORBIDDEN';
  END IF;
  IF assignment_order.driver_id IS NOT NULL THEN
    RETURN assignment_order.driver_id;
  END IF;
  RETURN private.dispatch_next_order_offer(
    p_order_id,
    LEAST(GREATEST(p_radius_meters, 1), 2000)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.assign_order_to_nearest_driver(
  uuid,
  double precision
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.assign_order_to_nearest_driver(
  uuid,
  double precision
) TO authenticated;

CREATE OR REPLACE FUNCTION public.retry_order_assignment(p_order_id uuid)
RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  retry_order public.orders%ROWTYPE;
  new_deadline timestamptz;
BEGIN
  SELECT * INTO retry_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;
  IF NOT FOUND OR auth.uid() IS DISTINCT FROM retry_order.customer_id THEN
    RAISE EXCEPTION 'ORDER_NOT_FOUND';
  END IF;
  IF retry_order.driver_id IS NOT NULL
     OR retry_order.status NOT IN (
       'pending'::public.order_status,
       'confirmed'::public.order_status
     ) THEN
    RAISE EXCEPTION 'ORDER_NOT_RETRYABLE';
  END IF;
  IF retry_order.assignment_timed_out_at IS NULL
     AND retry_order.assignment_expires_at > clock_timestamp() THEN
    RAISE EXCEPTION 'ASSIGNMENT_STILL_OPEN';
  END IF;
  new_deadline := clock_timestamp() + interval '15 minutes';
  UPDATE public.orders
  SET assignment_expires_at = new_deadline,
      assignment_timed_out_at = NULL,
      rejected_by = '[]'::jsonb,
      offered_driver_id = NULL,
      offer_expires_at = NULL,
      status_note = NULL
  WHERE id = p_order_id;
  INSERT INTO public.order_status_logs(
    order_id, status, title, description, logged_by
  ) VALUES (
    p_order_id,
    retry_order.status,
    'Đang tìm lại tài xế',
    'Hệ thống bắt đầu lượt tìm tài xế mới trong 15 phút.',
    auth.uid()
  );
  PERFORM private.dispatch_next_order_offer(p_order_id, 2000);
  RETURN new_deadline;
END;
$$;

REVOKE ALL ON FUNCTION public.retry_order_assignment(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.retry_order_assignment(uuid)
  TO authenticated;

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
    AND NOT (COALESCE(free_order.rejected_by, '[]'::jsonb)
      ? driver_user_id::text)
    AND free_order.pickup_lat BETWEEN p_south AND p_north
    AND free_order.pickup_lng BETWEEN p_west AND p_east
    AND NOT public.ST_DWithin(
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
      2000
    )
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
  IF COALESCE(free_order.rejected_by, '[]'::jsonb)
     ? driver_user_id::text THEN
    RAISE EXCEPTION 'ORDER_NOT_AVAILABLE';
  END IF;
  IF public.ST_DWithin(
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
    2000
  ) THEN RAISE EXCEPTION 'FREE_PICK_INSIDE_DEFAULT_RADIUS'; END IF;
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
