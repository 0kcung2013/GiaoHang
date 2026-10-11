-- Đã được người dùng duyệt ngày 10/10/2026: sửa sai số tọa độ quote phân công.
-- Chỉ thay hai phép so sánh tọa độ trong hàm hiện có; giữ nguyên quyền và chữ ký.

CREATE OR REPLACE FUNCTION private.valid_pickup_road_quote(
  p_quote jsonb,
  p_driver public.drivers,
  p_order public.orders,
  p_min double precision,
  p_max double precision
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SET search_path = ''
AS $function$
DECLARE
  v_distance double precision;
  v_quoted_at timestamptz;
BEGIN
  IF p_quote IS NULL OR jsonb_typeof(p_quote) <> 'object' THEN
    RETURN false;
  END IF;

  v_distance := (p_quote->>'distance_meters')::double precision;
  v_quoted_at := (p_quote->>'quoted_at')::timestamptz;

  RETURN COALESCE(
    v_distance >= p_min AND v_distance <= p_max
    AND (p_quote->>'duration_seconds')::double precision >= 0
    AND v_quoted_at BETWEEN now() - interval '30 seconds'
                         AND now() + interval '5 seconds'
    -- JSON có thể làm tròn float8. 1e-9 độ chỉ bù sai số biểu diễn tọa độ.
    AND abs((p_quote->>'pickup_lat')::double precision - p_order.pickup_lat) <= 1e-9
    AND abs((p_quote->>'pickup_lng')::double precision - p_order.pickup_lng) <= 1e-9
    AND public.ST_DWithin(
      public.ST_SetSRID(
        public.ST_MakePoint(p_driver.current_lng, p_driver.current_lat), 4326
      )::public.geography,
      public.ST_SetSRID(
        public.ST_MakePoint(
          (p_quote->>'origin_lng')::double precision,
          (p_quote->>'origin_lat')::double precision
        ), 4326
      )::public.geography,
      30
    ),
    false
  );
EXCEPTION WHEN OTHERS THEN
  RETURN false;
END;
$function$;
