-- Keep driver matching consistent across PostgreSQL, Redis, and Flutter.
-- A driver is assignable only when online, approved, idle, and reporting a
-- recent location. Also move driver status progression into one transaction.

ALTER TABLE public.drivers
  ADD COLUMN IF NOT EXISTS location_updated_at timestamptz;

UPDATE public.drivers
SET location_updated_at = COALESCE(location_updated_at, updated_at)
WHERE current_lat IS NOT NULL
  AND current_lng IS NOT NULL
  AND location_updated_at IS NULL;

CREATE INDEX IF NOT EXISTS drivers_assignable_location_fresh_idx
  ON public.drivers (location_updated_at DESC)
  WHERE is_available = true
    AND approval_status = 'approved'::public.approval_status;

CREATE OR REPLACE FUNCTION public.find_nearest_drivers(
  pickup_lat double precision,
  pickup_lng double precision,
  radius_meters double precision DEFAULT 15000,
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
  rating double precision
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $function$
  SELECT
    d.id,
    d.user_id,
    u.full_name,
    d.vehicle_type,
    d.license_plate,
    d.current_lat,
    d.current_lng,
    ST_Distance(
      ST_SetSRID(ST_MakePoint(d.current_lng, d.current_lat), 4326)::geography,
      ST_SetSRID(ST_MakePoint(pickup_lng, pickup_lat), 4326)::geography
    ) AS distance_meters,
    d.rating::double precision
  FROM public.drivers d
  JOIN public.users u ON u.id = d.user_id
  WHERE d.is_available = true
    AND d.approval_status = 'approved'::public.approval_status
    AND d.current_lat IS NOT NULL
    AND d.current_lng IS NOT NULL
    AND d.location_updated_at >= now() - interval '3 minutes'
    AND NOT EXISTS (
      SELECT 1
      FROM public.orders o
      WHERE o.driver_id = d.user_id
        AND o.status IN (
          'assigned'::public.order_status,
          'picking_up'::public.order_status,
          'delivering'::public.order_status
        )
    )
    AND ST_DWithin(
      ST_SetSRID(ST_MakePoint(d.current_lng, d.current_lat), 4326)::geography,
      ST_SetSRID(ST_MakePoint(pickup_lng, pickup_lat), 4326)::geography,
      radius_meters
    )
  ORDER BY distance_meters
  LIMIT LEAST(GREATEST(max_results, 1), 50);
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

CREATE OR REPLACE FUNCTION public.advance_driver_order_status(
  p_order_id uuid
)
RETURNS TABLE(
  order_id uuid,
  customer_id uuid,
  tracking_code text,
  new_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_driver_user_id uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_next_status public.order_status;
  v_title text;
  v_description text;
BEGIN
  IF v_driver_user_id IS NULL THEN
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

  IF v_order.driver_id IS DISTINCT FROM v_driver_user_id THEN
    RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED';
  END IF;

  v_next_status := CASE v_order.status
    WHEN 'assigned'::public.order_status
      THEN 'picking_up'::public.order_status
    WHEN 'picking_up'::public.order_status
      THEN 'delivering'::public.order_status
    WHEN 'delivering'::public.order_status
      THEN 'delivered'::public.order_status
    ELSE NULL
  END;

  IF v_next_status IS NULL THEN
    RAISE EXCEPTION 'INVALID_STATUS_TRANSITION';
  END IF;

  v_title := CASE v_next_status
    WHEN 'picking_up'::public.order_status THEN 'Tài xế đang đến điểm lấy hàng'
    WHEN 'delivering'::public.order_status THEN 'Đơn hàng đang được giao'
    WHEN 'delivered'::public.order_status THEN 'Giao hàng thành công'
    ELSE 'Cập nhật trạng thái đơn hàng'
  END;

  v_description := CASE v_next_status
    WHEN 'picking_up'::public.order_status
      THEN 'Tài xế đã bắt đầu di chuyển đến điểm lấy hàng.'
    WHEN 'delivering'::public.order_status
      THEN 'Tài xế đã lấy hàng và đang di chuyển đến người nhận.'
    WHEN 'delivered'::public.order_status
      THEN 'Đơn hàng đã được giao tới người nhận.'
    ELSE NULL
  END;

  UPDATE public.orders
  SET
    status = v_next_status,
    updated_at = clock_timestamp(),
    actual_picked_up_at = CASE
      WHEN v_next_status = 'delivering'::public.order_status
        THEN clock_timestamp()
      ELSE actual_picked_up_at
    END,
    actual_delivered_at = CASE
      WHEN v_next_status = 'delivered'::public.order_status
        THEN clock_timestamp()
      ELSE actual_delivered_at
    END
  WHERE id = p_order_id
    AND status = v_order.status;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ORDER_STATUS_CHANGED';
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
    v_next_status,
    v_title,
    v_description,
    v_driver_user_id
  );

  RETURN QUERY
  SELECT
    v_order.id,
    v_order.customer_id,
    v_order.tracking_code,
    v_next_status::text;
END;
$function$;

REVOKE ALL ON FUNCTION public.advance_driver_order_status(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.advance_driver_order_status(uuid)
  TO authenticated;
