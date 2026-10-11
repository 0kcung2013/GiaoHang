-- Kiểm tra chỉ đọc tại đúng hàm đang được commit_road_driver_offer sử dụng.
-- Trước khi sửa: hai ca json_roundtrip_same_pickup thất bại.
-- Sau khi sửa: mọi dòng phải có passes = true.
WITH base AS (
  SELECT
    o,
    d,
    jsonb_build_object(
      'distance_meters', 450,
      'duration_seconds', 70,
      'quoted_at', clock_timestamp(),
      'pickup_lat', o.pickup_lat,
      'pickup_lng', o.pickup_lng,
      'origin_lat', d.current_lat,
      'origin_lng', d.current_lng
    ) AS quote
  FROM public.orders o
  CROSS JOIN public.drivers d
  WHERE o.tracking_code IN ('GH-10199', 'GH-10200')
    AND d.user_id = '8398b809-fb41-4381-a7a4-51cb04834d0f'
), variants AS (
  SELECT b.*, v.name, v.patch, v.expected
  FROM base b
  CROSS JOIN LATERAL (
    VALUES
      ('json_roundtrip_same_pickup', '{}'::jsonb, true),
      ('different_pickup', jsonb_build_object('pickup_lat', (b.o).pickup_lat + 0.00001), false),
      ('outside_2km', jsonb_build_object('distance_meters', 2001), false),
      ('stale_quote', jsonb_build_object('quoted_at', now() - interval '31 seconds'), false),
      ('future_quote', jsonb_build_object('quoted_at', now() + interval '6 seconds'), false),
      ('driver_moved', jsonb_build_object('origin_lat', (b.d).current_lat + 0.001), false),
      ('negative_duration', jsonb_build_object('duration_seconds', -1), false),
      ('null_quote', NULL::jsonb, false),
      ('invalid_quote_object', '[]'::jsonb, false),
      ('missing_pickup', jsonb_build_object('pickup_lat', NULL), false),
      ('invalid_distance', jsonb_build_object('distance_meters', 'invalid'), false),
      ('nonfinite_pickup', jsonb_build_object('pickup_lat', 'NaN'), false)
  ) AS v(name, patch, expected)
), checks AS (
  SELECT
    (o).tracking_code,
    name,
    expected,
    private.valid_pickup_road_quote(
      CASE
        WHEN name = 'null_quote' THEN NULL::jsonb
        WHEN name = 'invalid_quote_object' THEN patch
        ELSE quote || patch
      END,
      d, o, 0, 2000
    ) AS actual
  FROM variants
)
SELECT *, actual = expected AS passes
FROM checks
ORDER BY tracking_code, name;
