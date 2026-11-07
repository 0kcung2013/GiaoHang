-- Rating tie-break regression: apply driver_rating_distance_tiebreak first.
-- Briefly locks two idle test driver accounts; all fixture changes roll back.
BEGIN;
SET LOCAL statement_timeout = '15s';
SELECT set_config('giaohang.road_dispatch_requested', 'yes', true);
DO $test$
DECLARE
  v_drivers uuid[];
  v_customer uuid;
  v_order uuid := gen_random_uuid();
  v_quote_a jsonb;
  v_quote_b jsonb;
  v_selected uuid;
  v_scenario jsonb;
  v_candidates jsonb;
BEGIN
  SELECT array_agg(user_id ORDER BY user_id) INTO v_drivers FROM (
    SELECT d.user_id FROM public.drivers d
    JOIN auth.users a ON a.id = d.user_id
    WHERE (a.banned_until IS NULL OR a.banned_until <= now())
      AND NOT EXISTS (
        SELECT 1 FROM public.orders o WHERE o.driver_id = d.user_id
          AND o.status IN ('assigned','picking_up','delivering','return_approved','returning')
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.orders o WHERE o.offered_driver_id = d.user_id
          AND o.driver_id IS NULL AND o.status IN ('pending','confirmed')
          AND o.assignment_timed_out_at IS NULL
      )
    ORDER BY d.user_id LIMIT 2
  ) idle;
  IF cardinality(v_drivers) IS DISTINCT FROM 2 THEN
    RAISE EXCEPTION 'Rating regression requires two idle test drivers';
  END IF;
  SELECT id INTO v_customer FROM public.users WHERE role = 'customer' LIMIT 1;
  IF v_customer IS NULL THEN RAISE EXCEPTION 'Customer fixture required'; END IF;

  UPDATE public.drivers SET is_available = true, approval_status = 'approved',
    acceptance_locked_until = NULL, current_lat = 10.781, current_lng = 106.7,
    location_updated_at = clock_timestamp(),
    dispatch_mode='nearby',operating_area_id=NULL,destination_lat=NULL,destination_lng=NULL,
    destination_label=NULL,destination_expires_at=NULL,nearby_delivery_limit_m=NULL
    WHERE user_id = ANY(v_drivers);
  INSERT INTO public.orders (
    id, customer_id, status, pickup_address, pickup_lat, pickup_lng,
    delivery_address, delivery_lat, delivery_lng, tracking_code
  ) VALUES (
    v_order, v_customer, 'pending', 'Rating regression pickup', 10.78, 106.7,
    'Rating regression delivery', 10.79, 106.71, 'RATING-TEST-' || v_order::text
  );

  FOR v_scenario IN SELECT value FROM jsonb_array_elements('[
    {"name":"rating beats duration and ID", "a":4.1, "b":4.9, "distance_b":1000, "duration_b":300, "winner":2},
    {"name":"closer still wins", "a":1, "b":5, "distance_b":1000.1, "duration_b":30, "winner":1},
    {"name":"unrated is not five stars", "a":null, "b":1, "distance_b":1000, "duration_b":300, "winner":2},
    {"name":"same rating retains duration", "a":4.8, "b":4.8, "distance_b":1000, "duration_b":30, "winner":2},
    {"name":"fully tied retains stable ID", "a":4.8, "b":4.8, "distance_b":1000, "duration_b":60, "winner":1},
    {"name":"both unrated retain stable ID", "a":null, "b":null, "distance_b":1000, "duration_b":60, "winner":1}
  ]'::jsonb)
  LOOP
    UPDATE public.orders SET offered_driver_id = NULL, offer_expires_at = NULL
      WHERE id = v_order;
    UPDATE public.drivers SET
      rating = (v_scenario ->> CASE WHEN user_id = v_drivers[1] THEN 'a' ELSE 'b' END)::numeric,
      rating_count = CASE
        WHEN v_scenario ->> CASE WHEN user_id = v_drivers[1] THEN 'a' ELSE 'b' END IS NULL THEN 0
        ELSE 1 END
      WHERE user_id = ANY(v_drivers);

    v_candidates := public.road_dispatch_candidates(v_order);
    IF (SELECT (value->>'rating')::numeric FROM jsonb_array_elements(v_candidates)
      WHERE value->>'user_id' = v_drivers[1]::text)
      IS DISTINCT FROM COALESCE((v_scenario->>'a')::numeric, 0)
    OR (SELECT (value->>'rating')::numeric FROM jsonb_array_elements(v_candidates)
      WHERE value->>'user_id' = v_drivers[2]::text)
      IS DISTINCT FROM COALESCE((v_scenario->>'b')::numeric, 0) THEN
      RAISE EXCEPTION 'Dispatcher did not receive current ratings: %', v_scenario->>'name';
    END IF;

    v_quote_a := jsonb_build_object(
      'user_id', v_drivers[1], 'origin_lat', 10.781, 'origin_lng', 106.7,
      'pickup_lat', 10.78, 'pickup_lng', 106.7,
      'distance_meters', 1000, 'duration_seconds', 60, 'quoted_at', now(),
      'rating', 5
    );
    v_quote_b := v_quote_a || jsonb_build_object(
      'user_id', v_drivers[2], 'distance_meters', (v_scenario->>'distance_b')::numeric,
      'duration_seconds', (v_scenario->>'duration_b')::numeric, 'rating', 0
    );
    -- Reversed input and forged scores must not override database ratings.
    v_selected := public.commit_road_driver_offer(v_order, jsonb_build_array(v_quote_b, v_quote_a));
    IF v_selected IS DISTINCT FROM v_drivers[(v_scenario->>'winner')::integer] THEN
      RAISE EXCEPTION 'Wrong ranking for %', v_scenario->>'name';
    END IF;
    IF public.commit_road_driver_offer(v_order, jsonb_build_array(v_quote_a, v_quote_b)) IS NOT NULL THEN
      RAISE EXCEPTION 'Retry replaced an active offer';
    END IF;
  END LOOP;

  IF has_function_privilege('authenticated', 'public.commit_road_driver_offer(uuid,jsonb)', 'execute')
    OR has_function_privilege('anon', 'public.road_dispatch_candidates(uuid)', 'execute') THEN
    RAISE EXCEPTION 'Quote submission or candidate lookup became client-accessible';
  END IF;
  RAISE NOTICE 'PASS: distance, rating, unrated drivers, duration, stable ID, authoritative scores and retry';
END;
$test$;
ROLLBACK;
