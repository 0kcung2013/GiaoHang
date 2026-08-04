-- Keep one active order per driver and offer the nearest remaining driver.
-- Previous rejections are excluded before distance ordering so a farther
-- driver can receive the same order after the nearest driver transfers it.

CREATE UNIQUE INDEX IF NOT EXISTS orders_one_active_per_driver_idx
  ON public.orders (driver_id)
  WHERE driver_id IS NOT NULL
    AND status IN (
      'assigned'::public.order_status,
      'picking_up'::public.order_status,
      'delivering'::public.order_status
    );

CREATE OR REPLACE FUNCTION public.find_nearest_drivers(
  pickup_lat double precision,
  pickup_lng double precision,
  radius_meters double precision DEFAULT 5000,
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
AS $function$
  WITH candidate_distances AS (
    SELECT
      d.id,
      d.user_id,
      u.full_name,
      d.vehicle_type,
      d.license_plate,
      d.current_lat,
      d.current_lng,
      public.ST_Distance(
        public.ST_SetSRID(
          public.ST_MakePoint(d.current_lng, d.current_lat),
          4326
        )::public.geography,
        public.ST_SetSRID(
          public.ST_MakePoint(pickup_lng, pickup_lat),
          4326
        )::public.geography
      ) AS distance_meters,
      COALESCE(d.rating, 0)::double precision AS rating,
      d.location_updated_at
    FROM public.drivers d
    JOIN public.users u ON u.id = d.user_id
    WHERE auth.uid() IS NOT NULL
      AND pickup_lat BETWEEN -90 AND 90
      AND pickup_lng BETWEEN -180 AND 180
      AND radius_meters > 0
      AND d.is_available = true
      AND d.approval_status = 'approved'::public.approval_status
      AND d.current_lat IS NOT NULL
      AND d.current_lng IS NOT NULL
      AND d.location_updated_at >= now() - interval '3 minutes'
      AND NOT EXISTS (
        SELECT 1
        FROM public.orders active_order
        WHERE active_order.driver_id = d.user_id
          AND active_order.status IN (
            'assigned'::public.order_status,
            'picking_up'::public.order_status,
            'delivering'::public.order_status
          )
      )
      AND public.ST_DWithin(
        public.ST_SetSRID(
          public.ST_MakePoint(d.current_lng, d.current_lat),
          4326
        )::public.geography,
        public.ST_SetSRID(
          public.ST_MakePoint(pickup_lng, pickup_lat),
          4326
        )::public.geography,
        LEAST(radius_meters, 50000)
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
  FROM candidate_distances candidate
  ORDER BY
    candidate.distance_meters ASC,
    candidate.user_id ASC
  LIMIT LEAST(GREATEST(max_results, 1), 50);
$function$;

CREATE OR REPLACE FUNCTION public.assign_order_to_nearest_driver(
  p_order_id uuid,
  p_radius_meters double precision DEFAULT 5000
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_actor_id uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_candidate record;
  v_driver_user_id uuid;
  v_distance double precision;
  v_rating double precision;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  SELECT *
  INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ORDER_NOT_FOUND';
  END IF;

  IF v_actor_id IS DISTINCT FROM v_order.customer_id THEN
    RAISE EXCEPTION 'ORDER_ASSIGNMENT_FORBIDDEN';
  END IF;

  IF v_order.driver_id IS NOT NULL THEN
    RETURN v_order.driver_id;
  END IF;

  IF v_order.status NOT IN (
       'pending'::public.order_status,
       'confirmed'::public.order_status
     )
     OR v_order.assignment_timed_out_at IS NOT NULL
     OR v_order.assignment_expires_at <= clock_timestamp()
     OR v_order.pickup_lat IS NULL
     OR v_order.pickup_lng IS NULL THEN
    RETURN NULL;
  END IF;

  FOR v_candidate IN
    WITH eligible_candidates AS (
      SELECT candidate.*
      FROM public.find_nearest_drivers(
        v_order.pickup_lat,
        v_order.pickup_lng,
        p_radius_meters,
        50
      ) candidate
      WHERE NOT (
        COALESCE(v_order.rejected_by, '[]'::jsonb)
        ? candidate.user_id::text
      )
    )
    SELECT candidate.*
    FROM eligible_candidates candidate
    ORDER BY
      candidate.distance_meters ASC,
      candidate.user_id ASC
  LOOP
    BEGIN
      UPDATE public.orders
      SET
        driver_id = v_candidate.user_id,
        status = 'assigned'::public.order_status,
        updated_at = clock_timestamp()
      WHERE id = p_order_id
        AND driver_id IS NULL
        AND assignment_timed_out_at IS NULL
        AND assignment_expires_at > clock_timestamp()
        AND status IN (
          'pending'::public.order_status,
          'confirmed'::public.order_status
        );

      IF FOUND THEN
        v_driver_user_id := v_candidate.user_id;
        v_distance := v_candidate.distance_meters;
        v_rating := v_candidate.rating;
        EXIT;
      END IF;
    EXCEPTION
      WHEN unique_violation THEN
        CONTINUE;
    END;
  END LOOP;

  IF v_driver_user_id IS NULL THEN
    RETURN NULL;
  END IF;

  INSERT INTO public.order_status_logs (
    order_id,
    status,
    title,
    description,
    logged_by
  )
  VALUES (
    p_order_id,
    'assigned'::public.order_status,
    'Đã phân công tài xế',
    format(
      'Hệ thống phân công tài xế phù hợp (%s m, rating %s).',
      round(COALESCE(v_distance, 0))::text,
      round(COALESCE(v_rating, 0)::numeric, 1)::text
    ),
    v_actor_id
  );

  RETURN v_driver_user_id;
END;
$function$;

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

REVOKE ALL ON FUNCTION public.assign_order_to_nearest_driver(
  uuid,
  double precision
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.assign_order_to_nearest_driver(
  uuid,
  double precision
) TO authenticated;
