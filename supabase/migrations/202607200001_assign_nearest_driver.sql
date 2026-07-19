-- Auto-assign order to nearest available driver (SECURITY DEFINER).
-- Client already filters the available pool to the nearest driver; this RPC
-- makes assignment atomic and bypasses fragile customer UPDATE RLS.

-- Improve nearest-driver search: require coords, skip busy drivers, wider radius.
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
    d.rating
  FROM drivers d
  JOIN users u ON u.id = d.user_id
  WHERE d.is_available = true
    AND d.approval_status = 'approved'
    AND d.current_lat IS NOT NULL
    AND d.current_lng IS NOT NULL
    AND NOT EXISTS (
      SELECT 1
      FROM orders o
      WHERE o.driver_id = d.user_id
        AND o.status IN ('assigned', 'picking_up', 'delivering')
    )
    AND ST_DWithin(
      ST_SetSRID(ST_MakePoint(d.current_lng, d.current_lat), 4326)::geography,
      ST_SetSRID(ST_MakePoint(pickup_lng, pickup_lat), 4326)::geography,
      radius_meters
    )
  ORDER BY distance_meters
  LIMIT max_results;
$function$;

CREATE OR REPLACE FUNCTION public.assign_order_to_nearest_driver(
  p_order_id uuid,
  p_radius_meters double precision DEFAULT 15000
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_order orders%ROWTYPE;
  v_driver_user_id uuid;
  v_distance double precision;
BEGIN
  SELECT * INTO v_order
  FROM orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  IF auth.uid() IS DISTINCT FROM v_order.customer_id THEN
    RAISE EXCEPTION 'Not allowed to assign this order';
  END IF;

  IF v_order.driver_id IS NOT NULL THEN
    RETURN v_order.driver_id;
  END IF;

  IF v_order.status NOT IN ('pending', 'confirmed') THEN
    RETURN NULL;
  END IF;

  IF v_order.pickup_lat IS NULL OR v_order.pickup_lng IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT f.user_id, f.distance_meters
  INTO v_driver_user_id, v_distance
  FROM public.find_nearest_drivers(
    v_order.pickup_lat,
    v_order.pickup_lng,
    p_radius_meters,
    1
  ) AS f
  LIMIT 1;

  IF v_driver_user_id IS NULL THEN
    RETURN NULL;
  END IF;

  UPDATE orders
  SET
    driver_id = v_driver_user_id,
    status = 'assigned',
    updated_at = now()
  WHERE id = p_order_id
    AND driver_id IS NULL
    AND status IN ('pending', 'confirmed');

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  INSERT INTO order_status_logs (order_id, status, title, description)
  VALUES (
    p_order_id,
    'assigned',
    'Đã phân công tài xế',
    format(
      'Hệ thống gán đơn cho tài xế gần điểm lấy hàng nhất (%.0f m).',
      COALESCE(v_distance, 0)
    )
  );

  RETURN v_driver_user_id;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.find_nearest_drivers(double precision, double precision, double precision, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_order_to_nearest_driver(uuid, double precision) TO authenticated;

-- Seed distinct positions for demo accounts (optional, safe to re-run).
-- taixe@gmail.com keeps existing coords if present.
-- taixe2@gmail.com is placed ~3km SE so distances never tie.
UPDATE drivers d
SET
  current_lat = 10.95850,
  current_lng = 106.69380,
  is_available = true,
  updated_at = now()
FROM users u
WHERE d.user_id = u.id
  AND u.email = 'taixe2@gmail.com';

UPDATE drivers d
SET
  is_available = true,
  updated_at = now()
FROM users u
WHERE d.user_id = u.id
  AND u.email = 'taixe@gmail.com';
